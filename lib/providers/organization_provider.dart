import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants/firestore_constants.dart';
import '../models/birthday_model.dart';
import '../models/holiday_model.dart';
import '../models/leave_config_model.dart';
import '../models/office_hours_model.dart';
import '../utils/logger.dart';

/// The single owner of the organization_details data (leave counts, office
/// hours, holiday calendar).
///
/// It keeps one live Firestore listener per document, started when a user logs
/// in and stopped on logout. Every screen reads from here, so the data is
/// fetched once per session and an admin's change reaches every signed-in
/// device automatically. All writes go through here too; the listener then
/// updates the state, so callers never refresh manually.
class OrganizationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _leaveSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _hoursSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _holidaysSub;

  LeaveConfigModel? _leaveConfig;
  OfficeHoursModel? _officeHours;
  List<HolidayModel> _holidays = [];

  // True once the first snapshot has arrived (even if the document is empty)
  bool _leaveConfigLoaded = false;
  bool _officeHoursLoaded = false;
  bool _holidaysLoaded = false;

  bool _isSavingLeaveConfig = false;
  bool _isSavingOfficeHours = false;
  bool _isSavingHoliday = false;

  LeaveConfigModel? get leaveConfig => _leaveConfig;
  OfficeHoursModel? get officeHours => _officeHours;
  List<HolidayModel> get holidays => _holidays;

  bool get isLeaveConfigured => _leaveConfig != null;
  bool get leaveConfigLoaded => _leaveConfigLoaded;
  bool get officeHoursLoaded => _officeHoursLoaded;
  bool get holidaysLoaded => _holidaysLoaded;

  bool get isSavingLeaveConfig => _isSavingLeaveConfig;
  bool get isSavingOfficeHours => _isSavingOfficeHours;
  bool get isSavingHoliday => _isSavingHoliday;

  CollectionReference<Map<String, dynamic>> get _org =>
      _firestore.collection(FirestoreCollections.organizationDetails);

  DocumentReference<Map<String, dynamic>> get _leaveDoc =>
      _org.doc(FirestoreDocs.leaveConfig);
  DocumentReference<Map<String, dynamic>> get _hoursDoc =>
      _org.doc(FirestoreDocs.officeHours);
  CollectionReference<Map<String, dynamic>> get _holidayItems => _org
      .doc(FirestoreDocs.holidays)
      .collection(FirestoreSubCollections.holidayItems);

  /// Live list of the employees whose birthday is today. Only those entries
  /// are read, so the cost does not grow with the number of employees.
  Stream<List<BirthdayModel>> todaysBirthdaysStream() {
    return _org
        .doc(FirestoreDocs.birthdays)
        .collection(FirestoreSubCollections.birthdayItems)
        .where('monthDay', isEqualTo: BirthdayModel.keyFor(DateTime.now()))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BirthdayModel.fromJson(doc.data()))
              .toList(),
        );
  }

  /// The holiday falling on [date], or null.
  HolidayModel? holidayOn(DateTime date) {
    for (final holiday in _holidays) {
      if (holiday.date.year == date.year &&
          holiday.date.month == date.month &&
          holiday.date.day == date.day) {
        return holiday;
      }
    }
    return null;
  }

  // A dropped listener (rules not yet deployed, network blip) is retried a few
  // times with a growing delay, then left until the next start().
  Timer? _retryTimer;
  int _retries = 0;
  static const int _maxRetries = 3;

  void _scheduleRetry() {
    if (_retryTimer != null || _retries >= _maxRetries) return;
    _retries++;
    _retryTimer = Timer(Duration(seconds: 5 * _retries), () {
      _retryTimer = null;
      start();
    });
  }

  /// Starts the listeners. Safe to call repeatedly: each one subscribes once,
  /// and again only if it was dropped (for example after a permission error).
  void start() {
    _leaveSub ??= _leaveDoc.snapshots().listen(
      (doc) {
        _retries = 0;
        _leaveConfig = LeaveConfigModel.tryFromJson(doc.data());
        _leaveConfigLoaded = true;
        notifyListeners();
      },
      onError: (Object e) {
        logDebug('Leave config listener stopped: $e');
        _leaveSub?.cancel();
        _leaveSub = null;
        _scheduleRetry();
      },
    );

    _hoursSub ??= _hoursDoc.snapshots().listen(
      (doc) {
        _retries = 0;
        _officeHours = OfficeHoursModel.tryFromJson(doc.data());
        _officeHoursLoaded = true;
        notifyListeners();
      },
      onError: (Object e) {
        logDebug('Office hours listener stopped: $e');
        _hoursSub?.cancel();
        _hoursSub = null;
        _scheduleRetry();
      },
    );

    // Only this year onward, so reads stay bounded as the years pass
    final yearStart = Timestamp.fromDate(DateTime(DateTime.now().year));
    _holidaysSub ??= _holidayItems
        .where('date', isGreaterThanOrEqualTo: yearStart)
        .snapshots()
        .listen(
          (snapshot) {
            _holidays =
                snapshot.docs
                    .map(
                      (doc) =>
                          HolidayModel.fromJson({...doc.data(), 'id': doc.id}),
                    )
                    .toList()
                  ..sort((a, b) => a.date.compareTo(b.date));
            _retries = 0;
            _holidaysLoaded = true;
            notifyListeners();
          },
          onError: (Object e) {
            logDebug('Holidays listener stopped: $e');
            _holidaysSub?.cancel();
            _holidaysSub = null;
            _scheduleRetry();
          },
        );
  }

  /// Cancels the listeners and clears the data (called on logout).
  void stop() {
    final wasRunning =
        _leaveSub != null ||
        _hoursSub != null ||
        _holidaysSub != null ||
        _leaveConfigLoaded ||
        _officeHoursLoaded ||
        _holidaysLoaded;
    if (!wasRunning) return;

    _retryTimer?.cancel();
    _retryTimer = null;
    _retries = 0;
    _leaveSub?.cancel();
    _hoursSub?.cancel();
    _holidaysSub?.cancel();
    _leaveSub = null;
    _hoursSub = null;
    _holidaysSub = null;

    _leaveConfig = null;
    _officeHours = null;
    _holidays = [];
    _leaveConfigLoaded = false;
    _officeHoursLoaded = false;
    _holidaysLoaded = false;

    // Called while the provider tree is updating, so notify afterwards
    Future.microtask(notifyListeners);
  }

  // --- Writes: the listeners update the state, so no manual refresh ---

  Future<bool> saveLeaveConfig(
    int pl,
    int sl,
    int cl, {
    bool carryForwardPL = false,
    bool carryForwardCompOff = false,
  }) async {
    start();
    _isSavingLeaveConfig = true;
    notifyListeners();
    try {
      await _leaveDoc.set({
        ...LeaveConfigModel(
          privilegeLeaves: pl,
          sickLeaves: sl,
          casualLeaves: cl,
          carryForwardPL: carryForwardPL,
          carryForwardCompOff: carryForwardCompOff,
        ).toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      logDebug('Error saving leave config: $e');
      return false;
    } finally {
      _isSavingLeaveConfig = false;
      notifyListeners();
    }
  }

  Future<bool> saveOfficeHours(OfficeHoursModel hours) async {
    start();
    _isSavingOfficeHours = true;
    notifyListeners();
    try {
      await _hoursDoc.set({
        ...hours.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      logDebug('Error saving office hours: $e');
      return false;
    } finally {
      _isSavingOfficeHours = false;
      notifyListeners();
    }
  }

  Future<bool> addHoliday(
    String name,
    DateTime date, {
    String? description,
  }) async {
    start();
    _isSavingHoliday = true;
    notifyListeners();
    try {
      final holiday = HolidayModel(
        id: const Uuid().v4(),
        name: name,
        date: date,
        description: description,
      );
      await _holidayItems.doc(holiday.id).set({
        ...holiday.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      logDebug('Error adding holiday: $e');
      return false;
    } finally {
      _isSavingHoliday = false;
      notifyListeners();
    }
  }

  Future<bool> deleteHoliday(String holidayId) async {
    try {
      await _holidayItems.doc(holidayId).delete();
      return true;
    } catch (e) {
      logDebug('Error deleting holiday: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _leaveSub?.cancel();
    _hoursSub?.cancel();
    _holidaysSub?.cancel();
    super.dispose();
  }
}
