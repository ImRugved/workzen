import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/const_textstyle.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;
  AttendanceModel? _todayAttendance;
  LeaveModel? _todayLeave;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

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
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    if (authProvider.userModel != null) {
      try {
        bool success =
            await attendanceProvider.punchIn(authProvider.userModel!);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully punched in'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload data
          await _loadData();
        } else {
          if (_todayLeave != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'You are on leave today (${DateFormat('dd MMM yyyy').format(_todayLeave!.fromDate)})'),
                backgroundColor: Colors.orange,
              ),
            );
          } else if (_todayAttendance?.punchInTime != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have already punched in today'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to punch in. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    if (authProvider.userModel != null) {
      try {
        bool success =
            await attendanceProvider.punchOut(authProvider.userModel!);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully punched out'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload data
          await _loadData();
        } else {
          if (_todayAttendance == null ||
              _todayAttendance?.punchInTime == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You need to punch in first'),
                backgroundColor: Colors.orange,
              ),
            );
          } else if (_todayAttendance?.punchOutTime != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have already punched out today'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to punch out. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
          'Attendance',
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
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            today,
                            style: getTextTheme().titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
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
                  SizedBox(height: 24.h),

                  // Status card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s Status',
                            style: getTextTheme().titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16.h),
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
                            onPressed: (_todayAttendance?.punchInTime == null &&
                                    !_isLoading)
                                ? _punchIn
                                : null,
                            icon: Icon(Icons.login, size: 20.r),
                            label: Text('Punch In', style: getTextTheme().labelLarge),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_todayAttendance?.punchInTime != null &&
                                    _todayAttendance?.punchOutTime == null &&
                                    !_isLoading)
                                ? _punchOut
                                : null,
                            icon: Icon(Icons.logout, size: 20.r),
                            label: Text('Punch Out', style: getTextTheme().labelLarge),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.symmetric(vertical: 16.h),
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
                          Icon(
                            Icons.info,
                            color: Colors.blue,
                            size: 24.r,
                          ),
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
      String title, String subtitle, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24.r,
          ),
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
