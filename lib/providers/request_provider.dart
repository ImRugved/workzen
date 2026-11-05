import 'dart:async';
import 'dart:developer';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:workzen/utils/logger.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../constants/permissions.dart';
import '../models/leave_allocation_model.dart';
import '../models/leave_balance_model.dart';
import '../models/past_request_entry.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
import 'my_data_provider.dart';
import '../services/attendance_summary_service.dart';
import '../services/fcm_service.dart';

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  List<RequestModel> _userRequests = [];
  List<RequestModel> _allRequests = [];
  bool _isLoading = false;

  // Stream controllers

  // Apply Leave Form State
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  String? _shift; // null until user selects
  String _halfDayShift = 'First Half';
  String? _selectedLeaveType;
  LeaveAllocationModel? _leaveAllocation; // this year's leave for the user
  double _compOffBalance = 0; // approved comp off credit still available
  double _compOffEarned = 0; // all comp off credit approved so far
  double _compOffUsed = 0; // comp off credit taken as leave
  bool _isLoadingBalances = true;

  double get compOffBalance => _compOffBalance;
  double get compOffEarned => _compOffEarned;
  double get compOffUsed => _compOffUsed;

  // leaveType -> days held by the user's pending leave requests
  Map<String, double> _pendingDays = {};

  /// Days a leave request takes: half a day for a half-day shift, otherwise the
  /// number of days from the first to the last date.
  double leaveDaysFor(RequestModel request) {
    final isHalf =
        request.shift == 'First Half' ||
        request.shift == 'Second Half' ||
        request.shift == 'Half Day';
    if (isHalf) return 0.5;
    if (request.fromDate == null || request.toDate == null) return 1;
    return (request.toDate!.difference(request.fromDate!).inDays + 1)
        .toDouble();
  }

  /// Days of [leaveType] the employee can still ask for: the approved balance
  /// minus what pending requests already hold. Unpaid leave has no limit.
  double availableLeave(String leaveType) {
    if (leaveType == AppConstants.leaveTypeUL) return double.infinity;

    double balance;
    if (leaveType == AppConstants.leaveTypeCO) {
      balance = _compOffBalance;
    } else {
      final LeaveTypeBalance? type;
      switch (leaveType) {
        case AppConstants.leaveTypePL:
          type = _leaveAllocation?.privilege;
        case AppConstants.leaveTypeSL:
          type = _leaveAllocation?.sick;
        case AppConstants.leaveTypeCL:
          type = _leaveAllocation?.casual;
        default:
          type = null;
      }
      balance = type?.balance ?? 0;
    }
    final available = balance - (_pendingDays[leaveType] ?? 0);
    return available < 0 ? 0 : available;
  }

  List<RequestModel> get userRequests => _userRequests;
  List<RequestModel> get allRequests => _allRequests;
  bool get isLoading => _isLoading;

  // Apply Leave Form Getters
  DateTime get fromDate => _fromDate;
  DateTime get toDate => _toDate;
  DateTime get selectedDate => _selectedDate;
  String? get shift => _shift;
  String get halfDayShift => _halfDayShift;
  String? get selectedLeaveType => _selectedLeaveType;
  LeaveAllocationModel? get leaveAllocation => _leaveAllocation;
  bool get isLoadingBalances => _isLoadingBalances;

  // Initialize apply leave form
  void initializeApplyLeave() {
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _selectedDate = DateTime.now();
    _shift = null; // no selection by default
    _halfDayShift = 'First Half';
    _selectedLeaveType = null;
    notifyListeners();
  }

  // Update form fields
  void setFromDate(DateTime date) {
    _fromDate = date;
    if (_toDate.isBefore(_fromDate)) {
      _toDate = _fromDate;
    }
    notifyListeners();
  }

  void setToDate(DateTime date) {
    _toDate = date;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setShift(String shift) {
    _shift = shift;
    notifyListeners();
  }

  void setHalfDayShift(String halfDayShift) {
    _halfDayShift = halfDayShift;
    notifyListeners();
  }

  void setSelectedLeaveType(String? leaveType) {
    _selectedLeaveType = leaveType;
    notifyListeners();
  }

  int calculateLeaveDays() {
    if (_shift == 'Half Day') {
      return 1;
    } else {
      return _toDate.difference(_fromDate).inDays + 1;
    }
  }

  // --- Every employee's requests (admin screens) ---
  //
  // One Firestore listener serves every admin screen that shows requests (the
  // dashboard counts and recent list, and the Leave Requests screen). Opening
  // a screen, pressing refresh or coming back from another screen reuses it
  // instead of reading every request again.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _allRequestsSub;
  List<RequestModel> _allRequestsCache = [];
  bool _allRequestsLoaded = false;
  int _allRequestsListeners = 0;
  Timer? _allRequestsStopTimer;
  final StreamController<List<RequestModel>> _allRequestsChanges =
      StreamController<List<RequestModel>>.broadcast();

  // How long the listener stays on after the last screen stopped listening, so
  // a screen that swaps its stream (or one opened right after another) reuses it
  static const Duration _allRequestsGrace = Duration(seconds: 45);

  void _startAllRequests() {
    _allRequestsStopTimer?.cancel();
    _allRequestsStopTimer = null;

    _allRequestsSub ??= _firestore
        .collectionGroup(FirestoreSubCollections.requests)
        .orderBy('appliedOn', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            try {
              _allRequestsCache = snapshot.docs
                  .map((doc) => RequestModel.fromJson(doc.data()))
                  .toList();
              _allRequestsLoaded = true;
              _allRequestsChanges.add(_allRequestsCache);
            } catch (e) {
              logDebug('Error parsing request documents: $e');
            }
          },
          onError: (Object error) {
            logDebug('Error in all requests listener: $error');
            // Dropped, so the next screen to listen starts it again
            _allRequestsSub?.cancel();
            _allRequestsSub = null;
            _allRequestsLoaded = false;
            _allRequestsChanges.addError(error);
          },
        );
  }

  void _stopAllRequests() {
    _allRequestsSub?.cancel();
    _allRequestsSub = null;
    _allRequestsCache = [];
    _allRequestsLoaded = false;
  }

  /// Live list of every employee's requests, newest first, from the one shared
  /// listener. A new listener gets the current list straight away.
  Stream<List<RequestModel>> getAllRequestsStream() {
    return Stream.multi((controller) {
      _allRequestsListeners++;
      _startAllRequests();
      if (_allRequestsLoaded) controller.add(_allRequestsCache);

      final subscription = _allRequestsChanges.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = () {
        subscription.cancel();
        _allRequestsListeners--;
        if (_allRequestsListeners <= 0) {
          _allRequestsListeners = 0;
          _allRequestsStopTimer?.cancel();
          _allRequestsStopTimer = Timer(_allRequestsGrace, _stopAllRequests);
        }
      };
    }, isBroadcast: true);
  }

  Future<void> fetchUserRequests(
    String userId, {
    bool forceRefresh = false,
    String? type,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (forceRefresh) {
        _userRequests = [];
      }

      Query query = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreSubCollections.requests);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      QuerySnapshot requestQuery = await query
          .orderBy('appliedOn', descending: true)
          .get();

      _userRequests = requestQuery.docs
          .map(
            (doc) => RequestModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      logDebug("Error fetching user requests: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllRequests({String? type}) async {
    _isLoading = true;
    notifyListeners();

    try {
      Query query = _firestore.collectionGroup(
        FirestoreSubCollections.requests,
      );

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      QuerySnapshot requestQuery = await query
          .orderBy('appliedOn', descending: true)
          .get();

      _allRequests = requestQuery.docs
          .map(
            (doc) => RequestModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      logDebug("Error fetching all requests: $e");
      _allRequests = [];

      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        logDebug("Permission denied error - user may not have admin access");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // This year's leave as the home screen shows it (null when none allocated)
  LeaveBalanceModel? _leaveBalances;
  LeaveBalanceModel? get leaveBalances => _leaveBalances;

  /// Takes the user's live leave data from [MyDataProvider] (no reads here):
  /// the comp off credit, this year's leave, and the days held by requests that
  /// are still pending. Those days are held against the balance, so applying
  /// shows the count going down at once, an approval keeps it down, and a
  /// rejection gives it back.
  void setMyData(MyDataProvider my) {
    // A copy: cancelling removes from this list before the snapshot arrives
    _userRequests = List.of(my.requests);

    // Until the leave documents arrive the balances show as loading
    if (!my.leaveLoaded || !my.requestsLoaded) {
      _isLoadingBalances = true;
      Future.microtask(notifyListeners);
      return;
    }

    double comp(String key) => ((my.compOff?[key] ?? 0) as num).toDouble();
    _compOffBalance = comp('balance');
    _compOffEarned = comp('earned');
    _compOffUsed = comp('used');

    _pendingDays = {};
    for (final request in my.requests) {
      if (request.status != AppConstants.statusPending) continue;
      final leaveType = request.additionalData?['leaveType'] as String?;
      if (request.isLeaveRequest && leaveType != null) {
        _pendingDays[leaveType] =
            (_pendingDays[leaveType] ?? 0) + leaveDaysFor(request);
      }
    }

    final annual = my.annualLeave;
    _leaveAllocation = LeaveAllocationModel.tryFromJson(annual);
    _leaveBalances = annual == null
        ? null
        : LeaveBalanceModel.fromFirestore(annual);
    _isLoadingBalances = false;

    // Runs while the provider tree is updating, so notify afterwards
    Future.microtask(notifyListeners);
  }

  // Apply leave request with leave type
  Future<bool> applyLeave(
    UserModel user,
    DateTime fromDate,
    DateTime toDate,
    String shift,
    String reason,
    String leaveType, // PL, SL, or CL
  ) async {
    return await _applyRequest(
      RequestModel.leave(
        id: const Uuid().v4(),
        userId: user.id,
        userName: user.name,
        fromDate: fromDate,
        toDate: toDate,
        shift: shift,
        reason: reason,
        appliedOn: DateTime.now(),
        additionalData: {'leaveType': leaveType},
      ),
      AppConstants.leaveRequestNotification,
      "${user.name} has applied for ${RequestModel.leaveTypeFullName(leaveType)} ${_datePhrase(fromDate, toDate)}",
    );
  }

  /// Asks for comp off credit for a day the employee worked (for example a
  /// holiday or weekly off). [fromTime] and [toTime] are required for a half
  /// day. Returns null on success, or a message to show the user.
  Future<String?> applyCompOff(
    UserModel user,
    DateTime workedDate,
    bool isHalfDay,
    String reason, {
    required DateTime compOffDate,
    TimeOfDay? fromTime,
    TimeOfDay? toTime,
  }) async {
    final day = DateTime(workedDate.year, workedDate.month, workedDate.day);
    final offDay = DateTime(
      compOffDate.year,
      compOffDate.month,
      compOffDate.day,
    );

    try {
      // One request per worked day (a rejected one may be filed again)
      final existing = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.id)
          .collection(FirestoreSubCollections.requests)
          .where('type', isEqualTo: AppConstants.requestTypeCompOff)
          .get();
      final duplicate = existing.docs
          .map((doc) => RequestModel.fromJson(doc.data()))
          .any(
            (r) =>
                r.status != AppConstants.statusRejected &&
                r.date != null &&
                r.date!.year == day.year &&
                r.date!.month == day.month &&
                r.date!.day == day.day,
          );
      if (duplicate) {
        return 'You have already applied for comp off for this date';
      }
    } catch (e) {
      logDebug('Error checking existing comp off requests: $e');
    }

    String hhmm(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final success = await _applyRequest(
      RequestModel.compOff(
        id: const Uuid().v4(),
        userId: user.id,
        userName: user.name,
        date: day,
        shift: isHalfDay ? 'Half Day' : 'Full Day',
        reason: reason,
        appliedOn: DateTime.now(),
        additionalData: {
          'days': isHalfDay ? 0.5 : 1,
          // The day off asked for in return (shown on the calendar once approved)
          'compOffDate': offDay.toIso8601String(),
          if (isHalfDay && fromTime != null) 'fromTime': hhmm(fromTime),
          if (isHalfDay && toTime != null) 'toTime': hhmm(toTime),
        },
      ),
      AppConstants.compOffRequestNotification,
      "${user.name} has applied for ${isHalfDay ? 'half day' : 'full day'} comp off (worked ${_formatDate(day)}, off on ${_formatDate(offDay)})",
    );

    return success
        ? null
        : 'Failed to submit comp off request. Please try again.';
  }

  // Apply WFH request
  Future<bool> applyWFH(
    UserModel user,
    DateTime fromDate,
    DateTime toDate,
    String reason,
  ) async {
    return await _applyRequest(
      RequestModel.wfh(
        id: const Uuid().v4(),
        userId: user.id,
        userName: user.name,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
        appliedOn: DateTime.now(),
      ),
      AppConstants.wfhRequestNotification,
      "${user.name} has applied for work from home ${_datePhrase(fromDate, toDate)}",
    );
  }

  // Apply break request
  Future<bool> applyBreak(
    UserModel user,
    DateTime date,
    String reason, {
    Map<String, dynamic>? additionalData,
  }) async {
    return await _applyRequest(
      RequestModel.breakRequest(
        id: const Uuid().v4(),
        userId: user.id,
        userName: user.name,
        date: date,
        reason: reason,
        appliedOn: DateTime.now(),
        additionalData: additionalData,
      ),
      AppConstants.breakRequestNotification,
      "${user.name} has applied for a break on ${_formatDate(date)}",
    );
  }

  // Ids of everyone who can decide a request: all admins, plus sub admins who
  // were given the "approve leave requests" permission.
  Future<List<String>> _requestApproverIds() async {
    final ids = <String>{};
    final users = _firestore.collection(FirestoreCollections.users);

    // The two lookups do not depend on each other, so they run together
    final results = await Future.wait([
      users.where('isAdmin', isEqualTo: true).get(),
      users.where('isSubAdmin', isEqualTo: true).get(),
    ]);
    final admins = results[0];
    final subAdmins = results[1];

    ids.addAll(admins.docs.map((d) => d.id));
    for (final doc in subAdmins.docs) {
      final granted = doc.data()[Permissions.field];
      if (granted is List && granted.contains(Permissions.leaveRequests)) {
        ids.add(doc.id);
      }
    }

    return ids.toList();
  }

  // Tells the admins and sub admins allowed to approve requests about a new
  // [request], all at once. Never the person who applied (an admin or a sub
  // admin applying for their own leave): the others who can decide it are told.
  Future<void> _notifyApprovers(
    RequestModel request,
    String notificationType,
    String notificationBody,
  ) async {
    try {
      final approverIds = (await _requestApproverIds())
          .where((id) => id != request.userId)
          .toList();
      logDebug(
        'Found ${approverIds.length} approvers to notify about ${request.type} request',
      );

      final notificationData = <String, dynamic>{
        'requestId': request.id,
        'userId': request.userId,
        'type': notificationType,
        'requestType': request.type,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      // Add type-specific data
      if (request.isLeaveRequest || request.isWFHRequest) {
        notificationData['fromDate'] = request.fromDate?.millisecondsSinceEpoch
            .toString();
        notificationData['toDate'] = request.toDate?.millisecondsSinceEpoch
            .toString();
      } else if (request.isBreakRequest || request.isCompOffRequest) {
        notificationData['date'] = request.date?.millisecondsSinceEpoch
            .toString();
      }

      await _fcmService.sendNotificationToUsers(
        userIds: approverIds,
        title: "${request.fullTypeName} Request",
        body: notificationBody,
        data: notificationData,
      );
    } catch (e) {
      logDebug('Error notifying approvers: $e');
    }
  }

  // Generic method to apply any type of request
  Future<bool> _applyRequest(
    RequestModel request,
    String notificationType,
    String notificationBody,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      logDebug(
        'Applying ${request.type} request for user ${request.userName} (${request.userId})',
      );

      // Save to user's requests subcollection
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(request.userId)
          .collection(FirestoreSubCollections.requests)
          .doc(request.id)
          .set(request.toJson());

      logDebug(
        '${request.type} request saved to Firestore with ID: ${request.id}',
      );

      // The admins and sub admins who can approve it are told in the
      // background: the request is already saved, so the employee does not wait
      // for the pushes to go out
      unawaited(_notifyApprovers(request, notificationType, notificationBody));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      logDebug("Error applying ${request.type} request: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRequestStatus(
    RequestModel request,
    String status,
    String remark,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      logDebug(
        'Updating request status for request ID: ${request.id}, user: ${request.userName} (${request.userId})',
      );
      logDebug('New status: $status, Remark: $remark');

      // Update in user's requests subcollection
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(request.userId)
          .collection(FirestoreSubCollections.requests)
          .doc(request.id)
          .update({'status': status, 'adminRemark': remark});

      // If leave request is approved, deduct from balance
      if (status == AppConstants.statusApproved && request.isLeaveRequest) {
        await _deductLeaveBalance(request);
      }

      // An approved comp off request adds credit the employee can take as leave
      if (status == AppConstants.statusApproved && request.isCompOffRequest) {
        await _creditCompOff(request);
      }

      logDebug('Request status updated in Firestore');

      // Send notification to user
      try {
        String statusText = status == AppConstants.statusApproved
            ? "approved"
            : "rejected";

        Map<String, dynamic> notificationData = {
          'requestId': request.id,
          'status': status,
          'requestType': request.type,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'type': AppConstants.requestStatusUpdateNotification,
        };

        logDebug('Notification data: ${jsonEncode(notificationData)}');

        String notificationBody;
        if (request.isLeaveRequest || request.isWFHRequest) {
          notificationBody =
              "Your ${request.fullTypeName} request ${_datePhrase(request.fromDate!, request.toDate!)} has been $statusText";
        } else {
          notificationBody =
              "Your ${request.fullTypeName} request for ${request.displayDate} has been $statusText";
        }

        // In the background: the decision is already saved, so the admin does
        // not wait for the push to go out
        unawaited(
          _fcmService
              .sendNotificationToUser(
                userId: request.userId,
                title: "${request.fullTypeName} Status Update",
                body: notificationBody,
                data: notificationData,
              )
              .then(
                (sent) => logDebug(
                  sent
                      ? 'Request status notification sent to user: ${request.userId}'
                      : 'Failed to send request status notification to user: ${request.userId}',
                ),
              ),
        );
      } catch (e) {
        logDebug('Error sending notification: $e');
      }

      // A decided leave / WFH request changes the employee's monthly summary.
      // Best effort: a sub admin without attendance access just skips it, and
      // the history screen rebuilds the month when the employee opens it.
      // A comp off marks the day off that was asked for.
      final summaryFrom = request.isCompOffRequest
          ? request.compOffDate
          : request.fromDate;
      final summaryTo = request.isCompOffRequest
          ? request.compOffDate
          : request.toDate;
      if ((request.isLeaveRequest ||
              request.isWFHRequest ||
              request.isCompOffRequest) &&
          summaryFrom != null &&
          summaryTo != null) {
        unawaited(() async {
          try {
            await AttendanceSummaryService().rebuildMonthsBetween(
              request.userId,
              summaryFrom,
              summaryTo,
            );
          } catch (e) {
            logDebug('Could not update attendance summary: $e');
          }
        }());
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      logDebug("Error updating request status: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a pending request
  Future<bool> deletePendingRequest(RequestModel request) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Only allow deletion if status is pending
      if (request.status != AppConstants.statusPending) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Delete from user's requests subcollection
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(request.userId)
          .collection(FirestoreSubCollections.requests)
          .doc(request.id)
          .delete();

      // Update local list if needed
      _userRequests.removeWhere((item) => item.id == request.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      logDebug("Error deleting request: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Helper methods for filtering
  List<RequestModel> getLeaveRequests() {
    return _userRequests.where((request) => request.isLeaveRequest).toList();
  }

  List<RequestModel> getWFHRequests() {
    return _userRequests.where((request) => request.isWFHRequest).toList();
  }

  List<RequestModel> getBreakRequests() {
    return _userRequests.where((request) => request.isBreakRequest).toList();
  }

  // Helper method for date formatting
  // --- Records HR adds for leave an employee already took ---

  /// Saves the [entries] on [userId] as approved requests (no approval step)
  /// and applies what an approval would: the leave balance, or the comp off
  /// credit. The monthly summaries are rebuilt. Nothing else happens: no
  /// notification is sent, and the records then show wherever requests do
  /// (the employee's history and calendar, the admin leave requests, the
  /// attendance reports). Nothing is saved when a day already has a request.
  Future<PastRequestsResult> addPastRequests({
    required String userId,
    required String userName,
    required List<PastRequestEntry> entries,
  }) async {
    if (entries.isEmpty) {
      return const PastRequestsResult.failure('Add at least one record');
    }

    try {
      final requestsRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreSubCollections.requests);

      // The years a balance leave falls in: each needs a leave document to
      // move
      final leaveYears = [
        ...{
          for (final e in entries)
            if (e.kind == PastRequestKind.pl ||
                e.kind == PastRequestKind.sl ||
                e.kind == PastRequestKind.cl ||
                e.kind == PastRequestKind.ul)
              e.from.year,
        },
      ];

      // The employee's requests and the leave document of each year do not
      // depend on each other, so they are read together
      final existingFuture = requestsRef.get();
      final allocationFutures = [
        for (final year in leaveYears)
          _firestore
              .collection(FirestoreCollections.users)
              .doc(userId)
              .collection(FirestoreSubCollections.leaves)
              .doc(FirestoreDocs.annualLeave(year))
              .get(),
      ];
      final existingSnapshot = await existingFuture;
      final allocations = await Future.wait(allocationFutures);

      // Days that already have a request would be counted twice
      final existing = existingSnapshot.docs
          .map((doc) => RequestModel.fromJson(doc.data()))
          .where((r) => r.status != AppConstants.statusRejected)
          .toList();
      final conflict = _findPastConflict(entries, existing);
      if (conflict != null) return PastRequestsResult.failure(conflict);

      // A leave of a year with no allocation can not move a balance; it is
      // still saved, and HR is told
      final notes = <String>[];
      for (var i = 0; i < leaveYears.length; i++) {
        if (!allocations[i].exists) {
          notes.add(
            'No ${leaveYears[i]} leave allocation, so the used days of '
            '${leaveYears[i]} were not recorded',
          );
        }
      }

      final now = DateTime.now();
      final requests = [
        for (final entry in entries)
          _requestFromEntry(entry, userId, userName, now),
      ];

      final batch = _firestore.batch();
      for (final request in requests) {
        batch.set(requestsRef.doc(request.id), request.toJson());
      }
      await batch.commit();

      // Leave already taken is recorded as used days and lowers the balance;
      // the yearly allocation stays (see _recordPastLeave)
      // Each record changes the numbers with atomic increments, so they can be
      // recorded together instead of one after another
      await Future.wait([
        for (final request in requests)
          if (request.isCompOffRequest)
            // Earned and used at once, so the credit balance does not change
            _creditCompOff(request)
          else if (request.isLeaveRequest)
            _recordPastLeave(request),
      ]);

      // The calendar and history of the employee follow the new records. Each
      // month is rebuilt once, however many records fall in it.
      final months = <DateTime>{};
      for (final request in requests) {
        final from = request.isCompOffRequest
            ? request.compOffDate
            : request.fromDate;
        final to = request.isCompOffRequest
            ? request.compOffDate
            : request.toDate;
        if (from == null || to == null) continue;
        var month = DateTime(from.year, from.month);
        final last = DateTime(to.year, to.month);
        while (!month.isAfter(last)) {
          months.add(month);
          month = DateTime(month.year, month.month + 1);
        }
      }
      if (months.isNotEmpty) {
        unawaited(() async {
          try {
            await AttendanceSummaryService().rebuildMonthsForUser(
              userId,
              months.toList(),
            );
          } catch (e) {
            logDebug('Could not update attendance summary: $e');
          }
        }());
      }

      return PastRequestsResult.success(notes);
    } catch (e) {
      logDebug('Error adding past requests: $e');
      return const PastRequestsResult.failure(
        'Could not save the records. Please try again.',
      );
    }
  }

  DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

  // The approved request an entry becomes
  RequestModel _requestFromEntry(
    PastRequestEntry entry,
    String userId,
    String userName,
    DateTime now,
  ) {
    const remark = 'Added by HR';
    final reason = entry.reason.isEmpty ? remark : entry.reason;
    final from = _dayOf(entry.from);
    final to = _dayOf(entry.isHalfDay ? entry.from : entry.to);

    if (entry.kind == PastRequestKind.compOff) {
      return RequestModel.compOff(
        id: const Uuid().v4(),
        userId: userId,
        userName: userName,
        date: from,
        shift: entry.isHalfDay ? 'Half Day' : 'Full Day',
        reason: reason,
        status: AppConstants.statusApproved,
        adminRemark: remark,
        appliedOn: now,
        additionalData: {
          'days': entry.isHalfDay ? 0.5 : 1,
          'compOffDate': _dayOf(entry.compOffDate ?? entry.from)
              .toIso8601String(),
          'addedByHr': true,
        },
      );
    }

    if (entry.kind == PastRequestKind.wfh) {
      return RequestModel.wfh(
        id: const Uuid().v4(),
        userId: userId,
        userName: userName,
        fromDate: from,
        toDate: to,
        reason: reason,
        status: AppConstants.statusApproved,
        adminRemark: remark,
        appliedOn: now,
      );
    }

    return RequestModel.leave(
      id: const Uuid().v4(),
      userId: userId,
      userName: userName,
      fromDate: from,
      toDate: to,
      shift: entry.isHalfDay
          ? (entry.half ?? PastRequestEntry.firstHalf)
          : 'Full Day',
      reason: reason,
      status: AppConstants.statusApproved,
      adminRemark: remark,
      appliedOn: now,
      additionalData: {'leaveType': entry.kind.leaveCode, 'addedByHr': true},
    );
  }

  // True when two day spans share a day, except a first half and a second half
  // on the same single day, which can both be taken
  bool _spansClash(
    DateTime aFrom,
    DateTime aTo,
    String? aHalf,
    DateTime bFrom,
    DateTime bTo,
    String? bHalf,
  ) {
    if (aTo.isBefore(bFrom) || aFrom.isAfter(bTo)) return false;
    final bothSingleHalves =
        aHalf != null &&
        bHalf != null &&
        aHalf != bHalf &&
        aFrom == aTo &&
        bFrom == bTo;
    return !bothSingleHalves;
  }

  // A message about the first record that clashes with an existing request or
  // with another new one, or null when none does
  String? _findPastConflict(
    List<PastRequestEntry> entries,
    List<RequestModel> existing,
  ) {
    final fmt = DateFormat('dd MMM yyyy');

    String? halfOf(String? shift) =>
        (shift == PastRequestEntry.firstHalf ||
            shift == PastRequestEntry.secondHalf)
        ? shift
        : null;

    for (var i = 0; i < entries.length; i++) {
      final a = entries[i];

      if (a.kind == PastRequestKind.compOff) {
        final day = _dayOf(a.from);
        final clash = existing.any(
          (r) => r.isCompOffRequest && r.date != null && _dayOf(r.date!) == day,
        );
        if (clash) {
          return 'A comp off for ${fmt.format(day)} already exists';
        }
        final duplicate = entries
            .skip(i + 1)
            .any((b) => b.kind == PastRequestKind.compOff && _dayOf(b.from) == day);
        if (duplicate) {
          return 'Comp off for ${fmt.format(day)} is added twice';
        }
        continue;
      }

      final aFrom = _dayOf(a.from);
      final aTo = _dayOf(a.isHalfDay ? a.from : a.to);
      final aHalf = a.isHalfDay ? a.half : null;

      for (final r in existing) {
        if (!(r.isLeaveRequest || r.isWFHRequest)) continue;
        if (r.fromDate == null || r.toDate == null) continue;
        if (_spansClash(
          aFrom,
          aTo,
          aHalf,
          _dayOf(r.fromDate!),
          _dayOf(r.toDate!),
          halfOf(r.shift),
        )) {
          return '${a.kind.sectionTitle} on ${a.dateText} overlaps an '
              'existing request';
        }
      }

      for (final b in entries.skip(i + 1)) {
        if (b.kind == PastRequestKind.compOff) continue;
        if (_spansClash(
          aFrom,
          aTo,
          aHalf,
          _dayOf(b.from),
          _dayOf(b.isHalfDay ? b.from : b.to),
          b.isHalfDay ? b.half : null,
        )) {
          return '${a.kind.sectionTitle} on ${a.dateText} overlaps '
              '${b.kind.sectionTitle} on ${b.dateText}';
        }
      }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  // "on 30/10/2026" for one day, "from 30/10/2026 to 1/11/2026" for more
  String _datePhrase(DateTime from, DateTime to) {
    final sameDay =
        from.year == to.year && from.month == to.month && from.day == to.day;
    return sameDay
        ? "on ${_formatDate(from)}"
        : "from ${_formatDate(from)} to ${_formatDate(to)}";
  }

  // Deduct leave balance when admin approves leave
  // Helper to map leave type constants to Firestore field names
  String _getLeaveTypeFieldName(String leaveType) {
    switch (leaveType) {
      case AppConstants.leaveTypePL:
        return 'privilegeLeaves';
      case AppConstants.leaveTypeSL:
        return 'sickLeaves';
      case AppConstants.leaveTypeCL:
        return 'casualLeaves';
      default:
        return leaveType;
    }
  }

  /// Records leave the employee already took (before the app was in use). The
  /// yearly allocation set at onboarding does not change: the used days go up
  /// and the balance goes down. 10 SL allocated, 2 days recorded gives 10
  /// allocated, 2 used, 8 left. Unpaid leave only adds to the unpaid count. For
  /// comp off leave the credit is earned and used at once.
  Future<void> _recordPastLeave(RequestModel request) async {
    try {
      final leaveType = request.leaveType?.toLowerCase();
      if (leaveType == null) return;
      final days = request.requestedDays;

      // Unpaid leave has no balance: its days are only counted in the
      // employee's own unpaid total. PL, SL, CL and comp off are not touched.
      if (leaveType == AppConstants.leaveTypeUL) {
        await _addUnpaidDays(request.userId, request.fromDate!.year, days);
        return;
      }

      if (leaveType == AppConstants.leaveTypeCO) {
        await _compOffRef(request.userId).set({
          'earned': FieldValue.increment(days),
          'used': FieldValue.increment(days),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final field = _getLeaveTypeFieldName(leaveType);
      final leaveRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(request.userId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.annualLeave(request.fromDate!.year));

      // The balance of the year the leave falls in; a year with no allocation
      // has nothing to record on (the caller already told HR)
      final snapshot = await leaveRef.get();
      if (!snapshot.exists) return;

      // Same as an approved leave: the yearly allocation stays as set, the
      // used days go up and the balance goes down
      await leaveRef.update({
        '$field.used': FieldValue.increment(days),
        '$field.balance': FieldValue.increment(-days),
        'totalUsed': FieldValue.increment(days),
        'totalBalance': FieldValue.increment(-days),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      logDebug('Past leave recorded: $field +$days used, -$days balance');
    } catch (e) {
      logDebug('Error recording past leave: $e');
    }
  }

  /// Adds [days] to the unpaid leave taken (users/{uid}/leaves/annual_{year},
  /// field unpaidLeaves.used). Only that count moves. A year with no leave
  /// document has nothing to add to.
  Future<void> _addUnpaidDays(String userId, int year, double days) async {
    final ref = _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreSubCollections.leaves)
        .doc(FirestoreDocs.annualLeave(year));

    final snapshot = await ref.get();
    if (!snapshot.exists) {
      logDebug('No $year leave document for $userId: unpaid days not counted');
      return;
    }
    await ref.update({
      'unpaidLeaves.used': FieldValue.increment(days),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    logDebug('Unpaid leave counted: +$days day(s) for $userId in $year');
  }

  DocumentReference<Map<String, dynamic>> _compOffRef(String userId) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.compOffBalance);

  // Adds the approved comp off days to the employee's credit
  Future<void> _creditCompOff(RequestModel request) async {
    try {
      final days = request.compOffDays;
      // A request that names its day off is taken at once: the credit is
      // earned and used, so the balance does not change
      final takenAtOnce = request.compOffDate != null;
      await _compOffRef(request.userId).set({
        'earned': FieldValue.increment(days),
        if (takenAtOnce)
          'used': FieldValue.increment(days)
        else
          'balance': FieldValue.increment(days),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      logDebug('Comp off credited: $days day(s) for ${request.userId}');
    } catch (e) {
      logDebug('Error crediting comp off: $e');
    }
  }

  // Takes the approved comp off leave days out of the employee's credit
  Future<void> _useCompOff(RequestModel request) async {
    try {
      final isHalf =
          request.shift == 'First Half' || request.shift == 'Second Half';
      final days = isHalf
          ? 0.5
          : (request.toDate!.difference(request.fromDate!).inDays + 1)
                .toDouble();

      await _compOffRef(request.userId).set({
        'used': FieldValue.increment(days),
        'balance': FieldValue.increment(-days),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      logDebug('Comp off used: $days day(s) by ${request.userId}');
    } catch (e) {
      logDebug('Error using comp off: $e');
    }
  }

  Future<void> _deductLeaveBalance(RequestModel request) async {
    try {
      // Get leave type from additional data
      final leaveType = request.additionalData?['leaveType'] as String?;
      if (leaveType == null) {
        logDebug('Leave type not found in request additional data');
        return;
      }

      // Unpaid leave has no balance, so nothing is deducted: its days are only
      // added to the employee's unpaid total
      if (leaveType == AppConstants.leaveTypeUL) {
        await _addUnpaidDays(
          request.userId,
          request.fromDate!.year,
          request.requestedDays,
        );
        return;
      }

      // Comp off is taken from the earned credit, not from the yearly balance
      if (leaveType == AppConstants.leaveTypeCO) {
        await _useCompOff(request);
        return;
      }

      // Map to Firestore field name
      final leaveTypeField = _getLeaveTypeFieldName(leaveType);

      // Calculate days
      int days = request.toDate!.difference(request.fromDate!).inDays + 1;

      // Handle half days
      if (request.shift == 'First Half' || request.shift == 'Second Half') {
        days = 1; // Count as 0.5 in the update
      }

      // The balance of the year the leave falls in
      final leaveYear = request.fromDate!.year;
      final leaveRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(request.userId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.annualLeave(leaveYear));

      await _firestore.runTransaction((transaction) async {
        final leaveDoc = await transaction.get(leaveRef);

        if (!leaveDoc.exists) {
          logDebug('Leave allocation not found for user ${request.userId}');
          return;
        }

        final data = leaveDoc.data()!;
        final leaveTypeData = data[leaveTypeField] as Map<String, dynamic>?;

        if (leaveTypeData == null) {
          logDebug(
            'Leave type $leaveTypeField not found in user leave allocation',
          );
          return;
        }

        // Calculate days to deduct (0.5 for half day, full day otherwise)
        final daysToDeduct =
            (request.shift == 'First Half' || request.shift == 'Second Half')
            ? 0.5
            : days.toDouble();

        final currentUsed = (leaveTypeData['used'] ?? 0) as num;
        final currentBalance = (leaveTypeData['balance'] ?? 0) as num;

        final newUsed = currentUsed + daysToDeduct;
        final newBalance = currentBalance - daysToDeduct;

        if (newBalance < 0) {
          logDebug(
            'Warning: Insufficient leave balance for user ${request.userId}',
          );
          // Continue anyway as admin has already approved
        }

        // Update the specific leave type and totals
        transaction.update(leaveRef, {
          '$leaveTypeField.used': newUsed,
          '$leaveTypeField.balance': newBalance,
          // Not truncated, so a half day (0.5) is counted
          'totalUsed': FieldValue.increment(daysToDeduct),
          'totalBalance': FieldValue.increment(-daysToDeduct),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        logDebug(
          'Leave balance updated: $leaveTypeField - used: $newUsed, balance: $newBalance',
        );
      });
    } catch (e) {
      logDebug('Error deducting leave balance: $e');
      // Don't throw error, just log it so approval still succeeds
    }
  }
}
