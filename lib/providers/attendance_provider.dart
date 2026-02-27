import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:workzen/utils/logger.dart';
import '../app_constants.dart';
import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
import '../services/fcm_service.dart';

class AttendanceProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  List<AttendanceModel> _userAttendance = [];
  List<AttendanceModel> _allAttendance = [];
  bool _isLoading = false;

  // Today's attendance screen state
  AttendanceModel? _todayAttendance;
  LeaveModel? _todayLeave;
  bool? _isAtOffice;

  // Stream controllers
  Stream<List<AttendanceModel>>? _userAttendanceStream;
  Stream<List<AttendanceModel>>? _allAttendanceStream;

  List<AttendanceModel> get userAttendance => _userAttendance;
  List<AttendanceModel> get allAttendance => _allAttendance;
  bool get isLoading => _isLoading;
  AttendanceModel? get todayAttendance => _todayAttendance;
  LeaveModel? get todayLeave => _todayLeave;
  bool? get isAtOffice => _isAtOffice;
  Stream<List<AttendanceModel>>? get userAttendanceStream =>
      _userAttendanceStream;
  Stream<List<AttendanceModel>>? get allAttendanceStream =>
      _allAttendanceStream;

  // Load today's attendance and leave data for the attendance screen
  Future<void> loadTodayData(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _todayAttendance = await getTodayAttendance(userId, notify: false);
      _todayLeave = await checkLeaveForToday(userId);
    } catch (e) {
      logDebug('Error loading today data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Check if user is within office range and update state
  void checkOfficeStatus(double? userLat, double? userLng, UserModel user) {
    final officeLat = user.officeLatitude ?? 18.5679456;
    final officeLng = user.officeLongitude ?? 73.7686132;

    if (userLat == null || userLng == null) {
      _isAtOffice = false;
      notifyListeners();
      return;
    }

    final distance = _calculateDistance(userLat, userLng, officeLat, officeLng);
    logDebug('Distance from office: ${distance.toStringAsFixed(2)} meters');
    _isAtOffice = distance <= 20.0;
    notifyListeners();
  }

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
              .map(
                (doc) => AttendanceModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                ),
              )
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
              .map(
                (doc) => AttendanceModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
        });

    return _allAttendanceStream!;
  }

  // Get today's attendance for a user
  Future<AttendanceModel?> getTodayAttendance(
    String userId, {
    bool notify = true,
  }) async {
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
        attendanceQuery.docs.first.data() as Map<String, dynamic>,
      );
    } catch (e) {
      logDebug("Error fetching today's attendance: $e");
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
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.userRequestsCollection)
          .where('type', isEqualTo: AppConstants.requestTypeLeave)
          .where('status', isEqualTo: AppConstants.statusApproved)
          .get();

      // Check if any approved leave includes today
      for (var doc in leaveQuery.docs) {
        final request = RequestModel.fromJson(
          doc.data() as Map<String, dynamic>,
        );
        final fromDate = DateTime(
          request.fromDate!.year,
          request.fromDate!.month,
          request.fromDate!.day,
        );
        final toDate = DateTime(
          request.toDate!.year,
          request.toDate!.month,
          request.toDate!.day,
        );

        if ((today.isAtSameMomentAs(fromDate) || today.isAfter(fromDate)) &&
            (today.isAtSameMomentAs(toDate) || today.isBefore(toDate))) {
          // Convert RequestModel to LeaveModel for backward compatibility
          return LeaveModel(
            id: request.id,
            userId: request.userId,
            userName: request.userName,
            fromDate: request.fromDate!,
            toDate: request.toDate!,
            shift: request.shift ?? '',
            reason: request.reason,
            status: request.status,
            adminRemark: request.adminRemark,
            appliedOn: request.appliedOn,
          );
        }
      }

      return null;
    } catch (e) {
      logDebug("Error checking leave for today: $e");
      return null;
    }
  }

  // Calculate distance between two coordinates in meters using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Validate if user is within office location (20 meter tolerance)
  bool _isWithinOfficeRange(double? userLat, double? userLng, double? officeLat, double? officeLng) {
    if (userLat == null || userLng == null || officeLat == null || officeLng == null) {
      return false;
    }
    final double distance = _calculateDistance(userLat, userLng, officeLat, officeLng);
    logDebug('Distance from office: ${distance.toStringAsFixed(2)} meters');
    return distance <= 20.0; // 20 meter tolerance
  }

  // Punch in
  Future<Map<String, dynamic>> punchIn(UserModel user, {double? latitude, double? longitude}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Validate office location (fallback to default office coordinates)
      final officeLat = user.officeLatitude ?? 18.5679456;
      final officeLng = user.officeLongitude ?? 73.7686132;
      if (latitude == null || longitude == null) {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'Unable to get your location. Please enable location services.'};
      }
      if (!_isWithinOfficeRange(latitude, longitude, officeLat, officeLng)) {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'You are not at the office location. Please punch in from the office.'};
      }

      // Check if already punched in today
      AttendanceModel? todayAttendance = await getTodayAttendance(user.id);

      // Check if on leave today
      LeaveModel? todayLeave = await checkLeaveForToday(user.id);
      if (todayLeave != null) {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'on_leave'};
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Build location map (latitude and longitude are guaranteed non-null here)
      final locationMap = {'lat': latitude, 'lng': longitude};

      if (todayAttendance != null) {
        // Already has an attendance record for today
        if (todayAttendance.punchInTime != null) {
          // Already punched in
          _isLoading = false;
          notifyListeners();
          return {'success': false, 'error': 'already_punched_in'};
        }

        // Update existing record with punch in time
        final updateData = <String, dynamic>{
          'punchInTime': now,
          'status': AppConstants.statusPending,
          'location': locationMap,
        };

        await _firestore
            .collection(AppConstants.attendanceCollection)
            .doc(todayAttendance.id)
            .update(updateData);

        todayAttendance = todayAttendance.copyWith(
          punchInTime: now,
          status: AppConstants.statusPending,
          location: locationMap,
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
          status: AppConstants.statusPending,
          location: locationMap,
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
      return {'success': true};
    } catch (e) {
      logDebug("Error punching in: $e");
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'Failed to punch in. Please try again.'};
    }
  }

  // Punch out
  Future<Map<String, dynamic>> punchOut(UserModel user, {double? latitude, double? longitude}) async {
    try {
      // Validate office location (fallback to default office coordinates)
      final officeLat = user.officeLatitude ?? 18.5679456;
      final officeLng = user.officeLongitude ?? 73.7686132;
      if (latitude == null || longitude == null) {
        return {'success': false, 'error': 'Unable to get your location. Please enable location services.'};
      }
      if (!_isWithinOfficeRange(latitude, longitude, officeLat, officeLng)) {
        return {'success': false, 'error': 'You are not at the office location. Please punch out from the office.'};
      }

      // Check if user is on leave today
      final leaveModel = await checkLeaveForToday(user.id);
      if (leaveModel != null) {
        return {'success': false, 'error': 'on_leave'};
      }

      // Get today's attendance
      final attendance = await getTodayAttendance(user.id);

      // Can only punch out if already punched in
      if (attendance == null || attendance.punchInTime == null) {
        return {'success': false, 'error': 'not_punched_in'};
      }

      // Can't punch out if already punched out
      if (attendance.punchOutTime != null) {
        return {'success': false, 'error': 'already_punched_out'};
      }

      // Build location map (latitude and longitude are guaranteed non-null here)
      final locationMap = {'lat': latitude, 'lng': longitude};

      // Update attendance with punch out time and set status to present
      final now = DateTime.now();
      final updatedAttendance = attendance.copyWith(
        punchOutTime: now,
        status: AppConstants.statusPresent,
        location: locationMap,
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

      return {'success': true};
    } catch (e) {
      logDebug('Error punching out: $e');
      return {'success': false, 'error': 'Failed to punch out. Please try again.'};
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

      //  log("Found ${adminSnapshot.docs.length} admin users to notify");

      for (var doc in adminSnapshot.docs) {
        final adminId = doc.id;
        if (adminId != user.id) {
          // Don't notify the user themselves
          //  log("Sending notification to admin: $adminId");

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
      // log('Error notifying admins: $e');
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
      logDebug('Error getting all attendance: $e');
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
      logDebug('Error getting user attendance: $e');
      return [];
    }
  }

  // Check if user has attendance for a specific date
  bool hasAttendanceForDate(String userId, DateTime date) {
    if (_allAttendance.isEmpty) return false;

    return _allAttendance.any(
      (attendance) =>
          attendance.userId == userId &&
          attendance.date.year == date.year &&
          attendance.date.month == date.month &&
          attendance.date.day == date.day,
    );
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
      logDebug('Error marking absent: $e');
      return false;
    }
  }
}
