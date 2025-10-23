import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_constants.dart';
import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/user_model.dart';
import '../services/fcm_service.dart';

class AttendanceProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  List<AttendanceModel> _userAttendance = [];
  List<AttendanceModel> _allAttendance = [];
  bool _isLoading = false;

  // Stream controllers
  Stream<List<AttendanceModel>>? _userAttendanceStream;
  Stream<List<AttendanceModel>>? _allAttendanceStream;

  List<AttendanceModel> get userAttendance => _userAttendance;
  List<AttendanceModel> get allAttendance => _allAttendance;
  bool get isLoading => _isLoading;
  Stream<List<AttendanceModel>>? get userAttendanceStream =>
      _userAttendanceStream;
  Stream<List<AttendanceModel>>? get allAttendanceStream =>
      _allAttendanceStream;

  // Get real-time stream of user attendance
  Stream<List<AttendanceModel>> getUserAttendanceStream(String userId) {
    // Temporary solution to avoid index requirement
    // This fetches all records for the user without ordering in Firestore
    // and then sorts them in memory
    _userAttendanceStream = _firestore
        .collection(AppConstants.attendanceCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final attendanceList = snapshot.docs
          .map((doc) =>
              AttendanceModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Sort in memory by date (descending)
      attendanceList.sort((a, b) => b.date.compareTo(a.date));

      return attendanceList;
    });

    return _userAttendanceStream!;
  }

  // Get real-time stream of all attendance
  Stream<List<AttendanceModel>> getAllAttendanceStream() {
    _allAttendanceStream = _firestore
        .collection(AppConstants.attendanceCollection)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              AttendanceModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });

    return _allAttendanceStream!;
  }

  // Get today's attendance for a user
  Future<AttendanceModel?> getTodayAttendance(String userId,
      {bool notify = true}) async {
    if (notify) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // Get today's date at midnight
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Query for today's attendance
      QuerySnapshot attendanceQuery = await _firestore
          .collection(AppConstants.attendanceCollection)
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: today)
          .where('date', isLessThan: today.add(const Duration(days: 1)))
          .get();

      if (notify) {
        _isLoading = false;
        notifyListeners();
      }

      if (attendanceQuery.docs.isEmpty) {
        return null;
      }

      return AttendanceModel.fromJson(
          attendanceQuery.docs.first.data() as Map<String, dynamic>);
    } catch (e) {
      print("Error fetching today's attendance: $e");
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
      return null;
    }
  }

  // Check if user has leave for today
  Future<LeaveModel?> checkLeaveForToday(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      QuerySnapshot leaveQuery = await _firestore
          .collection(AppConstants.leaveCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: AppConstants.statusApproved)
          .get();

      // Check if any approved leave includes today
      for (var doc in leaveQuery.docs) {
        final leave = LeaveModel.fromJson(doc.data() as Map<String, dynamic>);
        final fromDate = DateTime(
            leave.fromDate.year, leave.fromDate.month, leave.fromDate.day);
        final toDate =
            DateTime(leave.toDate.year, leave.toDate.month, leave.toDate.day);

        if ((today.isAtSameMomentAs(fromDate) || today.isAfter(fromDate)) &&
            (today.isAtSameMomentAs(toDate) || today.isBefore(toDate))) {
          return leave;
        }
      }

      return null;
    } catch (e) {
      print("Error checking leave for today: $e");
      return null;
    }
  }

  // Punch in
  Future<bool> punchIn(UserModel user) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check if already punched in today
      AttendanceModel? todayAttendance = await getTodayAttendance(user.id);

      // Check if on leave today
      LeaveModel? todayLeave = await checkLeaveForToday(user.id);
      if (todayLeave != null) {
        _isLoading = false;
        notifyListeners();
        return false; // Can't punch in if on leave
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (todayAttendance != null) {
        // Already has an attendance record for today
        if (todayAttendance.punchInTime != null) {
          // Already punched in
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Update existing record with punch in time
        await _firestore
            .collection(AppConstants.attendanceCollection)
            .doc(todayAttendance.id)
            .update({
          'punchInTime': now,
          'status': AppConstants
              .statusPending, // Set status to pending until punch out
        });

        todayAttendance = todayAttendance.copyWith(
          punchInTime: now,
          status: AppConstants
              .statusPending, // Set status to pending until punch out
        );
      } else {
        // Create new attendance record
        String attendanceId = const Uuid().v4();

        todayAttendance = AttendanceModel(
          id: attendanceId,
          userId: user.id,
          userName: user.name,
          date: today,
          punchInTime: now,
          status: AppConstants
              .statusPending, // Set status to pending until punch out
        );

        await _firestore
            .collection(AppConstants.attendanceCollection)
            .doc(attendanceId)
            .set(todayAttendance.toJson());
      }

      // Notify admins
      await _notifyAdmins(
        user,
        AppConstants.punchInNotification,
        "Punch In",
        "${user.name} has punched in at ${DateFormat('hh:mm a').format(now)}",
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print("Error punching in: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Punch out
  Future<bool> punchOut(UserModel user) async {
    try {
      // Check if user is on leave today
      final leaveModel = await checkLeaveForToday(user.id);
      if (leaveModel != null) {
        return false; // User is on leave, can't punch out
      }

      // Get today's attendance
      final attendance = await getTodayAttendance(user.id);

      // Can only punch out if already punched in
      if (attendance == null || attendance.punchInTime == null) {
        return false;
      }

      // Can't punch out if already punched out
      if (attendance.punchOutTime != null) {
        return false;
      }

      // Update attendance with punch out time and set status to present
      final now = DateTime.now();
      final updatedAttendance = attendance.copyWith(
        punchOutTime: now,
        status:
            AppConstants.statusPresent, // Set status to present after punch out
      );

      await _firestore
          .collection(AppConstants.attendanceCollection)
          .doc(attendance.id)
          .update(updatedAttendance.toJson());

      // Notify admins
      await _notifyAdmins(
        user,
        AppConstants.punchOutNotification,
        'Punch Out',
        '${user.name} has punched out at ${DateFormat('hh:mm a').format(now)}',
      );

      return true;
    } catch (e) {
      print('Error punching out: $e');
      return false;
    }
  }

  // Notify admins
  Future<void> _notifyAdmins(
    UserModel user,
    String notificationType,
    String title,
    String body,
  ) async {
    try {
      // Try to get admin users by isAdmin field first
      QuerySnapshot adminSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('isAdmin', isEqualTo: true)
          .get();

      // If no admins found, try with role field
      if (adminSnapshot.docs.isEmpty) {
        adminSnapshot = await _firestore
            .collection(AppConstants.usersCollection)
            .where('role', isEqualTo: AppConstants.adminRole)
            .get();
      }

      log("Found ${adminSnapshot.docs.length} admin users to notify");

      for (var doc in adminSnapshot.docs) {
        final adminId = doc.id;
        if (adminId != user.id) {
          // Don't notify the user themselves
          log("Sending notification to admin: $adminId");

          // Send notification
          await _fcmService.sendNotificationToUser(
            userId: adminId,
            title: title,
            body: body,
            data: {
              'userId': user.id,
              'userName': user.name,
              'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
              'type': notificationType,
            },
          );
        }
      }
    } catch (e) {
      log('Error notifying admins: $e');
    }
  }

  // Get all attendance records (not as stream)
  Future<List<AttendanceModel>> getAllAttendance() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection(AppConstants.attendanceCollection)
          .orderBy('date', descending: true)
          .get();

      final attendanceList = snapshot.docs
          .map((doc) => AttendanceModel.fromJson(doc.data()))
          .toList();

      _isLoading = false;
      notifyListeners();

      return attendanceList;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error getting all attendance: $e');
      return [];
    }
  }

  // Get user's attendance records (not as stream)
  Future<List<AttendanceModel>> getUserAttendance(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection(AppConstants.attendanceCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final attendanceList = snapshot.docs
          .map((doc) => AttendanceModel.fromJson(doc.data()))
          .toList();

      // Sort in memory by date (descending)
      attendanceList.sort((a, b) => b.date.compareTo(a.date));

      _isLoading = false;
      notifyListeners();

      return attendanceList;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error getting user attendance: $e');
      return [];
    }
  }

  // Check if user has attendance for a specific date
  bool hasAttendanceForDate(String userId, DateTime date) {
    if (_allAttendance.isEmpty) return false;

    return _allAttendance.any((attendance) =>
        attendance.userId == userId &&
        attendance.date.year == date.year &&
        attendance.date.month == date.month &&
        attendance.date.day == date.day);
  }

  // Mark an employee as absent for a specific date
  Future<bool> markAbsent(UserModel employee, DateTime date) async {
    try {
      // Check if already has attendance for this date
      if (hasAttendanceForDate(employee.id, date)) {
        return false;
      }

      // Create new attendance record with absent status
      final String id = const Uuid().v4();
      final attendanceModel = AttendanceModel(
        id: id,
        userId: employee.id,
        userName: employee.name,
        date: DateTime(date.year, date.month, date.day),
        punchInTime: null,
        punchOutTime: null,
        status: AppConstants.statusAbsent,
        leaveId: null,
      );

      await _firestore
          .collection(AppConstants.attendanceCollection)
          .doc(id)
          .set(attendanceModel.toJson());

      return true;
    } catch (e) {
      print('Error marking absent: $e');
      return false;
    }
  }
}
