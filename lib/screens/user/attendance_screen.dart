import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';

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
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and time card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            today,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Current Time: $time',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                  const SizedBox(height: 32),

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
                            icon: const Icon(Icons.login),
                            label: const Text('Punch In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_todayAttendance?.punchInTime != null &&
                                    _todayAttendance?.punchOutTime == null &&
                                    !_isLoading)
                                ? _punchOut
                                : null,
                            icon: const Icon(Icons.logout),
                            label: const Text('Punch Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    // Show leave message if on leave
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info,
                            color: Colors.blue,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'You are on approved leave from ${DateFormat('dd MMM').format(_todayLeave!.fromDate)} to ${DateFormat('dd MMM').format(_todayLeave!.toDate)}',
                              style: const TextStyle(
                                fontSize: 16,
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
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
