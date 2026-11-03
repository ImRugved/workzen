import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:workzen/utils/logger.dart';
import '../app_constants.dart';
import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/office_location_model.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
import '../constants/firestore_constants.dart';
import '../constants/permissions.dart';
import '../services/attendance_summary_service.dart';
import '../services/device_service.dart';
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
  // "First Half" / "Second Half" when today is a half day leave
  String? _todayHalfDayLeave;
  bool? _isAtOffice;

  // 'in' or 'out' for the whole punch flow (location, device check, save)
  String? _punchAction;

  // Stream controllers
  Stream<List<AttendanceModel>>? _userAttendanceStream;
  Stream<List<AttendanceModel>>? _allAttendanceStream;

  List<AttendanceModel> get userAttendance => _userAttendance;
  List<AttendanceModel> get allAttendance => _allAttendance;
  bool get isLoading => _isLoading;
  AttendanceModel? get todayAttendance => _todayAttendance;
  LeaveModel? get todayLeave => _todayLeave;
  String? get todayHalfDayLeave => _todayHalfDayLeave;
  bool? get isAtOffice => _isAtOffice;
  String? get punchAction => _punchAction;
  bool get isPunching => _punchAction != null;

  void setPunchAction(String? action) {
    _punchAction = action;
    notifyListeners();
  }

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
      _todayHalfDayLeave = await checkHalfDayLeaveForToday(userId);
    } catch (e) {
      logDebug('Error loading today data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Check if user is within office range and update state
  void checkOfficeStatus(
    double? userLat,
    double? userLng,
    UserModel user, {
    double? accuracy,
  }) {
    final office = _officeLocation;

    // No office set yet by the admin: the "at office" dot is not shown
    if (office == null) {
      _isAtOffice = null;
      notifyListeners();
      return;
    }

    if (userLat == null || userLng == null) {
      _isAtOffice = false;
      notifyListeners();
      return;
    }

    final distance = _calculateDistance(
      userLat,
      userLng,
      office.latitude,
      office.longitude,
    );
    logDebug('Distance from office: ${distance.toStringAsFixed(2)} meters');
    _isAtOffice =
        _isInsideOffice(distance, accuracy, office.radiusMeters) &&
        (accuracy == null || accuracy <= _maxAcceptableAccuracy);
    notifyListeners();
  }

  // The office the admin set (organization_details/office_location). It is
  // handed over by the organization provider, which keeps it live.
  OfficeLocationModel? _officeLocation;
  OfficeLocationModel? get officeLocation => _officeLocation;

  void setOfficeLocation(OfficeLocationModel? location) {
    _officeLocation = location;
  }

  // Get real-time stream of user attendance
  Stream<List<AttendanceModel>> getUserAttendanceStream(String userId) {
    // Temporary solution to avoid index requirement
    // This fetches all records for the user without ordering in Firestore
    // and then sorts them in memory
    _userAttendanceStream = _firestore
        .collection(FirestoreCollections.attendance)
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
        .collection(FirestoreCollections.attendance)
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
          .collection(FirestoreCollections.attendance)
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

  // Shifts that cover only half of the day
  static const Set<String> _halfDayShifts = {
    'Half Day',
    'First Half',
    'Second Half',
  };

  // The approved leave requests that include today
  Future<List<RequestModel>> _approvedLeavesToday(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final leaveQuery = await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreSubCollections.requests)
        .where('type', isEqualTo: AppConstants.requestTypeLeave)
        .where('status', isEqualTo: AppConstants.statusApproved)
        .get();

    final result = <RequestModel>[];
    for (final doc in leaveQuery.docs) {
      final request = RequestModel.fromJson(doc.data());
      final from = request.fromDate;
      final to = request.toDate;
      if (from == null || to == null) continue;
      final fromDate = DateTime(from.year, from.month, from.day);
      final toDate = DateTime(to.year, to.month, to.day);
      if (!today.isBefore(fromDate) && !today.isAfter(toDate)) {
        result.add(request);
      }
    }
    return result;
  }

  // Check if the user is on a FULL day leave today. A half day leave does not
  // count: the employee still comes in for the other half and punches in/out.
  Future<LeaveModel?> checkLeaveForToday(String userId) async {
    try {
      for (final request in await _approvedLeavesToday(userId)) {
        if (_halfDayShifts.contains(request.shift)) continue;
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
      return null;
    } catch (e) {
      logDebug("Error checking leave for today: $e");
      return null;
    }
  }

  // "First Half" / "Second Half" when the user has an approved half day leave
  // today, else null
  Future<String?> checkHalfDayLeaveForToday(String userId) async {
    try {
      for (final request in await _approvedLeavesToday(userId)) {
        final shift = request.shift;
        if (shift != null && _halfDayShifts.contains(shift)) return shift;
      }
      return null;
    } catch (e) {
      logDebug("Error checking half day leave for today: $e");
      return null;
    }
  }

  // Calculate distance between two coordinates in meters using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
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

  // Geofence rules. GPS on phones drifts by several metres, so the reported
  // accuracy is credited (up to a cap) before comparing with the radius, and
  // readings that are too imprecise are rejected instead of guessed. The
  // radius is the one the admin set with the office location.
  static const double _maxAccuracyCredit = 15.0; // metres
  static const double _maxAcceptableAccuracy = 50.0; // metres

  bool _isInsideOffice(double distance, double? accuracy, double radius) {
    final credit = math.min(accuracy ?? 0, _maxAccuracyCredit);
    return distance - credit <= radius;
  }

  // Returns an error message when the phone's position is not valid for an
  // action at the office (punch in, punch out, start or end a break), or null
  // when it is. [action] is the wording used in the message, for example
  // "punch in" or "start your break".
  String? _locationError(
    double? latitude,
    double? longitude,
    double? accuracy,
    String action,
  ) {
    final office = _officeLocation;
    if (office == null) {
      return 'The office location is not set yet. Please ask your admin to set it.';
    }
    if (latitude == null || longitude == null) {
      return 'Unable to get your location. Please enable location services.';
    }

    final distance = _calculateDistance(
      latitude,
      longitude,
      office.latitude,
      office.longitude,
    );
    logDebug(
      'Distance from office: ${distance.toStringAsFixed(2)} meters, GPS accuracy: ${accuracy?.toStringAsFixed(1) ?? 'unknown'} meters',
    );

    if (accuracy != null && accuracy > _maxAcceptableAccuracy) {
      logDebug('Action "$action" rejected: GPS accuracy too low');
      return 'GPS signal is weak (accuracy ±${accuracy.round()} m). Please move to an open area and try again.';
    }

    if (!_isInsideOffice(distance, accuracy, office.radiusMeters)) {
      logDebug('Action "$action" rejected: outside office range');
      return 'You are ${distance.round()} m from the office (limit ${office.radiusMeters.round()} m'
          '${accuracy != null ? ', GPS accuracy ±${accuracy.round()} m' : ''}). '
          'Please move closer and try to $action again.';
    }

    return null;
  }

  // Returns an error message if this phone is not the one registered to the
  // user on their first login, or null when the device matches.
  Future<String?> _checkRegisteredDevice(String userId) async {
    try {
      final userRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId);
      final userDoc = await userRef.get();
      final securityDoc = await userRef
          .collection(FirestoreSubCollections.security)
          .doc(FirestoreDocs.securitySettings)
          .get();

      final deviceInfo = securityDoc.data()?[FirestoreFields.deviceInfo];
      final registeredId = deviceInfo is Map
          ? deviceInfo[FirestoreFields.deviceId]
          : null;
      final isFirstLogin = userDoc.data()?[FirestoreFields.isFirstLogin];

      logDebug(
        'Device check for $userId - isFirstLogin: $isFirstLogin, registered device: $registeredId',
      );

      if (isFirstLogin != true || registeredId == null) {
        // No phone is bound yet (the login could not register it, or the admin
        // reset it): bind this one now, as the login would, and carry on
        logDebug('No device registered for $userId, registering this phone');
        return await DeviceService().registerDevice(userId);
      }

      final currentId = await DeviceService().getDeviceId();
      logDebug('Device check - current device: $currentId');
      if (currentId == null) {
        logDebug('Device check failed: unable to read current device id');
        return 'Unable to verify your device. Please try again.';
      }

      if (currentId != registeredId) {
        logDebug(
          'Device check failed: mismatch (registered: $registeredId, current: $currentId)',
        );
        return 'This is not your registered device. Please punch from your registered phone or ask the admin to reset your device.';
      }

      logDebug('Device check passed for $userId');
      return null;
    } catch (e) {
      logDebug('Error verifying device: $e');
      return 'Unable to verify your device. Please try again.';
    }
  }

  // Rebuilds the stored monthly summary (users/{id}/attendance_summary) after
  // attendance changes. Runs in the background and never fails the punch.
  void _refreshMonthSummary(String userId, {UserModel? user, DateTime? month}) {
    final target = month ?? DateTime.now();
    unawaited(() async {
      try {
        final service = AttendanceSummaryService();
        if (user != null) {
          await service.rebuildMonth(user, target);
        } else {
          await service.rebuildMonthById(userId, target);
        }
      } catch (e) {
        logDebug('Error updating attendance summary: $e');
      }
    }());
  }

  // Punch in
  Future<Map<String, dynamic>> punchIn(
    UserModel user, {
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // The phone must be at the office the admin set
      final rangeError = _locationError(
        latitude,
        longitude,
        accuracy,
        'punch in',
      );
      if (rangeError != null) {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': rangeError};
      }

      // Only the device registered on first login may punch
      final deviceError = await _checkRegisteredDevice(user.id);
      if (deviceError != null) {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': deviceError};
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

      // A half day leave still needs a punch in and out for the other half;
      // the day is saved with it so it is not judged as late or half day by the
      // punch times
      final halfDayLeave = await checkHalfDayLeaveForToday(user.id);

      // Build location map (_locationError already made sure both are set)
      final locationMap = <String, double>{
        'lat': latitude!,
        'lng': longitude!,
      };

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
          'halfDayLeave': halfDayLeave,
        };

        await _firestore
            .collection(FirestoreCollections.attendance)
            .doc(todayAttendance.id)
            .update(updateData);

        todayAttendance = todayAttendance.copyWith(
          punchInTime: now,
          status: AppConstants.statusPending,
          location: locationMap,
          halfDayLeave: halfDayLeave,
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
          halfDayLeave: halfDayLeave,
        );

        await _firestore
            .collection(FirestoreCollections.attendance)
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

      _refreshMonthSummary(user.id, user: user);

      _isLoading = false;
      notifyListeners();
      return {'success': true, 'halfDayLeave': halfDayLeave};
    } catch (e) {
      logDebug("Error punching in: $e");
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'error': 'Failed to punch in. Please try again.',
      };
    }
  }

  // Punch out
  Future<Map<String, dynamic>> punchOut(
    UserModel user, {
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    try {
      // The phone must be at the office the admin set
      final rangeError = _locationError(
        latitude,
        longitude,
        accuracy,
        'punch out',
      );
      if (rangeError != null) {
        return {'success': false, 'error': rangeError};
      }

      // Only the device registered on first login may punch
      final deviceError = await _checkRegisteredDevice(user.id);
      if (deviceError != null) {
        return {'success': false, 'error': deviceError};
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

      // A break still running has to be ended first
      if (attendance.isOnBreak) {
        return {'success': false, 'error': 'on_break'};
      }

      // Build location map (_locationError already made sure both are set)
      final locationMap = <String, double>{
        'lat': latitude!,
        'lng': longitude!,
      };

      // Update attendance with punch out time and set status to present
      final now = DateTime.now();
      final updatedAttendance = attendance.copyWith(
        punchOutTime: now,
        status: AppConstants.statusPresent,
        location: locationMap,
      );

      await _firestore
          .collection(FirestoreCollections.attendance)
          .doc(attendance.id)
          .update(updatedAttendance.toJson());

      // Notify admins
      await _notifyAdmins(
        user,
        AppConstants.punchOutNotification,
        'Punch Out',
        '${user.name} has punched out at ${DateFormat('hh:mm a').format(now)}',
      );

      _refreshMonthSummary(user.id, user: user);

      return {'success': true};
    } catch (e) {
      logDebug('Error punching out: $e');
      return {
        'success': false,
        'error': 'Failed to punch out. Please try again.',
      };
    }
  }

  // Starts a break (tea, lunch...) in today's record. Needs a punch in, no
  // punch out yet and no break already running. The phone must be at the
  // office, like a punch.
  Future<Map<String, dynamic>> startBreak(
    UserModel user, {
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    try {
      final rangeError = _locationError(
        latitude,
        longitude,
        accuracy,
        'start your break',
      );
      if (rangeError != null) {
        return {'success': false, 'error': rangeError};
      }

      final attendance = await getTodayAttendance(user.id, notify: false);
      if (attendance == null || attendance.punchInTime == null) {
        return {'success': false, 'error': 'not_punched_in'};
      }
      if (attendance.punchOutTime != null) {
        return {'success': false, 'error': 'already_punched_out'};
      }
      if (attendance.isOnBreak) {
        return {'success': false, 'error': 'already_on_break'};
      }

      final now = DateTime.now();
      final updated = attendance.copyWith(
        breaks: [...attendance.breaks, AttendanceBreak(start: now)],
      );
      await _saveBreaks(updated);

      // Same as a punch: the admins and the sub admins who view attendance
      await _notifyAdmins(
        user,
        AppConstants.breakStartNotification,
        'Break Start',
        '${user.name} has started a break at ${DateFormat('hh:mm a').format(now)}',
      );
      return {'success': true};
    } catch (e) {
      logDebug('Error starting break: $e');
      return {
        'success': false,
        'error': 'Failed to start the break. Please try again.',
      };
    }
  }

  // Ends the running break. The phone must be at the office.
  Future<Map<String, dynamic>> endBreak(
    UserModel user, {
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    try {
      final rangeError = _locationError(
        latitude,
        longitude,
        accuracy,
        'end your break',
      );
      if (rangeError != null) {
        return {'success': false, 'error': rangeError};
      }

      final attendance = await getTodayAttendance(user.id, notify: false);
      if (attendance == null || !attendance.isOnBreak) {
        return {'success': false, 'error': 'not_on_break'};
      }

      final breaks = [...attendance.breaks];
      final now = DateTime.now();
      breaks[breaks.length - 1] = AttendanceBreak(
        start: breaks.last.start,
        end: now,
      );
      await _saveBreaks(attendance.copyWith(breaks: breaks));

      // Always told, as for a punch; a break past the limit says so
      final minutes = now.difference(breaks.last.start).inMinutes;
      final tooLong = minutes > AppConstants.maxBreakMinutes;
      await _notifyAdmins(
        user,
        tooLong
            ? AppConstants.longBreakNotification
            : AppConstants.breakEndNotification,
        tooLong ? 'Long Break' : 'Break End',
        tooLong
            ? '${user.name} ended a $minutes min break '
                  '(limit ${AppConstants.maxBreakMinutes} min)'
            : '${user.name} has ended the break at '
                  '${DateFormat('hh:mm a').format(now)} ($minutes min)',
      );
      return {'success': true};
    } catch (e) {
      logDebug('Error ending break: $e');
      return {
        'success': false,
        'error': 'Failed to end the break. Please try again.',
      };
    }
  }

  // Writes only the breaks field, keeps the screen's copy in step and rebuilds
  // the month summary (break time is taken off the hours worked)
  Future<void> _saveBreaks(AttendanceModel updated) async {
    await _firestore
        .collection(FirestoreCollections.attendance)
        .doc(updated.id)
        .update({'breaks': updated.breaks.map((b) => b.toJson()).toList()});
    _todayAttendance = updated;
    notifyListeners();
    _refreshMonthSummary(updated.userId);
  }

  // Ids of everyone who follows attendance: all admins, plus sub admins who
  // were given the "view attendance" permission.
  Future<List<String>> _attendanceViewerIds() async {
    final ids = <String>{};
    final users = _firestore.collection(FirestoreCollections.users);

    var admins = await users.where('isAdmin', isEqualTo: true).get();
    // Older accounts may only have the admin role
    if (admins.docs.isEmpty) {
      admins = await users
          .where('role', isEqualTo: AppConstants.adminRole)
          .get();
    }
    ids.addAll(admins.docs.map((d) => d.id));

    final subAdmins = await users
        .where(
          Permissions.field,
          arrayContains: Permissions.viewAttendance,
        )
        .get();
    ids.addAll(subAdmins.docs.map((d) => d.id));

    return ids.toList();
  }

  // Tells the admins and the sub admins who can view attendance (never the
  // employee themselves)
  Future<void> _notifyAdmins(
    UserModel user,
    String notificationType,
    String title,
    String body,
  ) async {
    try {
      final recipients = await _attendanceViewerIds();

      for (final recipientId in recipients) {
        if (recipientId == user.id) continue;

        await _fcmService.sendNotificationToUser(
          userId: recipientId,
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
    } catch (e) {
      logDebug('Error notifying admins: $e');
    }
  }

  // Get all attendance records (not as stream)
  Future<List<AttendanceModel>> getAllAttendance() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection(FirestoreCollections.attendance)
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
          .collection(FirestoreCollections.attendance)
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
          .collection(FirestoreCollections.attendance)
          .doc(id)
          .set(attendanceModel.toJson());

      _refreshMonthSummary(employee.id, user: employee, month: date);

      return true;
    } catch (e) {
      logDebug('Error marking absent: $e');
      return false;
    }
  }
}
