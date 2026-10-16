import 'dart:async';
import 'dart:developer';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:workzen/utils/logger.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../constants/permissions.dart';
import '../models/leave_allocation_model.dart';
import '../models/leave_balance_model.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
import '../services/attendance_summary_service.dart';
import '../services/fcm_service.dart';

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  List<RequestModel> _userRequests = [];
  List<RequestModel> _allRequests = [];
  bool _isLoading = false;

  // Stream controllers
  Stream<List<RequestModel>>? _userRequestsStream;
  Stream<List<RequestModel>>? _allRequestsStream;

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
  /// minus what pending requests already hold.
  double availableLeave(String leaveType) {
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
  Stream<List<RequestModel>>? get userRequestsStream => _userRequestsStream;
  Stream<List<RequestModel>>? get allRequestsStream => _allRequestsStream;

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

  // Get real-time stream of user requests
  Stream<List<RequestModel>> getUserRequestsStream(
    String userId, {
    String? type,
  }) {
    Query query = _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreSubCollections.requests);

    // Filter by type if specified
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    _userRequestsStream = query
        .orderBy('appliedOn', descending: true)
        .snapshots()
        .handleError((error) {
          logDebug('Error in getUserRequestsStream: $error');
          return <RequestModel>[];
        })
        .map((snapshot) {
          try {
            return snapshot.docs
                .map(
                  (doc) =>
                      RequestModel.fromJson(doc.data() as Map<String, dynamic>),
                )
                .toList();
          } catch (e) {
            logDebug('Error parsing user request documents: $e');
            return <RequestModel>[];
          }
        });

    return _userRequestsStream!;
  }

  // Get real-time stream of all requests (for admin view)
  Stream<List<RequestModel>> getAllRequestsStream({String? type}) {
    Query query = _firestore.collectionGroup(
      FirestoreSubCollections.requests,
    );

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    _allRequestsStream = query
        .orderBy('appliedOn', descending: true)
        .snapshots()
        .handleError((error) {
          logDebug('Error in getAllRequestsStream: $error');
          return <RequestModel>[];
        })
        .map((snapshot) {
          try {
            return snapshot.docs
                .map(
                  (doc) =>
                      RequestModel.fromJson(doc.data() as Map<String, dynamic>),
                )
                .toList();
          } catch (e) {
            logDebug('Error parsing request documents: $e');
            return <RequestModel>[];
          }
        });

    return _allRequestsStream!;
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

  /// Fires whenever something that changes the employee's leave balances
  /// changes in Firestore: this year's leave document, the comp off credit, or
  /// any of their requests (an admin approving or rejecting one). The first
  /// snapshots are skipped, so it only reports later changes.
  Stream<void> leaveBalanceChanges(String userId) {
    final controller = StreamController<void>();
    final subscriptions = <StreamSubscription<dynamic>>[];

    void emit(dynamic _) {
      if (!controller.isClosed) controller.add(null);
    }

    final userDoc = _firestore
        .collection(FirestoreCollections.users)
        .doc(userId);
    final leaves = userDoc.collection(FirestoreSubCollections.leaves);

    subscriptions.addAll([
      leaves
          .doc(FirestoreDocs.annualLeave(DateTime.now().year))
          .snapshots()
          .skip(1)
          .listen(emit, onError: (_) {}),
      leaves
          .doc(FirestoreDocs.compOffBalance)
          .snapshots()
          .skip(1)
          .listen(emit, onError: (_) {}),
      userDoc
          .collection(FirestoreSubCollections.requests)
          .snapshots()
          .skip(1)
          .listen(emit, onError: (_) {}),
    ]);

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
    return controller.stream;
  }

  // Get user leave balances
  Future<LeaveBalanceModel?> getUserLeaveBalances(String userId) async {
    try {
      _isLoadingBalances = true;
      notifyListeners();

      // Comp off credit (not tied to a year)
      final compOffDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.compOffBalance)
          .get();
      _compOffBalance = ((compOffDoc.data()?['balance'] ?? 0) as num)
          .toDouble();
      _compOffEarned = ((compOffDoc.data()?['earned'] ?? 0) as num).toDouble();
      _compOffUsed = ((compOffDoc.data()?['used'] ?? 0) as num).toDouble();

      // Days already asked for in requests still waiting for a decision. They
      // are held against the balance, so applying shows the count going down
      // at once, an approval keeps it down, and a rejection gives it back.
      final pendingSnap = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreSubCollections.requests)
          .where('status', isEqualTo: AppConstants.statusPending)
          .get();
      _pendingDays = {};
      for (final doc in pendingSnap.docs) {
        final request = RequestModel.fromJson(doc.data());
        final leaveType = request.additionalData?['leaveType'] as String?;
        if (request.isLeaveRequest && leaveType != null) {
          _pendingDays[leaveType] =
              (_pendingDays[leaveType] ?? 0) + leaveDaysFor(request);
        }
      }

      final currentYear = DateTime.now().year;
      final leaveDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.annualLeave(currentYear))
          .get();

      _leaveAllocation = LeaveAllocationModel.tryFromJson(leaveDoc.data());
      _isLoadingBalances = false;
      notifyListeners();
      return leaveDoc.exists
          ? LeaveBalanceModel.fromFirestore(leaveDoc.data()!)
          : null;
    } catch (e) {
      logDebug('Error fetching leave balances: $e');
      _isLoadingBalances = false;
      notifyListeners();
      return null;
    }
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
      "${user.name} has applied for ${leaveType.toUpperCase()} leave from ${_formatDate(fromDate)} to ${_formatDate(toDate)}",
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
    final offDay = DateTime(compOffDate.year, compOffDate.month, compOffDate.day);

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

    return success ? null : 'Failed to submit comp off request. Please try again.';
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
      "${user.name} has applied for work from home from ${_formatDate(fromDate)} to ${_formatDate(toDate)}",
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

    final admins = await users.where('isAdmin', isEqualTo: true).get();
    ids.addAll(admins.docs.map((d) => d.id));

    final subAdmins = await users.where('isSubAdmin', isEqualTo: true).get();
    for (final doc in subAdmins.docs) {
      final granted = doc.data()[Permissions.field];
      if (granted is List && granted.contains(Permissions.leaveRequests)) {
        ids.add(doc.id);
      }
    }

    return ids.toList();
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

      // Admins and sub admins allowed to approve requests are notified
      final approverIds = await _requestApproverIds();

      logDebug(
        'Found ${approverIds.length} approvers to notify about ${request.type} request',
      );

      for (final adminId in approverIds) {
        logDebug('Preparing to notify approver: $adminId');

        try {
          Map<String, dynamic> notificationData = {
            'requestId': request.id,
            'userId': request.userId,
            'type': notificationType,
            'requestType': request.type,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          };

          // Add type-specific data
          if (request.isLeaveRequest || request.isWFHRequest) {
            notificationData['fromDate'] = request
                .fromDate
                ?.millisecondsSinceEpoch
                .toString();
            notificationData['toDate'] = request.toDate?.millisecondsSinceEpoch
                .toString();
          } else if (request.isBreakRequest || request.isCompOffRequest) {
            notificationData['date'] = request.date?.millisecondsSinceEpoch
                .toString();
          }

          logDebug('Notification data: ${jsonEncode(notificationData)}');

          bool notificationSent = await _fcmService.sendNotificationToUser(
            userId: adminId,
            title: "${request.typeDisplayName} Request",
            body: notificationBody,
            data: notificationData,
          );

          if (notificationSent) {
            logDebug(
              '${request.type} request notification sent successfully to admin: $adminId',
            );
          } else {
            logDebug(
              'Failed to send ${request.type} request notification to admin: $adminId',
            );
          }
        } catch (e) {
          logDebug('Error sending notification to admin: $e');
        }
      }

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
              "Your ${request.typeDisplayName.toLowerCase()} request from ${_formatDate(request.fromDate!)} to ${_formatDate(request.toDate!)} has been $statusText";
        } else {
          notificationBody =
              "Your ${request.typeDisplayName.toLowerCase()} request for ${request.displayDate} has been $statusText";
        }

        bool notificationSent = await _fcmService.sendNotificationToUser(
          userId: request.userId,
          title: "${request.typeDisplayName} Status Update",
          body: notificationBody,
          data: notificationData,
        );

        if (notificationSent) {
          logDebug(
            'Request status notification sent successfully to user: ${request.userId}',
          );
        } else {
          logDebug(
            'Failed to send request status notification to user: ${request.userId}',
          );
        }
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
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
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

      final currentYear = DateTime.now().year;
      final leaveRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(request.userId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.annualLeave(currentYear));

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
          'totalUsed': FieldValue.increment(daysToDeduct.toInt()),
          'totalBalance': FieldValue.increment(-daysToDeduct.toInt()),
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
