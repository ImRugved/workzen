import 'dart:developer';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_constants.dart';
import '../models/leave_model.dart';
import '../models/user_model.dart';
import '../services/fcm_service.dart';

class LeaveProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  List<LeaveModel> _userLeaves = [];
  List<LeaveModel> _allLeaves = [];
  bool _isLoading = false;

  // Stream controllers
  Stream<List<LeaveModel>>? _userLeavesStream;
  Stream<List<LeaveModel>>? _allLeavesStream;

  List<LeaveModel> get userLeaves => _userLeaves;
  List<LeaveModel> get allLeaves => _allLeaves;
  bool get isLoading => _isLoading;
  Stream<List<LeaveModel>>? get userLeavesStream => _userLeavesStream;
  Stream<List<LeaveModel>>? get allLeavesStream => _allLeavesStream;

  // Get real-time stream of user leaves
  Stream<List<LeaveModel>> getUserLeavesStream(String userId) {
    _userLeavesStream = _firestore
        .collection(AppConstants.leaveCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LeaveModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.appliedOn.compareTo(a.appliedOn));
    });

    return _userLeavesStream!;
  }

  // Get real-time stream of all leaves
  Stream<List<LeaveModel>> getAllLeavesStream() {
    _allLeavesStream = _firestore
        .collection(AppConstants.leaveCollection)
        .orderBy('appliedOn', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LeaveModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });

    return _allLeavesStream!;
  }

  Future<void> fetchUserLeaves(String userId,
      {bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear existing leaves if forcing refresh
      if (forceRefresh) {
        _userLeaves = [];
      }

      QuerySnapshot leaveQuery = await _firestore
          .collection(AppConstants.leaveCollection)
          .where('userId', isEqualTo: userId)
          .get();

      _userLeaves = leaveQuery.docs
          .map((doc) => LeaveModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Sort by applied date, newest first
      _userLeaves.sort((a, b) => b.appliedOn.compareTo(a.appliedOn));
    } catch (e) {
      print("Error fetching user leaves: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllLeaves() async {
    _isLoading = true;
    notifyListeners();

    try {
      QuerySnapshot leaveQuery = await _firestore
          .collection(AppConstants.leaveCollection)
          .orderBy('appliedOn', descending: true)
          .get();

      _allLeaves = leaveQuery.docs
          .map((doc) => LeaveModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Error fetching all leaves: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> applyLeave(
    UserModel user,
    DateTime fromDate,
    DateTime toDate,
    String shift,
    String reason,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      log('Applying leave for user ${user.name} (${user.id})');
      String leaveId = const Uuid().v4();

      LeaveModel newLeave = LeaveModel(
        id: leaveId,
        userId: user.id,
        userName: user.name,
        fromDate: fromDate,
        toDate: toDate,
        shift: shift,
        reason: reason,
        status: AppConstants.statusPending,
        appliedOn: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.leaveCollection)
          .doc(leaveId)
          .set(newLeave.toJson());

      log('Leave application saved to Firestore with ID: $leaveId');

      // Fetch admins to notify
      QuerySnapshot adminSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('isAdmin', isEqualTo: true)
          .get();

      log('Found ${adminSnapshot.docs.length} admin users to notify about leave application');

      // Send notification to all admins
      for (var adminDoc in adminSnapshot.docs) {
        String adminId = adminDoc.id;
        log('Preparing to notify admin: $adminId');

        try {
          Map<String, dynamic> notificationData = {
            'leaveId': leaveId,
            'fromDate': fromDate.millisecondsSinceEpoch.toString(),
            'toDate': toDate.millisecondsSinceEpoch.toString(),
            'employeeId': user.id, // This is the employee's ID for context
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'type': AppConstants.leaveRequestNotification,
          };

          log('Notification data: ${jsonEncode(notificationData)}');

          await _fcmService.sendNotificationToUser(
            userId: adminId,
            title: "Leave Request",
            body:
                "${user.name} has applied for leave from ${_formatDate(fromDate)} to ${_formatDate(toDate)}",
            data: notificationData,
          );
          log('Leave application notification sent to admin: $adminId');
        } catch (e) {
          log('Error sending notification to admin: $e');
          // Continue with the process even if notification fails
        }
      }

      // No need to manually update the lists as the streams will handle it
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      log("Error applying leave: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateLeaveStatus(
    LeaveModel leave,
    String status,
    String remark,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      log('Updating leave status for leave ID: ${leave.id}, user: ${leave.userName} (${leave.userId})');
      log('New status: $status, Remark: $remark');

      // Update in Firestore
      await _firestore
          .collection(AppConstants.leaveCollection)
          .doc(leave.id)
          .update({
        'status': status,
        'adminRemark': remark,
      });

      log('Leave status updated in Firestore');

      // Get user token using FCM service
      try {
        String statusText =
            status == AppConstants.statusApproved ? "approved" : "rejected";

        Map<String, dynamic> notificationData = {
          'leaveId': leave.id,
          'status': status,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'type': AppConstants.leaveStatusUpdateNotification,
        };

        log('Notification data: ${jsonEncode(notificationData)}');

        await _fcmService.sendNotificationToUser(
          userId: leave.userId,
          title: "Leave Status Update",
          body:
              "Your leave request from ${_formatDate(leave.fromDate)} to ${_formatDate(leave.toDate)} has been $statusText",
          data: notificationData,
        );
        log('Leave status notification sent to user: ${leave.userId}');
      } catch (e) {
        log('Error sending notification: $e');
        // Continue with the process even if notification fails
      }

      // No need to manually update the lists as the streams will handle it
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      log("Error updating leave status: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a pending leave request
  Future<bool> deletePendingLeave(LeaveModel leave) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Only allow deletion if status is pending
      if (leave.status != AppConstants.statusPending) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Delete the leave request from Firestore
      await _firestore
          .collection(AppConstants.leaveCollection)
          .doc(leave.id)
          .delete();

      // Update local list if needed
      _userLeaves.removeWhere((item) => item.id == leave.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print("Error deleting leave request: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Helper method for date formatting
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
