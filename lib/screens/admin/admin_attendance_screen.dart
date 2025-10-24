import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/user_provider.dart';
import '../../app_constants.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  Stream<List<AttendanceModel>>? _attendanceStream;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  List<UserModel> _employees = [];

  @override
  void initState() {
    super.initState();
    _initializeStream();

    // Use addPostFrameCallback to delay loading employees until after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmployees();
    });
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      _employees = await userProvider.getEmployees(silent: true);
    } catch (e) {
      print("Error loading employees: $e");
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeStream() {
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);
    _attendanceStream = attendanceProvider.getAllAttendanceStream();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  List<AttendanceModel> _filterAttendance(
      List<AttendanceModel> attendanceList) {
    return attendanceList.where((attendance) {
      // Filter by date
      final isSameDate = attendance.date.year == _selectedDate.year &&
          attendance.date.month == _selectedDate.month &&
          attendance.date.day == _selectedDate.day;

      // Filter by employee if selected
      final isSelectedEmployee = _selectedEmployeeId == null ||
          attendance.userId == _selectedEmployeeId;

      return isSameDate && isSelectedEmployee;
    }).toList();
  }

  Future<void> _generatePdf(List<AttendanceModel> attendanceList) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pdf = pw.Document();

      // Add title and date
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
              pw.SizedBox(height: 10),
              pw.Text(
                'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
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
                  1: pw.Alignment.centerLeft,
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
                  'Employee Name',
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
                    attendance.userName,
                    _getStatusText(attendance),
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
              pw.Bullet(text: 'Total Employees: ${attendanceList.length}'),
              pw.Bullet(
                  text:
                      'Present: ${attendanceList.where((a) => a.status == AppConstants.statusPresent && a.punchInTime != null && a.punchOutTime != null).length}'),
              pw.Bullet(
                  text:
                      'In Progress: ${attendanceList.where((a) => a.status == AppConstants.statusPending && a.punchInTime != null && a.punchOutTime == null).length}'),
              pw.Bullet(
                  text:
                      'Absent: ${attendanceList.where((a) => a.status == AppConstants.statusAbsent).length}'),
              pw.Bullet(
                  text:
                      'Half-day: ${attendanceList.where((a) => a.status == AppConstants.statusHalfDay).length}'),
              pw.Bullet(
                  text:
                      'On Leave: ${attendanceList.where((a) => a.status == AppConstants.statusOnLeave).length}'),
            ];
          },
        ),
      );

      // Save the PDF
      final output = await getTemporaryDirectory();
      final file = File(
          '${output.path}/attendance_report_${DateFormat('dd_MM_yyyy').format(_selectedDate)}.pdf');
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
        title: const Text('Employee Attendance'),
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
                        onTap: () => _selectDate(context),
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
                                DateFormat('dd MMM yyyy').format(_selectedDate),
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
                          child: DropdownButton<String?>(
                            value: _selectedEmployeeId,
                            isExpanded: true,
                            hint: const Text('All Employees'),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[700],
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Employees'),
                              ),
                              ..._employees.map((employee) {
                                return DropdownMenuItem<String?>(
                                  value: employee.id,
                                  child: Text(employee.name),
                                );
                              }).toList(),
                            ],
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedEmployeeId = newValue;
                              });
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

          // Attendance table
          Expanded(
            child: StreamBuilder<List<AttendanceModel>>(
              stream: _attendanceStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // Handle different types of errors with user-friendly messages
                  String errorMessage = 'Unable to load attendance records at the moment.';
                  
                  if (snapshot.error.toString().contains('permission-denied') ||
                      snapshot.error.toString().contains('PERMISSION_DENIED')) {
                    errorMessage = 'Access denied. Please check your admin permissions.';
                  } else if (snapshot.error.toString().contains('network') ||
                             snapshot.error.toString().contains('connection')) {
                    errorMessage = 'Network error. Please check your internet connection.';
                  }
                  
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _initializeStream,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No attendance records for this date'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Mark all employees as absent for this date
                            _markAbsentEmployees();
                          },
                          icon: const Icon(Icons.person_off),
                          label: const Text('Mark All Absent'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Table header
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              constraints: BoxConstraints(
                                minWidth:
                                    MediaQuery.of(context).size.width - 32,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      'Employee',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Punch In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Punch Out',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Table body
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredAttendance.length,
                              itemBuilder: (context, index) {
                                final attendance = filteredAttendance[index];
                                return Card(
                                  margin: const EdgeInsets.only(top: 8),
                                  elevation: 1,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Container(
                                      constraints: BoxConstraints(
                                        minWidth:
                                            MediaQuery.of(context).size.width -
                                                32,
                                      ),
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 150,
                                            child: Text(
                                              attendance.userName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: _buildStatusChip(
                                                attendance.status,
                                                hasPunchIn:
                                                    attendance.punchInTime !=
                                                        null,
                                                hasPunchOut:
                                                    attendance.punchOutTime !=
                                                        null),
                                          ),
                                          const SizedBox(width: 20),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              attendance.punchInTime != null
                                                  ? DateFormat('hh:mm a')
                                                      .format(attendance
                                                          .punchInTime!)
                                                  : '-',
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              attendance.punchOutTime != null
                                                  ? DateFormat('hh:mm a')
                                                      .format(attendance
                                                          .punchOutTime!)
                                                  : '-',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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
        onPressed: () {
          final attendanceProvider =
              Provider.of<AttendanceProvider>(context, listen: false);
          attendanceProvider.getAllAttendance().then((attendanceList) {
            final filteredAttendance = _filterAttendance(attendanceList);
            _generatePdf(filteredAttendance);
          });
        },
        icon: const Icon(Icons.download),
        label: const Text('Export PDF'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _markAbsentEmployees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);

      // Get all employees who don't have attendance records for today
      final employeesWithoutAttendance = _employees.where((employee) {
        // Check if employee already has an attendance record for today
        return !attendanceProvider.hasAttendanceForDate(
            employee.id, _selectedDate);
      }).toList();

      if (employeesWithoutAttendance.isNotEmpty) {
        // Mark all these employees as absent
        for (final employee in employeesWithoutAttendance) {
          await attendanceProvider.markAbsent(employee, _selectedDate);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Marked ${employeesWithoutAttendance.length} employees as absent'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the stream
        _initializeStream();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'All employees already have attendance records for this date'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking employees as absent: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStatusChip(String status,
      {bool hasPunchIn = false, bool hasPunchOut = false}) {
    // For pending status (punched in but not punched out), show a special indicator
    if (status.toLowerCase() == AppConstants.statusPending &&
        hasPunchIn &&
        !hasPunchOut) {
      return Text(
        'IN PROGRESS',
        style: TextStyle(
          color: Colors.amber,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }

    // Only show present status when both punch in and punch out are available
    if (status.toLowerCase() == AppConstants.statusPresent &&
        (!hasPunchIn || !hasPunchOut)) {
      return Text(
        'INCOMPLETE',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }

    Color textColor;
    String displayText = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'present':
        textColor = Colors.green;
        break;
      case 'absent':
        textColor = Colors.red;
        break;
      case 'half-day':
        textColor = Colors.orange;
        break;
      case 'on-leave':
        textColor = Colors.blue;
        displayText = 'ON LEAVE';
        break;
      default:
        textColor = Colors.grey;
    }

    return Text(
      displayText,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  String _getStatusText(AttendanceModel attendance) {
    if (attendance.status.toLowerCase() == AppConstants.statusPending &&
        attendance.punchInTime != null &&
        attendance.punchOutTime == null) {
      return 'IN PROGRESS';
    } else if (attendance.status.toLowerCase() == AppConstants.statusPresent &&
        attendance.punchInTime != null &&
        attendance.punchOutTime != null) {
      return 'PRESENT';
    } else if (attendance.status.toLowerCase() == AppConstants.statusAbsent) {
      return 'ABSENT';
    } else if (attendance.status.toLowerCase() == AppConstants.statusHalfDay) {
      return 'HALF-DAY';
    } else if (attendance.status.toLowerCase() == AppConstants.statusOnLeave) {
      return 'ON LEAVE';
    } else {
      return 'INCOMPLETE';
    }
  }
}
