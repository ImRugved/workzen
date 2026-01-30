import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../utils/logger.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;
  AttendanceModel? _todayAttendance;
  LeaveModel? _todayLeave;
  bool? _isAtOffice; // null = unknown, true = at office, false = not at office

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOfficeLocation();
    });
  }

  Future<void> _checkOfficeLocation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    if (user == null) return;

    // Use user's office location or fallback to default office coordinates
    final officeLat = user.officeLatitude ?? 18.5679456;
    final officeLng = user.officeLongitude ?? 73.7686132;
    logDebug('Office Location - Lat: $officeLat, Lng: $officeLng');

    double? userLat;
    double? userLng;

    // Try to get fresh GPS location
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          userLat = position.latitude;
          userLng = position.longitude;

          // Also update GetStorage
          final storage = GetStorage();
          await storage.write('latitude', userLat);
          await storage.write('longitude', userLng);
        }
      }
    } catch (e) {
      logDebug('Error getting GPS in attendance screen: $e');
    }

    // Fallback to GetStorage if GPS failed
    if (userLat == null || userLng == null) {
      final storage = GetStorage();
      userLat = storage.read('latitude');
      userLng = storage.read('longitude');
    }

    if (userLat == null || userLng == null) {
      logDebug('User location not available.');
      if (mounted) setState(() => _isAtOffice = false);
      return;
    }

    final distance = _calculateDistance(userLat, userLng, officeLat, officeLng);
    logDebug(
      'Attendance screen - Distance from office: ${distance.toStringAsFixed(2)} meters',
    );
    if (mounted) setState(() => _isAtOffice = distance <= 20.0);
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;
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

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    if (authProvider.userModel != null) {
      try {
        // Get today's attendance
        _todayAttendance = await attendanceProvider.getTodayAttendance(
          authProvider.userModel!.id,
          notify: false,
        );

        // Check if on leave today
        _todayLeave = await attendanceProvider.checkLeaveForToday(
          authProvider.userModel!.id,
        );
      } catch (e) {
        print("Error loading attendance data: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _punchIn() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    if (authProvider.userModel != null) {
      try {
        // Read location from GetStorage
        final storage = GetStorage();
        final double? lat = storage.read('latitude');
        final double? lng = storage.read('longitude');
        logDebug('Punch In - Latitude: $lat, Longitude: $lng');

        final result = await attendanceProvider.punchIn(
          authProvider.userModel!,
          latitude: lat,
          longitude: lng,
        );

        if (result['success'] == true) {
          ConstantSnackbar.showSuccess(title: 'Successfully punched in');

          // Reload data
          await _loadData();
        } else {
          final error = result['error'] ?? '';
          if (error == 'on_leave') {
            ConstantSnackbar.show(
              title:
                  'You are on leave today${_todayLeave != null ? ' (${DateFormat('dd MMM yyyy').format(_todayLeave!.fromDate)})' : ''}',
              backgroundColor: Colors.orange,
            );
          } else if (error == 'already_punched_in') {
            ConstantSnackbar.show(
              title: 'You have already punched in today',
              backgroundColor: Colors.orange,
            );
          } else {
            ConstantSnackbar.showError(title: error);
          }
        }
      } catch (e) {
        ConstantSnackbar.showError(title: 'Error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _punchOut() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    if (authProvider.userModel != null) {
      try {
        // Read location from GetStorage
        final storage = GetStorage();
        final double? lat = storage.read('latitude');
        final double? lng = storage.read('longitude');
        logDebug('Punch Out - Latitude: $lat, Longitude: $lng');

        final result = await attendanceProvider.punchOut(
          authProvider.userModel!,
          latitude: lat,
          longitude: lng,
        );

        if (result['success'] == true) {
          ConstantSnackbar.showSuccess(title: 'Successfully punched out');

          // Reload data
          await _loadData();
        } else {
          final error = result['error'] ?? '';
          if (error == 'not_punched_in') {
            ConstantSnackbar.show(
              title: 'You need to punch in first',
              backgroundColor: Colors.orange,
            );
          } else if (error == 'already_punched_out') {
            ConstantSnackbar.show(
              title: 'You have already punched out today',
              backgroundColor: Colors.orange,
            );
          } else {
            ConstantSnackbar.showError(title: error);
          }
        }
      } catch (e) {
        ConstantSnackbar.showError(title: 'Error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final time = DateFormat('hh:mm a').format(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance Screen',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and time card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  today,
                                  style: getTextTheme().titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ),
                              if (_isAtOffice != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 12.r,
                                      height: 12.r,
                                      decoration: BoxDecoration(
                                        color: _isAtOffice!
                                            ? Colors.green
                                            : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      _isAtOffice!
                                          ? 'At Office'
                                          : 'Not at Office',
                                      style: getTextTheme().labelSmall
                                          ?.copyWith(
                                            color: _isAtOffice!
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                            ],
                          ),

                          Text(
                            'Current Time: $time',
                            style: getTextTheme().bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),

                  // Status card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s Status',
                            style: getTextTheme().titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          if (_todayLeave != null)
                            _buildStatusRow(
                              'On Leave',
                              'You are on approved leave today',
                              Colors.blue,
                              Icons.event_busy,
                            )
                          else if (_todayAttendance == null)
                            _buildStatusRow(
                              'Not Checked In',
                              'You haven\'t punched in today',
                              Colors.grey,
                              Icons.pending_actions,
                            )
                          else if (_todayAttendance!.punchInTime != null &&
                              _todayAttendance!.punchOutTime == null)
                            _buildStatusRow(
                              'Checked In',
                              'Punched in at ${DateFormat('hh:mm a').format(_todayAttendance!.punchInTime!)}',
                              Colors.green,
                              Icons.login,
                            )
                          else if (_todayAttendance!.punchInTime != null &&
                              _todayAttendance!.punchOutTime != null)
                            _buildStatusRow(
                              'Checked Out',
                              'Punched out at ${DateFormat('hh:mm a').format(_todayAttendance!.punchOutTime!)}',
                              Colors.orange,
                              Icons.logout,
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Punch buttons
                  if (_todayLeave == null) // Only show buttons if not on leave
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                (_todayAttendance?.punchInTime == null &&
                                    !_isLoading)
                                ? _punchIn
                                : null,
                            icon: Icon(Icons.login, size: 20.r),
                            label: Text(
                              'Punch In',
                              style: getTextTheme().labelLarge,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                (_todayAttendance?.punchInTime != null &&
                                    _todayAttendance?.punchOutTime == null &&
                                    !_isLoading)
                                ? _punchOut
                                : null,
                            icon: Icon(Icons.logout, size: 20.r),
                            label: Text(
                              'Punch Out',
                              style: getTextTheme().labelLarge,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    // Show leave message if on leave
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 24.r),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Text(
                              'You are on approved leave from ${DateFormat('dd MMM').format(_todayLeave!.fromDate)} to ${DateFormat('dd MMM').format(_todayLeave!.toDate)}',
                              style: getTextTheme().bodyMedium?.copyWith(
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusRow(
    String title,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24.r),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: getTextTheme().titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: getTextTheme().bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
