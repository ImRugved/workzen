import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

import '../../models/attendance_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../app_constants.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  Stream<List<AttendanceModel>>? _attendanceStream;
  bool _isLoading = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedStatus = 'All';

  final List<String> _statusOptions = [
    'All',
    'Present',
    'Absent',
    'Half-day',
    'On Leave'
  ];

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  void _initializeStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userModel != null) {
      _attendanceStream =
          Provider.of<AttendanceProvider>(context, listen: false)
              .getUserAttendanceStream(authProvider.userModel!.id);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  List<AttendanceModel> _filterAttendance(
      List<AttendanceModel> attendanceList) {
    return attendanceList.where((attendance) {
      // Filter by date range
      final attendanceDate = attendance.date;
      final isInDateRange = attendanceDate
              .isAfter(_startDate.subtract(const Duration(days: 1))) &&
          attendanceDate.isBefore(_endDate.add(const Duration(days: 1)));

      // Filter by status
      bool matchesStatus = true;
      if (_selectedStatus != 'All') {
        final normalizedSelectedStatus = _selectedStatus.toLowerCase();
        final normalizedAttendanceStatus = attendance.status.toLowerCase();
        matchesStatus = normalizedAttendanceStatus == normalizedSelectedStatus;
      }

      return isInDateRange && matchesStatus;
    }).toList();
  }

  Future<void> _generatePdf(List<AttendanceModel> attendanceList) async {
    if (attendanceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance records to generate PDF'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get employee name
      final employeeName =
          Provider.of<AuthProvider>(context, listen: false).userModel!.name;

      final pdf = pw.Document();

      // Add title and date range
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Attendance Report',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 5),

              // Add employee name as subtitle
              pw.Header(
                level: 1,
                child: pw.Text(
                  employeeName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                'Date Range: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              // Create table
              pw.Table.fromTextArray(
                border: null,
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blue300,
                ),
                headerHeight: 30,
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                },
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 10,
                ),
                headers: [
                  'Date',
                  'Status',
                  'Punch In',
                  'Punch Out',
                  'Duration'
                ],
                data: attendanceList.map((attendance) {
                  String duration = '';
                  if (attendance.punchInTime != null &&
                      attendance.punchOutTime != null) {
                    final difference = attendance.punchOutTime!
                        .difference(attendance.punchInTime!);
                    final hours = difference.inHours;
                    final minutes = difference.inMinutes.remainder(60);
                    duration = '$hours hrs $minutes mins';
                  }

                  return [
                    DateFormat('dd MMM yyyy').format(attendance.date),
                    (attendance.punchInTime != null &&
                            attendance.punchOutTime != null)
                        ? attendance.status.toUpperCase()
                        : '-',
                    attendance.punchInTime != null
                        ? DateFormat('hh:mm a').format(attendance.punchInTime!)
                        : '-',
                    attendance.punchOutTime != null
                        ? DateFormat('hh:mm a').format(attendance.punchOutTime!)
                        : '-',
                    duration.isNotEmpty ? duration : '-',
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 20),
              pw.Text(
                'Summary:',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),

              // Add summary statistics
              pw.Bullet(text: 'Total Days: ${attendanceList.length}'),
              pw.Bullet(
                  text:
                      'Present Days: ${attendanceList.where((a) => a.status == AppConstants.statusPresent && a.punchInTime != null && a.punchOutTime != null).length}'),
              pw.Bullet(
                  text:
                      'Absent Days: ${attendanceList.where((a) => a.status == AppConstants.statusAbsent).length}'),
              pw.Bullet(
                  text:
                      'Half Days: ${attendanceList.where((a) => a.status == AppConstants.statusHalfDay).length}'),
              pw.Bullet(
                  text:
                      'Leave Days: ${attendanceList.where((a) => a.status == AppConstants.statusOnLeave).length}'),
            ];
          },
        ),
      );

      // Save the PDF
      final output = await getTemporaryDirectory();
      final fileName =
          'attendance_report_${employeeName.replaceAll(' ', '_')}_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Open the PDF
      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeStream,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Attendance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateRange(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey[700],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[700],
                            ),
                            items: _statusOptions.map((String status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedStatus = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Attendance list
          Expanded(
            child: StreamBuilder<List<AttendanceModel>>(
              stream: _attendanceStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No attendance records found'),
                  );
                }

                final filteredAttendance = _filterAttendance(snapshot.data!);

                if (filteredAttendance.isEmpty) {
                  return const Center(
                    child: Text('No records match your filter criteria'),
                  );
                }

                return Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredAttendance.length,
                      itemBuilder: (context, index) {
                        final attendance = filteredAttendance[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('EEEE, dd MMM yyyy')
                                          .format(attendance.date),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (attendance.punchInTime != null &&
                                        attendance.punchOutTime != null)
                                      _buildStatusChip(attendance.status),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTimeInfo(
                                        'Punch In',
                                        attendance.punchInTime != null
                                            ? DateFormat('hh:mm a')
                                                .format(attendance.punchInTime!)
                                            : '-',
                                        Icons.login,
                                        Colors.green,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildTimeInfo(
                                        'Punch Out',
                                        attendance.punchOutTime != null
                                            ? DateFormat('hh:mm a').format(
                                                attendance.punchOutTime!)
                                            : '-',
                                        Icons.logout,
                                        Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                if (attendance.punchInTime != null &&
                                    attendance.punchOutTime != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.timelapse,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Duration: ${_calculateDuration(attendance.punchInTime!, attendance.punchOutTime!)}',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (_isLoading)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            setState(() {
              _isLoading = true;
            });

            final attendanceProvider =
                Provider.of<AttendanceProvider>(context, listen: false);
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);

            if (authProvider.userModel != null) {
              final attendanceList = await attendanceProvider
                  .getUserAttendance(authProvider.userModel!.id);

              if (attendanceList.isNotEmpty) {
                final filteredAttendance = _filterAttendance(attendanceList);
                if (filteredAttendance.isNotEmpty) {
                  await _generatePdf(filteredAttendance);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No records match your filter criteria'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No attendance records found'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating PDF: $e'),
                backgroundColor: Colors.red,
              ),
            );
          } finally {
            setState(() {
              _isLoading = false;
            });
          }
        },
        icon: const Icon(Icons.download),
        label: const Text('Export PDF'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    // Don't show any status chip for 'pending' status or when only punch in exists
    if (status.toLowerCase() == AppConstants.statusPending) {
      return const SizedBox.shrink(); // Return an empty widget
    }

    Color chipColor;
    String displayText = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'present':
        chipColor = Colors.green;
        break;
      case 'absent':
        chipColor = Colors.red;
        break;
      case 'half-day':
        chipColor = Colors.orange;
        break;
      case 'on-leave':
        chipColor = Colors.blue;
        displayText = 'ON LEAVE';
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        border: Border.all(color: chipColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final difference = end.difference(start);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return '$hours hrs $minutes mins';
  }
}
