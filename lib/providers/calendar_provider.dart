import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../models/attendance_model.dart';
import '../models/holiday_model.dart';
import '../models/office_hours_model.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
import '../services/attendance_day_calculator.dart';
import '../utils/logger.dart';

export '../services/attendance_day_calculator.dart' show CalendarDayStatus;

class _MonthData {
  final Map<int, AttendanceModel> attendance;
  final List<RequestModel> requests;

  _MonthData(this.attendance, this.requests);
}

/// Builds the per-day status for the month shown on the dashboard calendar from
/// the user's attendance, approved leave / WFH requests, and the office hours
/// and holiday list the admin maintains (supplied live by
/// [OrganizationProvider] through [setOrganization]). The rules themselves
/// live in [AttendanceDayCalculator], shared with the stored monthly summary.
class CalendarProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = false;
  UserModel? _user;

  // Loaded per month from Firestore
  final Map<int, AttendanceModel> _attendance = {};
  List<RequestModel> _requests = [];

  // Pushed in live from OrganizationProvider
  OfficeHoursModel? _officeHours;
  List<HolidayModel> _orgHolidays = [];

  final Map<int, CalendarDayStatus> _statuses = {};
  final Map<int, String> _labels = {};
  AttendanceModel? _today;

  // Months already fetched for the current user, keyed "yyyy-MM"
  final Map<String, _MonthData> _monthCache = {};
  String _cacheKey(DateTime m) => '${m.year}-${m.month}';

  OfficeHoursModel? get officeHours => _officeHours;
  DateTime get month => _month;
  bool get isLoading => _isLoading;
  AttendanceModel? get todayAttendance => _today;

  bool get isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  CalendarDayStatus statusFor(int day) =>
      _statuses[day] ?? CalendarDayStatus.none;

  /// Short description of the day for the tap message, or null.
  String? labelFor(int day) => _labels[day];

  AttendanceModel? attendanceFor(int day) => _attendance[day];

  /// Called whenever the admin changes office hours or holidays. Recomputes the
  /// colours from data already loaded, without another network read.
  void setOrganization(OfficeHoursModel? hours, List<HolidayModel> holidays) {
    _officeHours = hours;
    _orgHolidays = holidays;

    final user = _user;
    if (user != null) {
      _buildStatuses(user);
    }
    // This runs while the provider tree is updating, so notify afterwards
    Future.microtask(notifyListeners);
  }

  /// Loads a month. A month already viewed is served from memory (no reads);
  /// pass [force] to fetch again, e.g. after punching or on pull-to-refresh.
  Future<void> loadMonth(
    UserModel user,
    DateTime month, {
    bool force = false,
  }) async {
    // A different account on the same device must not see cached data
    if (_user?.id != user.id) _monthCache.clear();
    if (force) _monthCache.remove(_cacheKey(month));

    _user = user;
    _month = DateTime(month.year, month.month);

    final cached = _monthCache[_cacheKey(_month)];
    if (cached != null) {
      _attendance
        ..clear()
        ..addAll(cached.attendance);
      _requests = cached.requests;
      _buildStatuses(user);
      if (isCurrentMonth) _today = _attendance[DateTime.now().day];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final start = _month;
      final end = DateTime(_month.year, _month.month + 1);

      final attendanceFuture = _firestore
          .collection(FirestoreCollections.attendance)
          .where('userId', isEqualTo: user.id)
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .get();
      final requestsFuture = _firestore
          .collection(FirestoreCollections.users)
          .doc(user.id)
          .collection(FirestoreSubCollections.requests)
          .where('status', isEqualTo: AppConstants.statusApproved)
          .get();

      // Future.wait watches both reads, so one failing never leaves the other
      // unobserved
      final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
        attendanceFuture,
        requestsFuture,
      ]);
      final attendanceSnap = results[0];
      final requestsSnap = results[1];

      _attendance.clear();
      for (final doc in attendanceSnap.docs) {
        final record = AttendanceModel.fromJson(doc.data());
        _attendance[record.date.day] = record;
      }

      _requests = requestsSnap.docs
          .map((doc) => RequestModel.fromJson(doc.data()))
          // Leave / WFH cover a from-to range; a comp off request names its
          // day off
          .where(
            (r) =>
                (r.fromDate != null && r.toDate != null) ||
                (r.isCompOffRequest && r.compOffDate != null),
          )
          .toList();

      _monthCache[_cacheKey(_month)] = _MonthData(
        Map.of(_attendance),
        _requests,
      );

      _buildStatuses(user);

      if (isCurrentMonth) {
        _today = _attendance[DateTime.now().day];
      }
    } catch (e) {
      logDebug('Error loading calendar month: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Re-reads the shown month and drops the cached ones.
  Future<void> refresh() async {
    final user = _user;
    if (user == null) return;
    _monthCache.clear();
    await loadMonth(user, _month, force: true);
  }

  Future<void> previousMonth() async {
    final user = _user;
    if (user != null) {
      await loadMonth(user, DateTime(_month.year, _month.month - 1));
    }
  }

  Future<void> nextMonth() async {
    final user = _user;
    if (user != null) {
      await loadMonth(user, DateTime(_month.year, _month.month + 1));
    }
  }

  void _buildStatuses(UserModel user) {
    _statuses.clear();
    _labels.clear();

    // Holidays of the displayed month, by day
    final holidays = <int, HolidayModel>{
      for (final h in _orgHolidays)
        if (h.date.year == _month.year && h.date.month == _month.month)
          h.date.day: h,
    };

    final results = AttendanceDayCalculator.computeMonth(
      month: _month,
      user: user,
      attendance: _attendance,
      requests: _requests,
      holidays: holidays,
      officeHours: _officeHours,
    );

    results.forEach((day, result) {
      _statuses[day] = result.status;
      if (result.label.isNotEmpty) _labels[day] = result.label;
    });
  }
}
