import 'dart:developer';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_constants.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
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
  Map<String, dynamic>? _leaveBalances;
  bool _isLoadingBalances = true;

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
  Map<String, dynamic>? get leaveBalances => _leaveBalances;
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
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.userRequestsCollection);

    // Filter by type if specified
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    _userRequestsStream = query
        .orderBy('appliedOn', descending: true)
        .snapshots()
        .handleError((error) {
          log('Error in getUserRequestsStream: $error');
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
            log('Error parsing user request documents: $e');
            return <RequestModel>[];
          }
        });

    return _userRequestsStream!;
  }

  // Get real-time stream of all requests (for admin view)
  Stream<List<RequestModel>> getAllRequestsStream({String? type}) {
    Query query = _firestore.collectionGroup(
      AppConstants.userRequestsCollection,
    );

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    _allRequestsStream = query
        .orderBy('appliedOn', descending: true)
        .snapshots()
        .handleError((error) {
          log('Error in getAllRequestsStream: $error');
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
            log('Error parsing request documents: $e');
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
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.userRequestsCollection);

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
      log("Error fetching user requests: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllRequests({String? type}) async {
    _isLoading = true;
    notifyListeners();

    try {
      Query query = _firestore.collectionGroup(
        AppConstants.userRequestsCollection,
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
      log("Error fetching all requests: $e");
      _allRequests = [];

      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        log("Permission denied error - user may not have admin access");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // Get user leave balances
  Future<Map<String, dynamic>?> getUserLeaveBalances(String userId) async {
    try {
      _isLoadingBalances = true;
      notifyListeners();

      final currentYear = DateTime.now().year;
      final leaveDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.leavesCollection)
          .doc('annual_$currentYear')
          .get();

      if (leaveDoc.exists) {
        _leaveBalances = leaveDoc.data();
        _isLoadingBalances = false;
        notifyListeners();
        return leaveDoc.data();
      }
      _isLoadingBalances = false;
      notifyListeners();
      return null;
    } catch (e) {
      log('Error fetching leave balances: $e');
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

  // Generic method to apply any type of request
  Future<bool> _applyRequest(
    RequestModel request,
    String notificationType,
    String notificationBody,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      log(
        'Applying ${request.type} request for user ${request.userName} (${request.userId})',
      );

      // Save to user's requests subcollection
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(request.userId)
          .collection(AppConstants.userRequestsCollection)
          .doc(request.id)
          .set(request.toJson());

      log('${request.type} request saved to Firestore with ID: ${request.id}');

      // Fetch admins to notify
      QuerySnapshot adminSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('isAdmin', isEqualTo: true)
          .get();

      log(
        'Found ${adminSnapshot.docs.length} admin users to notify about ${request.type} request',
      );

      // Send notification to all admins
      for (var adminDoc in adminSnapshot.docs) {
        String adminId = adminDoc.id;
        log('Preparing to notify admin: $adminId');

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
          } else if (request.isBreakRequest) {
            notificationData['date'] = request.date?.millisecondsSinceEpoch
                .toString();
          }

          log('Notification data: ${jsonEncode(notificationData)}');

          bool notificationSent = await _fcmService.sendNotificationToUser(
            userId: adminId,
            title: "${request.typeDisplayName} Request",
            body: notificationBody,
            data: notificationData,
          );

          if (notificationSent) {
            log(
              '${request.type} request notification sent successfully to admin: $adminId',
            );
          } else {
            log(
              'Failed to send ${request.type} request notification to admin: $adminId',
            );
          }
        } catch (e) {
          log('Error sending notification to admin: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      log("Error applying ${request.type} request: $e");
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
      log(
        'Updating request status for request ID: ${request.id}, user: ${request.userName} (${request.userId})',
      );
      log('New status: $status, Remark: $remark');

      // Update in user's requests subcollection
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(request.userId)
          .collection(AppConstants.userRequestsCollection)
          .doc(request.id)
          .update({'status': status, 'adminRemark': remark});

      // If leave request is approved, deduct from balance
      if (status == AppConstants.statusApproved && request.isLeaveRequest) {
        await _deductLeaveBalance(request);
      }

      log('Request status updated in Firestore');

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

        log('Notification data: ${jsonEncode(notificationData)}');

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
          log(
            'Request status notification sent successfully to user: ${request.userId}',
          );
        } else {
          log(
            'Failed to send request status notification to user: ${request.userId}',
          );
        }
      } catch (e) {
        log('Error sending notification: $e');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      log("Error updating request status: $e");
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
          .collection(AppConstants.usersCollection)
          .doc(request.userId)
          .collection(AppConstants.userRequestsCollection)
          .doc(request.id)
          .delete();

      // Update local list if needed
      _userRequests.removeWhere((item) => item.id == request.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      log("Error deleting request: $e");
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

  Future<void> _deductLeaveBalance(RequestModel request) async {
    try {
      // Get leave type from additional data
      final leaveType = request.additionalData?['leaveType'] as String?;
      if (leaveType == null) {
        log('Leave type not found in request additional data');
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
          .collection(AppConstants.usersCollection)
          .doc(request.userId)
          .collection(AppConstants.leavesCollection)
          .doc('annual_$currentYear');

      await _firestore.runTransaction((transaction) async {
        final leaveDoc = await transaction.get(leaveRef);

        if (!leaveDoc.exists) {
          log('Leave allocation not found for user ${request.userId}');
          return;
        }

        final data = leaveDoc.data()!;
        final leaveTypeData = data[leaveTypeField] as Map<String, dynamic>?;

        if (leaveTypeData == null) {
          log('Leave type $leaveTypeField not found in user leave allocation');
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
          log('Warning: Insufficient leave balance for user ${request.userId}');
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

        log(
          'Leave balance updated: $leaveTypeField - used: $newUsed, balance: $newBalance',
        );
      });
    } catch (e) {
      log('Error deducting leave balance: $e');
      // Don't throw error, just log it so approval still succeeds
    }
  }
}
