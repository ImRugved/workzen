import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../models/attendance_model.dart';
import '../models/holiday_model.dart';
import '../models/monthly_attendance_summary.dart';
import '../models/office_hours_model.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';
import 'attendance_day_calculator.dart';

/// Keeps one document per user per month at
/// users/{uid}/attendance_summary/{yyyy-MM}: the lists of present, absent,
/// leave, half day, late, ... days plus per-day punch times. The attendance
/// history screen reads these, so it needs one read per month instead of
/// re-deriving everything from raw attendance, leave and holiday data.
///
/// A month is rebuilt after a punch, after leave is approved or rejected, when
/// an admin marks an absence, and when history opens a month that is out of
/// date. Past months that were rebuilt after the month ended are read as-is.
class AttendanceSummaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _summaryDoc(
    String userId,
    DateTime month,
  ) => _firestore
      .collection(FirestoreCollections.users)
      .doc(userId)
      .collection(FirestoreSubCollections.attendanceSummary)
      .doc(FirestoreDocs.monthKey(month));

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Returns the stored summary for [month], rebuilding it first when it is
  /// missing or out of date (or when [force] is set).
  Future<MonthlyAttendanceSummary> ensureMonth(
    UserModel user,
    DateTime month, {
    bool force = false,
  }) async {
    final target = DateTime(month.year, month.month);

    if (!force) {
      final snap = await _summaryDoc(user.id, target).get();
      final data = snap.data();
      if (data != null && _isFresh(data['builtOn'] as String?, target)) {
        return MonthlyAttendanceSummary.fromJson(data);
      }
    }

    return rebuildMonth(user, target);
  }

  bool _isFresh(String? builtOn, DateTime month) {
    if (builtOn == null) return false;

    final now = DateTime.now();
    final current = DateTime(now.year, now.month);

    if (month.isAfter(current)) return true; // future month: nothing happened
    if (month == current) return builtOn == _dayKey(now);

    // Past month: only complete if it was built after the month had ended
    return builtOn.compareTo(
          _dayKey(DateTime(month.year, month.month + 1, 1)),
        ) >=
        0;
  }

  /// Same as [rebuildMonth] for a user known only by id (used when an admin
  /// approves leave for someone else).
  Future<MonthlyAttendanceSummary?> rebuildMonthById(
    String userId,
    DateTime month,
  ) async {
    final userDoc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .get();
    final data = userDoc.data();
    if (data == null) return null;
    return rebuildMonth(UserModel.fromJson(data), month);
  }

  /// Rebuilds the months a leave request covers.
  Future<void> rebuildMonthsBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    var month = DateTime(from.year, from.month);
    final last = DateTime(to.year, to.month);
    while (!month.isAfter(last)) {
      await rebuildMonthById(userId, month);
      month = DateTime(month.year, month.month + 1);
    }
  }

  /// Reads the raw data for [month], recomputes every day and stores it.
  Future<MonthlyAttendanceSummary> rebuildMonth(
    UserModel user,
    DateTime month,
  ) async {
    final target = DateTime(month.year, month.month);
    final end = DateTime(target.year, target.month + 1);
    final org = _firestore.collection(FirestoreCollections.organizationDetails);

    // Start every read together, then await each with its own type
    final attendanceFuture = _firestore
        .collection(FirestoreCollections.attendance)
        .where('userId', isEqualTo: user.id)
        .where('date', isGreaterThanOrEqualTo: target)
        .where('date', isLessThan: end)
        .get();
    final requestsFuture = _firestore
        .collection(FirestoreCollections.users)
        .doc(user.id)
        .collection(FirestoreSubCollections.requests)
        .where('status', isEqualTo: AppConstants.statusApproved)
        .get();
    final holidaysFuture = org
        .doc(FirestoreDocs.holidays)
        .collection(FirestoreSubCollections.holidayItems)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(target))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    final officeHoursFuture = org.doc(FirestoreDocs.officeHours).get();
    final existingFuture = _summaryDoc(user.id, target).get();

    // Future.wait watches every read, so one failing read never leaves another
    // unobserved (which would surface as an unhandled exception)
    final reads = await Future.wait<Object>([
      attendanceFuture,
      requestsFuture,
      holidaysFuture,
      officeHoursFuture,
      existingFuture,
    ]);
    final attendanceSnap = reads[0] as QuerySnapshot<Map<String, dynamic>>;
    final requestsSnap = reads[1] as QuerySnapshot<Map<String, dynamic>>;
    final holidaysSnap = reads[2] as QuerySnapshot<Map<String, dynamic>>;
    final officeHoursSnap = reads[3] as DocumentSnapshot<Map<String, dynamic>>;
    final existingSnap = reads[4] as DocumentSnapshot<Map<String, dynamic>>;

    final attendance = <int, AttendanceModel>{
      for (final doc in attendanceSnap.docs)
        AttendanceModel.fromJson(doc.data()).date.day: AttendanceModel.fromJson(
          doc.data(),
        ),
    };
    final requests = requestsSnap.docs
        .map((doc) => RequestModel.fromJson(doc.data()))
        .toList();
    final holidays = <int, HolidayModel>{
      for (final doc in holidaysSnap.docs)
        HolidayModel.fromJson({...doc.data(), 'id': doc.id}).date.day:
            HolidayModel.fromJson({...doc.data(), 'id': doc.id}),
    };
    final officeHours = OfficeHoursModel.tryFromJson(officeHoursSnap.data());

    // Keep how a punch-in was judged when it happened, so changing the office
    // hours later does not rewrite earlier days of the month
    final frozen = <int, PunchInStatus>{};
    final existingData = existingSnap.data();
    if (existingData != null) {
      final previous = MonthlyAttendanceSummary.fromJson(existingData);
      previous.days.forEach((day, summary) {
        final record = attendance[day];
        final stored = summary.punchStatus;
        if (record?.punchInTime != null &&
            stored != null &&
            summary.punchIn == record!.punchInTime) {
          frozen[day] = PunchInStatus.values.firstWhere(
            (s) => s.name == stored,
            orElse: () => PunchInStatus.onTime,
          );
        }
      });
    }

    final results = AttendanceDayCalculator.computeMonth(
      month: target,
      user: user,
      attendance: attendance,
      requests: requests,
      holidays: holidays,
      officeHours: officeHours,
      frozenPunchStatus: frozen,
    );

    final days = <int, DaySummary>{
      for (final entry in results.entries)
        entry.key: DaySummary(
          day: entry.key,
          status: entry.value.status.name,
          label: entry.value.label,
          punchIn: attendance[entry.key]?.punchInTime,
          punchOut: attendance[entry.key]?.punchOutTime,
          punchStatus: entry.value.punchStatus?.name,
        ),
    };

    final summary = MonthlyAttendanceSummary(
      year: target.year,
      month: target.month,
      days: days,
    );

    try {
      await _summaryDoc(
        user.id,
        target,
      ).set({...summary.toJson(), 'builtOn': _dayKey(DateTime.now())});
    } catch (e) {
      // Still return the computed data if the write is not allowed
      logDebug('Could not store attendance summary: $e');
    }

    return summary;
  }
}
