import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/attendance_model.dart';
import '../../providers/admin_attendance_filter_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/user_provider.dart';
import '../../app_constants.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/constant_date_time_picker.dart';
import '../../constants/constant_colors.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/app_theme.dart';
import '../../utils/logger.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  // Stream, filters, employees and the busy flag live in this scoped provider
  final AdminAttendanceFilterProvider _filter = AdminAttendanceFilterProvider();

  @override
  void initState() {
    super.initState();

    // Use addPostFrameCallback so context is ready for provider lookups
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStream();
      _loadEmployees();
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    _filter.setLoading(true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final employees = await userProvider.getEmployees(silent: true);
      if (!mounted) return;
      _filter.setEmployees(employees);
    } catch (e) {
      logDebug('Error loading employees: $e');
    }

    if (mounted) _filter.setLoading(false);
  }

  void _initializeStream() {
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    _filter.setStream(attendanceProvider.getAllAttendanceStream());
  }

  Future<void> _generatePdf(List<AttendanceModel> attendanceList) async {
    _filter.setLoading(true);
    final selectedDate = _filter.selectedDate;

    try {
      final pdf = pw.Document();

      // Add title and date
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              // Create table
              pw.Table.fromTextArray(
                border: null,
                headerDecoration: pw.BoxDecoration(color: PdfColors.blue300),
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
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: [
                  'Employee Name',
                  'Status',
                  'Punch In',
                  'Punch Out',
                  'Duration',
                ],
                data: attendanceList.map((attendance) {
                  String duration = '';
                  if (attendance.punchInTime != null &&
                      attendance.punchOutTime != null) {
                    final difference = attendance.punchOutTime!.difference(
                      attendance.punchInTime!,
                    );
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
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              // Add summary statistics
              pw.Bullet(text: 'Total Employees: ${attendanceList.length}'),
              pw.Bullet(
                text:
                    'Present: ${attendanceList.where((a) => a.status == AppConstants.statusPresent && a.punchInTime != null && a.punchOutTime != null).length}',
              ),
              pw.Bullet(
                text:
                    'In Progress: ${attendanceList.where((a) => a.status == AppConstants.statusPending && a.punchInTime != null && a.punchOutTime == null).length}',
              ),
              pw.Bullet(
                text:
                    'Absent: ${attendanceList.where((a) => a.status == AppConstants.statusAbsent).length}',
              ),
              pw.Bullet(
                text:
                    'Half-day: ${attendanceList.where((a) => a.status == AppConstants.statusHalfDay).length}',
              ),
              pw.Bullet(
                text:
                    'On Leave: ${attendanceList.where((a) => a.status == AppConstants.statusOnLeave).length}',
              ),
            ];
          },
        ),
      );

      // Save the PDF
      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/attendance_report_${DateFormat('dd_MM_yyyy').format(selectedDate)}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      // Open the PDF
      await OpenFile.open(file.path);

      ConstantSnackbar.showSuccess(title: 'PDF generated successfully');
    } catch (e) {
      ConstantSnackbar.showError(title: 'Error generating PDF: $e');
    } finally {
      if (mounted) _filter.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _filter,
      child: Consumer<AdminAttendanceFilterProvider>(
        builder: (context, filter, _) => _buildScreen(context, filter),
      ),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    AdminAttendanceFilterProvider filter,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Attendance',
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r),
            onPressed: _initializeStream,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: ConstColors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: ConstColors.neuShadowDark,
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Attendance',
                  style: getTextTheme().titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: ConstantDatePicker(
                        value: filter.selectedDate,
                        format: 'dd MMM yyyy',
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        isDense: true,
                        onChanged: (picked) {
                          if (picked != filter.selectedDate) {
                            _filter.setSelectedDate(picked);
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      // An empty id stands for "All Employees"
                      child: ConstantDropdown<String>(
                        value: filter.selectedEmployeeId ?? '',
                        isDense: true,
                        items: ['', ...filter.employees.map((e) => e.id)],
                        itemLabel: (id) => id.isEmpty
                            ? 'All Employees'
                            : filter.employees
                                  .firstWhere((e) => e.id == id)
                                  .name,
                        onChanged: (id) => filter.setSelectedEmployee(
                          id == null || id.isEmpty ? null : id,
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
              stream: filter.stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppLoadingIndicator(size: 40));
                }

                if (snapshot.hasError) {
                  // Handle different types of errors with user-friendly messages
                  String errorMessage =
                      'Unable to load attendance records at the moment.';

                  if (snapshot.error.toString().contains('permission-denied') ||
                      snapshot.error.toString().contains('PERMISSION_DENIED')) {
                    errorMessage =
                        'Access denied. Please check your admin permissions.';
                  } else if (snapshot.error.toString().contains('network') ||
                      snapshot.error.toString().contains('connection')) {
                    errorMessage =
                        'Network error. Please check your internet connection.';
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64.r,
                          color: ConstColors.inProgressOrange,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          errorMessage,
                          style: getTextTheme().bodyLarge?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                        ConstantButton(
                          text: 'Try Again',
                          onPressed: _initializeStream,
                          icon: Icon(
                            Icons.refresh,
                            size: 20.r,
                            color: ConstColors.textColor,
                          ),
                          isFullWidth: false,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No attendance records found',
                      style: getTextTheme().bodyMedium,
                    ),
                  );
                }

                final filteredAttendance = filter.filter(snapshot.data!);

                if (filteredAttendance.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No attendance records for this date',
                          style: getTextTheme().bodyMedium,
                        ),
                        SizedBox(height: 16.h),
                        ConstantButton(
                          text: 'Mark All Absent',
                          onPressed: () {
                            // Mark all employees as absent for this date
                            _markAbsentEmployees();
                          },
                          icon: Icon(
                            Icons.person_off,
                            size: 20.r,
                            color: ConstColors.white,
                          ),
                          isFullWidth: false,
                          backgroundColor: ConstColors.errorRed,
                        ),
                      ],
                    ),
                  );
                }

                // Everyone's attendance for the chosen date in a data table
                final employeesById = {
                  for (final e in filter.employees) e.id: e,
                };
                final timeFormat = DateFormat('hh:mm a');

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: AppSpacing.screen,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20.w,
                          headingRowColor: WidgetStatePropertyAll(
                            ConstColors.primary.withValues(alpha: 0.1),
                          ),
                          columns: const [
                            DataColumn(label: Text('Employee')),
                            DataColumn(label: Text('Emp ID')),
                            DataColumn(label: Text('Department')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Punch In')),
                            DataColumn(label: Text('Punch Out')),
                            DataColumn(label: Text('Hours')),
                          ],
                          rows: filteredAttendance.map((attendance) {
                            final employee = employeesById[attendance.userId];
                            final worked =
                                attendance.punchInTime != null &&
                                    attendance.punchOutTime != null
                                ? attendance.punchOutTime!.difference(
                                    attendance.punchInTime!,
                                  )
                                : null;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    attendance.userName,
                                    style: getTextTheme().bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(Text(employee?.employeeId ?? '-')),
                                DataCell(Text(employee?.department ?? '-')),
                                DataCell(
                                  _buildStatusChip(
                                    attendance.status,
                                    hasPunchIn: attendance.punchInTime != null,
                                    hasPunchOut:
                                        attendance.punchOutTime != null,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    attendance.punchInTime != null
                                        ? timeFormat.format(
                                            attendance.punchInTime!,
                                          )
                                        : '-',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    attendance.punchOutTime != null
                                        ? timeFormat.format(
                                            attendance.punchOutTime!,
                                          )
                                        : '-',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    worked == null
                                        ? '-'
                                        : '${worked.inHours}h ${worked.inMinutes.remainder(60)}m',
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (filter.isLoading)
                      Container(
                        color: ConstColors.textColor.withValues(alpha: 0.3),
                        child: const Center(
                          child: AppLoadingIndicator(
                            size: 40,
                            color: ConstColors.white,
                          ),
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
          final attendanceProvider = Provider.of<AttendanceProvider>(
            context,
            listen: false,
          );
          attendanceProvider.getAllAttendance().then((attendanceList) {
            final filteredAttendance = filter.filter(attendanceList);
            _generatePdf(filteredAttendance);
          });
        },
        icon: Icon(Icons.download, size: 20.r),
        label: Text('Export PDF', style: getTextTheme().labelLarge),
        backgroundColor: ConstColors.primary,
        foregroundColor: ConstColors.textColor,
      ),
    );
  }

  Future<void> _markAbsentEmployees() async {
    _filter.setLoading(true);
    final selectedDate = _filter.selectedDate;

    try {
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );

      // Get all employees who don't have attendance records for today
      final employeesWithoutAttendance = _filter.employees.where((employee) {
        // Check if employee already has an attendance record for today
        return !attendanceProvider.hasAttendanceForDate(
          employee.id,
          selectedDate,
        );
      }).toList();

      if (employeesWithoutAttendance.isNotEmpty) {
        // Mark all these employees as absent
        for (final employee in employeesWithoutAttendance) {
          await attendanceProvider.markAbsent(employee, selectedDate);
        }

        ConstantSnackbar.showSuccess(
          title:
              'Marked ${employeesWithoutAttendance.length} employees as absent',
        );

        // Refresh the stream
        if (mounted) _initializeStream();
      } else {
        ConstantSnackbar.show(
          title: 'All employees already have attendance records for this date',
          backgroundColor: ConstColors.inProgressOrange,
        );
      }
    } catch (e) {
      ConstantSnackbar.showError(
        title: 'Error marking employees as absent: $e',
      );
    } finally {
      if (mounted) _filter.setLoading(false);
    }
  }

  Widget _buildStatusChip(
    String status, {
    bool hasPunchIn = false,
    bool hasPunchOut = false,
  }) {
    // For pending status (punched in but not punched out), show a special indicator
    if (status.toLowerCase() == AppConstants.statusPending &&
        hasPunchIn &&
        !hasPunchOut) {
      return Text(
        'IN PROGRESS',
        style: getTextTheme().labelSmall?.copyWith(
          color: ConstColors.warningAmber,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Only show present status when both punch in and punch out are available
    if (status.toLowerCase() == AppConstants.statusPresent &&
        (!hasPunchIn || !hasPunchOut)) {
      return Text(
        'INCOMPLETE',
        style: getTextTheme().labelSmall?.copyWith(
          color: ConstColors.textColorLight,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    Color textColor;
    String displayText = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'present':
        textColor = ConstColors.successGreen;
        break;
      case 'absent':
        textColor = ConstColors.errorRed;
        break;
      case 'half-day':
        textColor = ConstColors.inProgressOrange;
        break;
      case 'on-leave':
        textColor = ConstColors.primaryDeep;
        displayText = 'ON LEAVE';
        break;
      default:
        textColor = ConstColors.textColorLight;
    }

    return Text(
      displayText,
      style: getTextTheme().labelSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.bold,
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
