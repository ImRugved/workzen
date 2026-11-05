import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/my_data_provider.dart';
import '../../providers/organization_provider.dart';
import '../../models/attendance_model.dart';
import '../../models/office_hours_model.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../constants/app_theme.dart';
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
  // A day with a half day leave is never late: the employee comes in for the
  // other half, so [halfDayLeave] switches the note off.
  String _punchInSuffix(
    OfficeHoursModel? hours,
    DateTime punchIn, {
    String? halfDayLeave,
  }) {
    if (hours == null || halfDayLeave != null) return '';
    switch (hours.punchInStatus(punchIn)) {
      case PunchInStatus.late:
        return ' (Late)';
      case PunchInStatus.halfDay:
        return ' (Half day)';
      case PunchInStatus.onTime:
        return '';
    }
  }

  // " (1h 0m extra)" when the punch out is after the office end time, or ""
  String _extraSuffix(OfficeHoursModel? hours, DateTime punchOut) {
    if (hours == null) return '';
    final extra = hours.extraAfterEnd(punchOut);
    if (extra == Duration.zero) return '';
    return ' (${extra.inHours}h ${extra.inMinutes.remainder(60)}m extra)';
  }

  Widget _punchIcon(AttendanceProvider provider, String action, IconData icon) {
    if (provider.punchAction == action) {
      return SizedBox(
        width: 20.r,
        height: 20.r,
        child: const AppLoadingIndicator(
          size: 20,
          color: ConstColors.textColor,
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
      final user = authProvider.userModel;
      if (user != null) {
        // Today's punch and leave are live; this only makes sure the listeners
        // are running
        Provider.of<MyDataProvider>(context, listen: false).start(user.id);
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

    // Fresh GPS reading, asked for quietly (no messages: this only drives the
    // "At Office" text; a punch asks again and explains any problem). A stale
    // saved position is never used, because it would say where the phone WAS.
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        final precise =
            await Geolocator.getLocationAccuracy() ==
            LocationAccuracyStatus.precise;
        if (precise &&
            (permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always)) {
          final position = await _bestPosition(
            sampleFor: const Duration(seconds: 2),
          );
          if (!position.isMocked) {
            userLat = position.latitude;
            userLng = position.longitude;
            userAccuracy = position.accuracy;
          }
        }
      }
    } catch (e) {
      logDebug('Error getting GPS in attendance screen: $e');
    }

    attendanceProvider.checkOfficeStatus(
      userLat,
      userLng,
      user,
      accuracy: userAccuracy,
    );
  }

  /// The most accurate GPS reading in about [sampleFor]: a single fix indoors
  /// can be several metres worse than the next one. Used for punches, breaks
  /// and the "At Office" indicator, so they all judge the same kind of reading.
  /// Throws when no fix can be had (a time limit stops it waiting forever, e.g.
  /// on the simulator with Location set to None).
  Future<Position> _bestPosition({
    Duration sampleFor = const Duration(seconds: 3),
  }) async {
    Position? position;
    final timer = Stopwatch()..start();
    await for (final reading
        in Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.close(),
        )) {
      if (position == null || reading.accuracy < position.accuracy) {
        position = reading;
      }
      if (timer.elapsed >= sampleFor || reading.accuracy <= 5) break;
    }
    logDebug('Location stream finished, position: $position');

    return position ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 10),
          ),
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

    // "Approximate" location (Android 12+, iOS 14+) is blurred by kilometres
    final accuracyStatus = await Geolocator.getLocationAccuracy();
    if (accuracyStatus == LocationAccuracyStatus.reduced) {
      ConstantSnackbar.showError(
        title: 'Turn on "Precise location" for this app, then try again.',
      );
      await Geolocator.openAppSettings();
      return null;
    }

    try {
      final position = await _bestPosition();

      // Fake GPS apps and old cached fixes are not accepted
      if (position.isMocked) {
        ConstantSnackbar.showError(
          title: 'Fake location detected. Turn off mock location apps.',
        );
        return null;
      }
      if (DateTime.now().difference(position.timestamp).abs() >
          const Duration(minutes: 1)) {
        ConstantSnackbar.showError(
          title: 'Location is out of date. Please try again.',
        );
        return null;
      }

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
                'Successfully punched in${_punchInSuffix(hours, DateTime.now(), halfDayLeave: result['halfDayLeave'] as String?)}',
          );
          // Nothing to reload: the live attendance (MyDataProvider) already has
          // the punch, and this screen, the home screen and the calendar all
          // read from it
        } else {
          final error = result['error'] ?? '';
          if (error == 'on_leave') {
            final todayLeave = attendanceProvider.todayLeave;
            ConstantSnackbar.show(
              title:
                  'You are on leave today${todayLeave != null ? ' (${DateFormat('dd MMM yyyy').format(todayLeave.fromDate)})' : ''}',
              backgroundColor: ConstColors.inProgressOrange,
            );
          } else if (error == 'already_punched_in') {
            ConstantSnackbar.show(
              title: 'You have already punched in today',
              backgroundColor: ConstColors.inProgressOrange,
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
          // Nothing to reload: the live attendance already has the punch out
        } else {
          final error = result['error'] ?? '';
          if (error == 'not_punched_in') {
            ConstantSnackbar.show(
              title: 'You need to punch in first',
              backgroundColor: ConstColors.inProgressOrange,
            );
          } else if (error == 'already_punched_out') {
            ConstantSnackbar.show(
              title: 'You have already punched out today',
              backgroundColor: ConstColors.inProgressOrange,
            );
          } else if (error == 'on_break') {
            ConstantSnackbar.show(
              title: 'End your break before punching out',
              backgroundColor: ConstColors.inProgressOrange,
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
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r),
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              if (authProvider.userModel != null) {
                // Data is live: restart a dropped listener, re-check the spot
                Provider.of<MyDataProvider>(
                  context,
                  listen: false,
                ).start(authProvider.userModel!.id);
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
          if (!attendanceProvider.isTodayLoaded ||
              (attendanceProvider.isLoading && !attendanceProvider.isPunching)) {
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
            padding: AppSpacing.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and time card
                NeuCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 10.h,
                    ),
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
                                          ? ConstColors.successGreen
                                          : ConstColors.errorRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    isAtOffice ? 'At Office' : 'Not at Office',
                                    style: getTextTheme().labelSmall?.copyWith(
                                      color: isAtOffice
                                          ? ConstColors.successGreen
                                          : ConstColors.errorRed,
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
                            color: ConstColors.textColorLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 15.h),

                // Status card
                NeuCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 10.h,
                    ),
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
                            ConstColors.primaryDeep,
                            Icons.event_busy,
                          )
                        else if (todayAttendance == null)
                          _buildStatusRow(
                            'Not Checked In',
                            'You haven\'t punched in today',
                            ConstColors.textColorLight,
                            Icons.pending_actions,
                          )
                        else if (todayAttendance.punchInTime != null &&
                            todayAttendance.punchOutTime == null &&
                            todayAttendance.isOnBreak)
                          _buildStatusRow(
                            'On Break',
                            'On a break since ${DateFormat('hh:mm a').format(todayAttendance.breaks.last.start)}',
                            ConstColors.inProgressOrange,
                            Icons.coffee_outlined,
                          )
                        else if (todayAttendance.punchInTime != null &&
                            todayAttendance.punchOutTime == null)
                          _buildStatusRow(
                            'Checked In',
                            'Punched in at ${DateFormat('hh:mm a').format(todayAttendance.punchInTime!)}${_punchInSuffix(officeHours, todayAttendance.punchInTime!, halfDayLeave: todayAttendance.halfDayLeave)}',
                            ConstColors.successGreen,
                            Icons.login,
                          )
                        else if (todayAttendance.punchInTime != null &&
                            todayAttendance.punchOutTime != null)
                          _buildStatusRow(
                            'Checked Out',
                            'Punched out at ${DateFormat('hh:mm a').format(todayAttendance.punchOutTime!)}${_extraSuffix(officeHours, todayAttendance.punchOutTime!)}',
                            ConstColors.inProgressOrange,
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: ConstColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: ConstColors.primary),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.celebration,
                          color: ConstColors.primaryDeep,
                          size: 22.r,
                        ),
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
                // Half day leave: explains when to punch
                if (attendanceProvider.todayHalfDayLeave != null) ...[
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: ConstColors.warningAmber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: ConstColors.warningAmber),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.timelapse,
                          color: ConstColors.textColor,
                          size: 22.r,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            attendanceProvider.todayHalfDayLeave ==
                                    'Second Half'
                                ? 'Half day leave today (second half). Punch in on time and punch out when your leave starts.'
                                : 'Half day leave today (first half). Punch in when you arrive for the second half and punch out at the end of the day.',
                            style: getTextTheme().bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: ConstColors.textColor,
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
                      Icon(
                        Icons.access_time,
                        size: 16.r,
                        color: ConstColors.textColorLight,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          'Office hours ${officeHours.startTime.format(context)} - ${officeHours.endTime.format(context)}'
                          '${officeHours.lateAfterMinutes != null ? ' • Late after ${officeHours.startPlus(officeHours.lateAfterMinutes!).format(context)}' : ''}'
                          '${officeHours.halfDayAfterMinutes != null ? ' • Half day after ${officeHours.startPlus(officeHours.halfDayAfterMinutes!).format(context)}' : ''}',
                          style: getTextTheme().bodySmall?.copyWith(
                            color: ConstColors.textColorLight,
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
                          icon: _punchIcon(
                            attendanceProvider,
                            'in',
                            Icons.login,
                          ),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    decoration: BoxDecoration(
                      color: ConstColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: ConstColors.primary),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: ConstColors.primaryDeep,
                          size: 24.r,
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            'You are on approved leave from ${DateFormat('dd MMM').format(todayLeave.fromDate)} to ${DateFormat('dd MMM').format(todayLeave.toDate)}',
                            style: getTextTheme().bodyMedium?.copyWith(
                              color: ConstColors.primaryDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Breaks: only between a punch in and a punch out
                if (todayLeave == null &&
                    todayAttendance?.punchInTime != null) ...[
                  SizedBox(height: 16.h),
                  _buildBreakCard(attendanceProvider, todayAttendance!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // Start / end break button and the breaks taken today
  Widget _buildBreakCard(
    AttendanceProvider provider,
    AttendanceModel attendance,
  ) {
    final time = DateFormat('hh:mm a');
    final onBreak = attendance.isOnBreak;
    final canTakeBreak = attendance.punchOutTime == null;
    final totalMinutes = attendance.breakDuration().inMinutes;

    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.coffee_outlined,
                  size: 20.r,
                  color: ConstColors.primaryDeep,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Breaks',
                    style: getTextTheme().titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ConstColors.textColor,
                    ),
                  ),
                ),
                if (attendance.breaks.isNotEmpty)
                  Text(
                    'Total $totalMinutes min',
                    style: getTextTheme().labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ConstColors.textColor,
                    ),
                  ),
              ],
            ),
            if (attendance.breaks.isNotEmpty) ...[
              SizedBox(height: 8.h),
              for (final b in attendance.breaks)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  child: Text(
                    b.isOpen
                        ? '${time.format(b.start)} - on break now'
                        : '${time.format(b.start)} - ${time.format(b.end!)}'
                              '  (${b.duration().inMinutes} min)',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColor,
                    ),
                  ),
                ),
            ],
            if (canTakeBreak) ...[
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: ConstantButton(
                  text: onBreak ? 'End Break' : 'Start Break',
                  icon: _punchIcon(
                    provider,
                    'break',
                    onBreak ? Icons.play_arrow : Icons.coffee_outlined,
                  ),
                  isOutlined: !onBreak,
                  backgroundColor: onBreak
                      ? ConstColors.successGreen
                      : ConstColors.primary,
                  onPressed: provider.isPunching
                      ? null
                      : () => _runPunch('break', () => _toggleBreak(!onBreak)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBreak(bool starting) async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    final provider = context.read<AttendanceProvider>();

    // Breaks are checked against the office location, like a punch
    final position = await _getLocationWithPermission();
    if (position == null) return;

    final result = starting
        ? await provider.startBreak(
            user,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          )
        : await provider.endBreak(
            user,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          );

    if (result['success'] == true) {
      ConstantSnackbar.showSuccess(
        title: starting ? 'Break started' : 'Break ended',
      );
      return;
    }

    switch (result['error']) {
      case 'not_punched_in':
        ConstantSnackbar.show(
          title: 'Punch in before taking a break',
          backgroundColor: ConstColors.inProgressOrange,
        );
      case 'already_punched_out':
        ConstantSnackbar.show(
          title: 'You have already punched out today',
          backgroundColor: ConstColors.inProgressOrange,
        );
      case 'already_on_break':
        ConstantSnackbar.show(
          title: 'You are already on a break',
          backgroundColor: ConstColors.inProgressOrange,
        );
      case 'not_on_break':
        ConstantSnackbar.show(
          title: 'No break is running',
          backgroundColor: ConstColors.inProgressOrange,
        );
      default:
        ConstantSnackbar.showError(title: '${result['error']}');
    }
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
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
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
                  color: ConstColors.textColorLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
