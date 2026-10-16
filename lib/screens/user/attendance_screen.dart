import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/organization_provider.dart';
import '../../models/office_hours_model.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../utils/logger.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // The punch flow flag lives in AttendanceProvider (isPunching / punchAction)
  Future<void> _runPunch(String action, Future<void> Function() punch) async {
    final provider = context.read<AttendanceProvider>();
    if (provider.isPunching) return;
    provider.setPunchAction(action);
    try {
      await punch();
    } finally {
      provider.setPunchAction(null);
    }
  }

  // " (Late)" / " (Half day)" from the admin's office hours, or "" when on time
  // or when no office hours have been set.
  String _punchInSuffix(OfficeHoursModel? hours, DateTime punchIn) {
    if (hours == null) return '';
    switch (hours.punchInStatus(punchIn)) {
      case PunchInStatus.late:
        return ' (Late)';
      case PunchInStatus.halfDay:
        return ' (Half day)';
      case PunchInStatus.onTime:
        return '';
    }
  }

  Widget _punchIcon(AttendanceProvider provider, String action, IconData icon) {
    if (provider.punchAction == action) {
      return SizedBox(
        width: 20.r,
        height: 20.r,
        child: const AppLoadingIndicator(
          size: 20,
          color: ConstColors.white,
        ),
      );
    }
    return Icon(icon, size: 20.r);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Live office hours and holidays set by the admin
      Provider.of<OrganizationProvider>(context, listen: false).start();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );
      final user = authProvider.userModel;
      if (user != null) {
        attendanceProvider.loadTodayData(user.id);
        _checkOfficeLocation();
      }
    });
  }

  Future<void> _checkOfficeLocation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final user = authProvider.userModel;
    if (user == null) return;

    double? userLat;
    double? userLng;
    double? userAccuracy;

    // Try to get fresh GPS location (request permission if needed)
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          userLat = position.latitude;
          userLng = position.longitude;
          userAccuracy = position.accuracy;

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

    attendanceProvider.checkOfficeStatus(
      userLat,
      userLng,
      user,
      accuracy: userAccuracy,
    );
  }

  /// Ensures location services are enabled and permission is granted.
  /// Returns the current [Position] or null if location couldn't be obtained.
  Future<Position?> _getLocationWithPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ConstantSnackbar.showError(
        title: 'Location services are disabled. Please enable GPS.',
      );
      await Geolocator.openLocationSettings();
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ConstantSnackbar.showError(
          title: 'Location permission denied. Please grant permission.',
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ConstantSnackbar.showError(
        title:
            'Location permission permanently denied. Please enable it from app settings.',
      );
      await Geolocator.openAppSettings();
      return null;
    }

    try {
      // One fast fix; GPS drift is handled by the accuracy-aware range check
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final storage = GetStorage();
      await storage.write('latitude', position.latitude);
      await storage.write('longitude', position.longitude);
      return position;
    } catch (e) {
      logDebug('Error getting current position: $e');
      ConstantSnackbar.showError(title: 'Failed to get location. Try again.');
      return null;
    }
  }

  Future<void> _punchIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    final position = await _getLocationWithPermission();
    if (position == null) return;

    // Update office status immediately with fresh location
    if (authProvider.userModel != null) {
      attendanceProvider.checkOfficeStatus(
        position.latitude,
        position.longitude,
        authProvider.userModel!,
        accuracy: position.accuracy,
      );
    }

    if (authProvider.userModel != null) {
      try {
        logDebug(
          'Punch In - Latitude: ${position.latitude}, Longitude: ${position.longitude}',
        );

        final result = await attendanceProvider.punchIn(
          authProvider.userModel!,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );

        if (result['success'] == true) {
          final hours = Provider.of<OrganizationProvider>(
            context,
            listen: false,
          ).officeHours;
          ConstantSnackbar.showSuccess(
            title:
                'Successfully punched in${_punchInSuffix(hours, DateTime.now())}',
          );
          await attendanceProvider.loadTodayData(authProvider.userModel!.id);
          // Dashboard calendar must show the new punch
          if (mounted) {
            Provider.of<CalendarProvider>(context, listen: false).refresh();
          }
        } else {
          final error = result['error'] ?? '';
          if (error == 'on_leave') {
            final todayLeave = attendanceProvider.todayLeave;
            ConstantSnackbar.show(
              title:
                  'You are on leave today${todayLeave != null ? ' (${DateFormat('dd MMM yyyy').format(todayLeave.fromDate)})' : ''}',
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
  }

  Future<void> _punchOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    final position = await _getLocationWithPermission();
    if (position == null) return;

    // Update office status immediately with fresh location
    if (authProvider.userModel != null) {
      attendanceProvider.checkOfficeStatus(
        position.latitude,
        position.longitude,
        authProvider.userModel!,
        accuracy: position.accuracy,
      );
    }

    if (authProvider.userModel != null) {
      try {
        logDebug(
          'Punch Out - Latitude: ${position.latitude}, Longitude: ${position.longitude}',
        );

        final result = await attendanceProvider.punchOut(
          authProvider.userModel!,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );

        if (result['success'] == true) {
          ConstantSnackbar.showSuccess(title: 'Successfully punched out');
          await attendanceProvider.loadTodayData(authProvider.userModel!.id);
          // Dashboard calendar must show the new punch
          if (mounted) {
            Provider.of<CalendarProvider>(context, listen: false).refresh();
          }
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
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final attendanceProvider = Provider.of<AttendanceProvider>(
                context,
                listen: false,
              );
              if (authProvider.userModel != null) {
                attendanceProvider.loadTodayData(authProvider.userModel!.id);
                _checkOfficeLocation();
              }
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendanceProvider, _) {
          // Keep the page (and the button spinner) visible while punching
          if (attendanceProvider.isLoading && !attendanceProvider.isPunching) {
            return const Center(child: AppLoadingIndicator(size: 40));
          }

          final todayAttendance = attendanceProvider.todayAttendance;
          final todayLeave = attendanceProvider.todayLeave;
          final isAtOffice = attendanceProvider.isAtOffice;

          // Office hours and holidays the admin maintains (live)
          final org = Provider.of<OrganizationProvider>(context);
          final officeHours = org.officeHours;
          final todayHoliday = org.holidayOn(DateTime.now());

          return SingleChildScrollView(
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
                            if (isAtOffice != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12.r,
                                    height: 12.r,
                                    decoration: BoxDecoration(
                                      color: isAtOffice
                                          ? Colors.green
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    isAtOffice
                                        ? 'At Office'
                                        : 'Not at Office',
                                    style: getTextTheme().labelSmall?.copyWith(
                                      color: isAtOffice
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
                        if (todayLeave != null)
                          _buildStatusRow(
                            'On Leave',
                            'You are on approved leave today',
                            Colors.blue,
                            Icons.event_busy,
                          )
                        else if (todayAttendance == null)
                          _buildStatusRow(
                            'Not Checked In',
                            'You haven\'t punched in today',
                            Colors.grey,
                            Icons.pending_actions,
                          )
                        else if (todayAttendance.punchInTime != null &&
                            todayAttendance.punchOutTime == null)
                          _buildStatusRow(
                            'Checked In',
                            'Punched in at ${DateFormat('hh:mm a').format(todayAttendance.punchInTime!)}${_punchInSuffix(officeHours, todayAttendance.punchInTime!)}',
                            Colors.green,
                            Icons.login,
                          )
                        else if (todayAttendance.punchInTime != null &&
                            todayAttendance.punchOutTime != null)
                          _buildStatusRow(
                            'Checked Out',
                            'Punched out at ${DateFormat('hh:mm a').format(todayAttendance.punchOutTime!)}',
                            Colors.orange,
                            Icons.logout,
                          ),
                      ],
                    ),
                  ),
                ),
                if (todayHoliday != null) ...[
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: Colors.lightBlue.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.celebration, color: Colors.lightBlue, size: 22.r),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Today is a holiday: ${todayHoliday.name}',
                            style: getTextTheme().bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (officeHours != null) ...[
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16.r, color: Colors.grey),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          'Office hours ${officeHours.startTime.format(context)} - ${officeHours.endTime.format(context)}'
                          '${officeHours.lateAfterMinutes != null ? ' • Late after ${officeHours.startPlus(officeHours.lateAfterMinutes!).format(context)}' : ''}'
                          '${officeHours.halfDayAfterMinutes != null ? ' • Half day after ${officeHours.startPlus(officeHours.halfDayAfterMinutes!).format(context)}' : ''}',
                          style: getTextTheme().bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 32.h),

                // Punch buttons
                if (todayLeave == null)
                  Row(
                    children: [
                      Expanded(
                        child: ConstantButton(
                          text: attendanceProvider.punchAction == 'in'
                              ? 'Verifying...'
                              : 'Punch In',
                          onPressed:
                              (todayAttendance?.punchInTime == null &&
                                  !attendanceProvider.isPunching)
                              ? () => _runPunch('in', _punchIn)
                              : null,
                          icon: _punchIcon(attendanceProvider, 'in', Icons.login),
                          backgroundColor: ConstColors.successGreen,
                          disabledBackgroundColor:
                              attendanceProvider.punchAction == 'in'
                              ? ConstColors.successGreen.withValues(alpha: 0.7)
                              : null,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: ConstantButton(
                          text: attendanceProvider.punchAction == 'out'
                              ? 'Verifying...'
                              : 'Punch Out',
                          onPressed:
                              (todayAttendance?.punchInTime != null &&
                                  todayAttendance?.punchOutTime == null &&
                                  !attendanceProvider.isPunching)
                              ? () => _runPunch('out', _punchOut)
                              : null,
                          icon: _punchIcon(
                            attendanceProvider,
                            'out',
                            Icons.logout,
                          ),
                          backgroundColor: ConstColors.inProgressOrange,
                          disabledBackgroundColor:
                              attendanceProvider.punchAction == 'out'
                              ? ConstColors.inProgressOrange.withValues(
                                  alpha: 0.7,
                                )
                              : null,
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 24.r),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            'You are on approved leave from ${DateFormat('dd MMM').format(todayLeave.fromDate)} to ${DateFormat('dd MMM').format(todayLeave.toDate)}',
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
          );
        },
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
