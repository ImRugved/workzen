import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/attendance_model.dart';
import '../../models/office_hours_model.dart';
import '../../providers/admin_attendance_filter_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/organization_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/attendance_export_service.dart';
import '../../services/attendance_report_service.dart';
import '../../widgets/attendance_filter_sheet.dart';
import '../../app_constants.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../constants/constant_button.dart';
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
      // Live office hours, needed for the extra hours column
      context.read<OrganizationProvider>().start();
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
    // Only the chosen dates are listened to, so the reads follow the filter
    // instead of the whole history
    _filter.setStream(
      attendanceProvider.getAttendanceStream(from: _filter.from, to: _filter.to),
    );
  }

  // Time worked after the office end time ("1h 0m"), or "-" when there is none
  // or no office hours are set
  String _extraText(OfficeHoursModel? hours, AttendanceModel attendance) {
    final out = attendance.punchOutTime;
    if (hours == null || out == null) return '-';
    final extra = hours.extraAfterEnd(out);
    return extra == Duration.zero
        ? '-'
        : '${extra.inHours}h ${extra.inMinutes.remainder(60)}m';
  }

  // Opens the filter sheet and applies what was chosen
  Future<void> _openFilterSheet() async {
    final selection = await AttendanceFilterSheet.show(
      context,
      employees: _filter.employees,
      employeeId: _filter.selectedEmployeeId,
      period: _filter.period,
      customRange: _filter.customRange,
    );
    if (selection == null) return;
    _filter.apply(
      employeeId: selection.employeeId,
      period: selection.period,
      customRange: selection.customRange,
    );
    // The listener covers the chosen dates only, so it follows the new ones
    _initializeStream();
  }

  // Export options: PDF or Excel, for what the filter shows
  Future<void> _showExportOptions() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: ConstColors.borderColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Export attendance',
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                _filter.summaryText,
                style: getTextTheme().bodySmall?.copyWith(
                  color: ConstColors.textColorLight,
                ),
              ),
              SizedBox(height: 12.h),
              _exportOption(
                sheetContext,
                icon: Icons.picture_as_pdf_outlined,
                title: 'Export as PDF',
                subtitle: 'Summary and the day by day table',
                value: 'pdf',
              ),
              SizedBox(height: 8.h),
              _exportOption(
                sheetContext,
                icon: Icons.table_chart_outlined,
                title: 'Export as Excel sheet',
                subtitle: 'Summary and Attendance sheets (.xlsx)',
                value: 'excel',
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
    if (format != null) await _export(format);
  }

  Widget _exportOption(
    BuildContext sheetContext, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () => Navigator.pop(sheetContext, value),
      child: Ink(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: ConstColors.lightShade,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: const BoxDecoration(
                color: ConstColors.cardBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22.r, color: ConstColors.primaryDeep),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ConstColors.textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 22.r,
              color: ConstColors.textColorLight,
            ),
          ],
        ),
      ),
    );
  }

  // Builds the report for the current filter (every employee, or the chosen
  // one, over the chosen dates) and writes it in the chosen format
  Future<void> _export(String format) async {
    final employees = _filter.selectedEmployee != null
        ? [_filter.selectedEmployee!]
        : _filter.employees;
    if (employees.isEmpty) {
      ConstantSnackbar.showError(title: 'No employees to export');
      return;
    }

    _filter.setLoading(true);
    try {
      final report = await AttendanceReportService().build(
        employees: employees,
        range: _filter.range,
        employeeLabel: _filter.selectedEmployee?.name ?? 'All employees',
      );

      if (report.rows.isEmpty) {
        ConstantSnackbar.show(
          title: 'No attendance records for this filter',
          backgroundColor: ConstColors.inProgressOrange,
        );
        return;
      }

      final exporter = AttendanceExportService();
      if (format == 'pdf') {
        final file = await exporter.toPdf(report);
        await OpenFile.open(file.path);
      } else {
        // Opening an .xlsx directly hands it to whichever app the phone picks
        // (some phones pick an unrelated one), so the share sheet is used: the
        // admin chooses Excel, Sheets, Drive, mail or Save to device
        final file = await exporter.toExcel(report);
        await SharePlus.instance.share(
          ShareParams(
            title: 'Attendance report',
            subject: 'Attendance report',
            files: [
              XFile(
                file.path,
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              ),
            ],
          ),
        );
      }

      ConstantSnackbar.showSuccess(
        title: '${format == 'pdf' ? 'PDF' : 'Excel sheet'} exported',
      );
    } catch (e) {
      logDebug('Error exporting attendance: $e');
      ConstantSnackbar.showError(title: 'Error exporting attendance');
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
          // A dot shows when something other than "Today, all employees" is on
          IconButton(
            icon: Badge(
              isLabelVisible: filter.isFiltered,
              smallSize: 8.r,
              backgroundColor: ConstColors.errorRed,
              child: Icon(Icons.filter_list, size: 24.r),
            ),
            onPressed: _openFilterSheet,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r),
            onPressed: _initializeStream,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // What the filter currently shows; tap to change it
          InkWell(
            onTap: _openFilterSheet,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              color: ConstColors.lightShade,
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 18.r,
                    color: ConstColors.primaryDeep,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      filter.summaryText,
                      overflow: TextOverflow.ellipsis,
                      style: getTextTheme().bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ConstColors.textColor,
                      ),
                    ),
                  ),
                ],
              ),
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
                          filter.isSingleDay
                              ? 'No attendance records for this date'
                              : 'No attendance records for this filter',
                          style: getTextTheme().bodyMedium,
                        ),
                        // Marking everyone absent only makes sense for one day
                        if (filter.isSingleDay) ...[
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
                      ],
                    ),
                  );
                }

                // Everyone's attendance for the chosen date in a data table
                final employeesById = {
                  for (final e in filter.employees) e.id: e,
                };
                final timeFormat = DateFormat('hh:mm a');
                final officeHours = context
                    .watch<OrganizationProvider>()
                    .officeHours;

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
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Emp ID')),
                            DataColumn(label: Text('Department')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Punch In')),
                            DataColumn(label: Text('Punch Out')),
                            DataColumn(label: Text('Break')),
                            DataColumn(label: Text(' Working Hours')),
                            DataColumn(label: Text('Extra Hrs')),
                          ],
                          rows: filteredAttendance.map((attendance) {
                            final employee = employeesById[attendance.userId];
                            // Break time is taken off the hours worked
                            final breakTime = attendance.breakDuration();
                            final worked =
                                attendance.punchInTime != null &&
                                    attendance.punchOutTime != null
                                ? attendance.punchOutTime!.difference(
                                        attendance.punchInTime!,
                                      ) -
                                      breakTime
                                : null;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(attendance.date),
                                  ),
                                ),
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
                                    halfDayLeave: attendance.halfDayLeave,
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
                                // "-" when no break was taken
                                DataCell(
                                  Text(
                                    attendance.breaks.isEmpty
                                        ? '-'
                                        : '${breakTime.inMinutes} min',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    worked == null
                                        ? '-'
                                        : '${worked.inHours}h ${worked.inMinutes.remainder(60)}m',
                                  ),
                                ),
                                DataCell(
                                  Text(_extraText(officeHours, attendance)),
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
        // Opens the PDF / Excel choice; busy while a report is being built
        onPressed: filter.isLoading ? null : _showExportOptions,
        icon: Icon(Icons.download, size: 20.r, color: ConstColors.textColor),
        // The text style sets its own colour, so black is set here explicitly
        // to stay readable on the soft blue button
        label: Text(
          'Export',
          style: getTextTheme().labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: ConstColors.textColor,
          ),
        ),
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

      // Employees with no record on that day (one read of that day's records)
      final withRecord = await attendanceProvider.userIdsWithRecordOn(
        selectedDate,
      );
      final employeesWithoutAttendance = _filter.employees
          .where((employee) => !withRecord.contains(employee.id))
          .toList();

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
    String? halfDayLeave,
  }) {
    // A half day leave: the other half was worked, so say which half was off
    if (halfDayLeave != null) {
      return Text(
        'HALF DAY (${halfDayLeave == 'Second Half' ? '2ND' : '1ST'} HALF LEAVE)',
        style: getTextTheme().labelSmall?.copyWith(
          color: ConstColors.inProgressOrange,
          fontWeight: FontWeight.bold,
        ),
      );
    }

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

}
