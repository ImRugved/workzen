import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../models/attendance_model.dart';
import '../models/request_model.dart';
import '../utils/logger.dart';

/// The signed-in user's own attendance, requests and leave balances, kept live
/// with one Firestore listener each for the whole session.
///
/// Every screen of the employee (home, attendance, calendar, leave history,
/// apply leave) reads from here instead of running its own query, so a punch,
/// a new request or an admin's decision shows everywhere at once and each
/// document is read once, not once per screen.
///
/// Listeners (all small and bounded):
/// - attendance of this month onward (one document per day worked),
/// - the user's requests,
/// - this year's leave document and the comp off document.
///
/// Started when a user logs in and stopped on logout (see main.dart).
class MyDataProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _uid;
  // What the listeners were started for, so a new month or year restarts them
  DateTime? _attendanceFrom;
  int? _leaveYear;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _annualSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _compOffSub;

  List<AttendanceModel> _attendance = [];
  List<RequestModel> _requests = [];
  Map<String, dynamic>? _annualLeave;
  Map<String, dynamic>? _compOff;

  // True once the first snapshot arrived (even when there is no data)
  bool _attendanceLoaded = false;
  bool _requestsLoaded = false;
  bool _annualLoaded = false;
  bool _compOffLoaded = false;

  // Lets screens that want a stream (StreamBuilder) share the one listener
  final StreamController<List<RequestModel>> _requestChanges =
      StreamController<List<RequestModel>>.broadcast();

  /// The user the data belongs to, or null when nobody is signed in.
  String? get uid => _uid;

  /// Attendance records from the first day of the current month onward.
  List<AttendanceModel> get attendance => _attendance;

  /// All of the user's requests, newest first.
  List<RequestModel> get requests => _requests;

  /// This year's leave document (users/{uid}/leaves/annual_{year}), or null.
  Map<String, dynamic>? get annualLeave => _annualLeave;

  /// The comp off document (users/{uid}/leaves/comp_off), or null.
  Map<String, dynamic>? get compOff => _compOff;

  bool get attendanceLoaded => _attendanceLoaded;
  bool get requestsLoaded => _requestsLoaded;

  /// Both leave documents have arrived.
  bool get leaveLoaded => _annualLoaded && _compOffLoaded;

  /// Today's attendance record, or null when the user has not punched in.
  AttendanceModel? get todayAttendance {
    final now = DateTime.now();
    for (final record in _attendance) {
      if (record.date.year == now.year &&
          record.date.month == now.month &&
          record.date.day == now.day) {
        return record;
      }
    }
    return null;
  }

  /// The user's approved requests.
  List<RequestModel> get approvedRequests => _requests
      .where((r) => r.status == AppConstants.statusApproved)
      .toList();

  /// The requests as a stream that gives the current list to a new listener
  /// straight away and then every change, all from the one Firestore listener.
  Stream<List<RequestModel>> get requestsStream => Stream.multi((controller) {
    if (_requestsLoaded) controller.add(_requests);
    final subscription = _requestChanges.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection(FirestoreCollections.users).doc(_uid);

  /// Starts the listeners for [uid]. Safe to call repeatedly: each one is
  /// subscribed once, and again only when it was dropped (for example after an
  /// error) or when the month or year changed since it was started.
  void start(String uid) {
    if (_uid != uid) {
      stop();
      _uid = uid;
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    // A new month: the attendance query must begin at the new month
    if (_attendanceFrom != null && _attendanceFrom != monthStart) {
      _attendanceSub?.cancel();
      _attendanceSub = null;
    }
    // A new year: a new annual leave document
    if (_leaveYear != null && _leaveYear != now.year) {
      _annualSub?.cancel();
      _annualSub = null;
      _annualLoaded = false;
      _annualLeave = null;
    }

    _attendanceFrom = monthStart;
    _leaveYear = now.year;

    // Needs the (userId, date) index that the attendance queries already use
    _attendanceSub ??= _firestore
        .collection(FirestoreCollections.attendance)
        .where(FirestoreFields.userId, isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: monthStart)
        .snapshots()
        .listen(
          (snapshot) {
            _attendance =
                snapshot.docs
                    .map((doc) => AttendanceModel.fromJson(doc.data()))
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
            _attendanceLoaded = true;
            notifyListeners();
          },
          onError: (Object e) {
            logDebug('Own attendance listener stopped: $e');
            _attendanceSub?.cancel();
            _attendanceSub = null;
          },
        );

    _requestsSub ??= _userDoc
        .collection(FirestoreSubCollections.requests)
        .snapshots()
        .listen(
          (snapshot) {
            _requests =
                snapshot.docs
                    .map((doc) => RequestModel.fromJson(doc.data()))
                    .toList()
                  ..sort((a, b) => b.appliedOn.compareTo(a.appliedOn));
            _requestsLoaded = true;
            _requestChanges.add(_requests);
            notifyListeners();
          },
          onError: (Object e) {
            logDebug('Own requests listener stopped: $e');
            _requestsSub?.cancel();
            _requestsSub = null;
          },
        );

    _annualSub ??= _userDoc
        .collection(FirestoreSubCollections.leaves)
        .doc(FirestoreDocs.annualLeave(now.year))
        .snapshots()
        .listen(
          (doc) {
            _annualLeave = doc.data();
            _annualLoaded = true;
            notifyListeners();
          },
          onError: (Object e) {
            logDebug('Own leave listener stopped: $e');
            _annualSub?.cancel();
            _annualSub = null;
          },
        );

    _compOffSub ??= _userDoc
        .collection(FirestoreSubCollections.leaves)
        .doc(FirestoreDocs.compOffBalance)
        .snapshots()
        .listen(
          (doc) {
            _compOff = doc.data();
            _compOffLoaded = true;
            notifyListeners();
          },
          onError: (Object e) {
            logDebug('Own comp off listener stopped: $e');
            _compOffSub?.cancel();
            _compOffSub = null;
          },
        );
  }

  /// Cancels the listeners and clears the data (called on logout).
  void stop() {
    final wasRunning = _uid != null;
    _attendanceSub?.cancel();
    _requestsSub?.cancel();
    _annualSub?.cancel();
    _compOffSub?.cancel();
    _attendanceSub = null;
    _requestsSub = null;
    _annualSub = null;
    _compOffSub = null;

    _uid = null;
    _attendanceFrom = null;
    _leaveYear = null;
    _attendance = [];
    _requests = [];
    _annualLeave = null;
    _compOff = null;
    _attendanceLoaded = false;
    _requestsLoaded = false;
    _annualLoaded = false;
    _compOffLoaded = false;

    // Called while the provider tree is updating, so notify afterwards
    if (wasRunning) Future.microtask(notifyListeners);
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _requestsSub?.cancel();
    _annualSub?.cancel();
    _compOffSub?.cancel();
    _requestChanges.close();
    super.dispose();
  }
}
