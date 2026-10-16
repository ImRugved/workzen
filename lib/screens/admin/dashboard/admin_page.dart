import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/employee_management_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/admin_settings_form_provider.dart';
import '../../../providers/value_provider.dart';
import '../../../constants/permissions.dart';
import 'package:intl/intl.dart';
import '../../../models/attendance_model.dart';
import '../../../models/holiday_model.dart';
import '../../../models/office_hours_model.dart';
import '../../../widgets/department_role_manager.dart';
import '../../../constants/const_textstyle.dart';
import '../../../constants/constant_button.dart';
import '../../../constants/constant_colors.dart';
import '../../../constants/constant_date_time_picker.dart';
import '../../../constants/constant_snackbar.dart';
import 'package:shimmer/shimmer.dart';

class AdminDemoPage extends StatefulWidget {
  const AdminDemoPage({super.key});

  @override
  State<AdminDemoPage> createState() => _AdminDemoPageState();
}

class _AdminDemoPageState extends State<AdminDemoPage> {
  final TextEditingController _plController = TextEditingController();
  final TextEditingController _slController = TextEditingController();
  final TextEditingController _clController = TextEditingController();

  // Form state (carry forward, office times, minutes, assigning flag) lives in
  // this scoped provider; the State only owns it and the text controllers.
  final AdminSettingsFormProvider _form = AdminSettingsFormProvider();

  final TextEditingController _lateAfterController = TextEditingController();
  final TextEditingController _halfDayAfterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _plController.dispose();
    _slController.dispose();
    _clController.dispose();
    _lateAfterController.dispose();
    _halfDayAfterController.dispose();
    _form.dispose();
    super.dispose();
  }

  void _loadData() {
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);
    final empProvider = Provider.of<EmployeeManagementProvider>(
      context,
      listen: false,
    );
    final onboardingProvider = Provider.of<OnboardingProvider>(
      context,
      listen: false,
    );
    dashProvider.loadDashboardData(empProvider, onboardingProvider);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(value: _form, child: _buildPage());
  }

  Widget _buildPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: getTextTheme().titleMedium?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          Consumer3<
            EmployeeManagementProvider,
            AttendanceProvider,
            DashboardProvider
          >(
            builder: (context, empProvider, attProvider, dashProvider, _) {
              // Leave counts, office hours and holidays (live, shared)
              final org = Provider.of<OrganizationProvider>(context);
              final auth = Provider.of<AuthProvider>(context);

              return RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Each section is shown only if this admin / sub admin
                      // has the matching permission.

                      // Reminder: leave not yet assigned for the current year
                      if (auth.can(Permissions.onboarding) &&
                          !dashProvider.isLoadingEmployeeLeaves &&
                          dashProvider.missingLeaveCount > 0) ...[
                        _buildAssignLeaveBanner(dashProvider.missingLeaveCount),
                        SizedBox(height: 16.h),
                      ],

                      // 1. Today's Attendance
                      if (auth.can(Permissions.viewAttendance))
                        _buildAttendanceSection(empProvider, attProvider),

                      // 2. Department & Roles
                      if (auth.can(Permissions.departments)) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildSectionHeader(
                                'Departments & Roles',
                                Icons.business,
                              ),
                            ),
                            if (empProvider.departments.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => DepartmentRoleManager
                                    .showAddDepartmentDialog(
                                      context,
                                      empProvider,
                                    ),
                                icon: Icon(Icons.add, size: 18.r),
                                label: const Text('Add'),
                              ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        _buildDepartmentSection(empProvider),
                        SizedBox(height: 24.h),
                      ],

                      // 3. Leave Configuration
                      if (auth.can(Permissions.leaveConfig)) ...[
                        _buildSectionHeader(
                          'Leave Configuration',
                          Icons.settings_outlined,
                        ),
                        SizedBox(height: 10.h),
                        _buildLeaveConfigSection(org),
                        SizedBox(height: 24.h),
                      ],

                      // Office Hours
                      if (auth.can(Permissions.officeHours)) ...[
                        _buildSectionHeader('Office Hours', Icons.access_time),
                        SizedBox(height: 10.h),
                        _buildOfficeHoursSection(org),
                        SizedBox(height: 24.h),
                      ],

                      // Holiday Calendar
                      if (auth.can(Permissions.holidays)) ...[
                        _buildSectionHeader(
                          'Holiday Calendar',
                          Icons.event_outlined,
                        ),
                        SizedBox(height: 10.h),
                        _buildHolidaySection(org),
                        SizedBox(height: 24.h),
                      ],

                      // 4. Employee Leave Balances
                      if (auth.can(Permissions.manageEmployees) ||
                          auth.can(Permissions.onboarding)) ...[
                        _buildSectionHeader(
                          'Employee Leave Balances',
                          Icons.people_outline,
                        ),
                        SizedBox(height: 10.h),
                        _buildEmployeeLeaveSection(empProvider, dashProvider),
                        SizedBox(height: 24.h),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  // --- New year leave reminder ---
  Widget _buildAssignLeaveBanner(int missing) {
    final year = DateTime.now().year;

    return Card(
      color: Colors.orange.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: Colors.orange.shade800,
              size: 26.r,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign $year leaves',
                    style: getTextTheme().titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  Text(
                    '$missing onboarded employee(s) have no leave for $year yet.',
                    style: getTextTheme().bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Selector<AdminSettingsFormProvider, bool>(
              selector: (_, f) => f.isAssigningLeaves,
              builder: (context, isAssigning, _) => ConstantButton(
                text: 'Assign',
                onPressed: isAssigning ? null : _assignYearLeaves,
                isLoading: isAssigning,
                isFullWidth: false,
                height: 40.h,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignYearLeaves() async {
    final onboarding = Provider.of<OnboardingProvider>(context, listen: false);
    final year = DateTime.now().year;

    if (!onboarding.isLeaveConfigured) {
      ConstantSnackbar.show(
        title: 'Set the default leave counts first (Leave Configuration)',
        backgroundColor: Colors.orange,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Assign $year leaves?'),
        content: Text(
          'Every onboarded employee without leave for $year gets the default '
          'PL / SL / CL (for the types enabled for them).\n\n'
          'Unused PL: ${onboarding.carryForwardPL ? 'carried forward' : 'reset to 0'}\n'
          'Unused comp off: ${onboarding.carryForwardCompOff ? 'carried forward' : 'reset to 0'}\n'
          'SL and CL always reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ConstantButton(
            text: 'Assign',
            onPressed: () => Navigator.pop(c, true),
            isFullWidth: false,
            height: 40.h,
          ),
        ],
      ),
    );
    if (confirm != true) return;

    _form.setAssigningLeaves(true);
    final count = await onboarding.renewYearlyLeaves(newYear: year);
    if (!mounted) return;
    _form.setAssigningLeaves(false);

    if (count > 0) {
      ConstantSnackbar.showSuccess(
        title: 'Assigned $year leaves to $count employee(s)',
      );
    } else {
      ConstantSnackbar.show(
        title: 'No employees needed $year leaves',
        backgroundColor: Colors.orange,
      );
    }
    _loadData();
  }

  // --- Section Header ---
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22.r, color: ConstColors.primary),
        SizedBox(width: 8.w),
        Text(
          title,
          style: getTextTheme().titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ConstColors.textColor,
          ),
        ),
      ],
    );
  }

  // --- 1. Today's Attendance ---
  Widget _buildAttendanceSection(
    EmployeeManagementProvider empProvider,
    AttendanceProvider attProvider,
  ) {
    return StreamBuilder<List<AttendanceModel>>(
      stream: attProvider.getAllAttendanceStream(),
      builder: (context, snapshot) {
        final allRecords = snapshot.data ?? [];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final todayRecords = allRecords.where((a) {
          final aDate = DateTime(a.date.year, a.date.month, a.date.day);
          return aDate.isAtSameMomentAs(today);
        }).toList();

        final present = todayRecords.where((a) => a.status == 'present').length;
        final absent = todayRecords.where((a) => a.status == 'absent').length;
        final onLeave = todayRecords
            .where((a) => a.status == 'on-leave')
            .length;
        final halfDay = todayRecords
            .where((a) => a.status == 'half-day')
            .length;
        final total = present + absent + onLeave + halfDay;

        if (total == 0) return const SizedBox.shrink();

        final chartData = [
          _ChartItem('Present', present, ConstColors.successGreen),
          _ChartItem('Absent', absent, ConstColors.errorRed),
          _ChartItem('On Leave', onLeave, ConstColors.inProgressOrange),
          _ChartItem('Half Day', halfDay, ConstColors.warningAmber),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Today's Attendance", Icons.access_time),
            SizedBox(height: 10.h),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  children: [
                    // Pie Chart
                    SizedBox(
                      width: 180.w,
                      height: 180.h,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 45.r,
                              sections: chartData
                                  .where((d) => d.count > 0)
                                  .map(
                                    (d) => PieChartSectionData(
                                      value: d.count.toDouble(),
                                      title: '${d.count}',
                                      color: d.color,
                                      radius: 32.r,
                                      titleStyle: getTextTheme().bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$total',
                                style: getTextTheme().titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ConstColors.primary,
                                ),
                              ),
                              Text(
                                'Today',
                                style: getTextTheme().labelSmall?.copyWith(
                                  color: ConstColors.textColorLight,
                                  fontSize: 10.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: chartData
                          .map(
                            (d) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10.w,
                                  height: 10.h,
                                  decoration: BoxDecoration(
                                    color: d.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${d.label} ',
                                  style: getTextTheme().labelMedium?.copyWith(
                                    color: ConstColors.textColorLight,
                                  ),
                                ),
                                Text(
                                  '${d.count}',
                                  style: getTextTheme().labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: d.color,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        );
      },
    );
  }

  // --- 2. Department & Roles ---
  Widget _buildDepartmentSection(EmployeeManagementProvider provider) {
    if (provider.departments.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: ConstColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.business,
                  size: 28.r,
                  color: ConstColors.primary,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'No departments yet',
                style: getTextTheme().titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Add your first department. You can add roles to it afterwards.',
                textAlign: TextAlign.center,
                style: getTextTheme().bodySmall?.copyWith(
                  color: ConstColors.textColorLight,
                ),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                width: double.infinity,
                child: ConstantButton(
                  text: 'Add Department',
                  onPressed: () => DepartmentRoleManager.showAddDepartmentDialog(
                    context,
                    provider,
                  ),
                  icon: Icon(Icons.add, size: 20.r, color: ConstColors.white),
                  backgroundColor: ConstColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          children: provider.departments.asMap().entries.map((entry) {
            final dept = entry.value;
            final isLast = entry.key == provider.departments.length - 1;

            final empCount = provider.employees
                .where((e) => e.department == dept.name)
                .length;

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: ConstColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.business,
                        color: ConstColors.primary,
                        size: 20.r,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dept.name,
                                  style: getTextTheme().titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: ConstColors.infoBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  '$empCount emp',
                                  style: getTextTheme().labelSmall?.copyWith(
                                    color: ConstColors.infoBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          dept.roles.isEmpty
                              ? Text(
                                  'No roles assigned',
                                  style: getTextTheme().bodySmall?.copyWith(
                                    color: ConstColors.textColorLight,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              : Wrap(
                                  spacing: 6.w,
                                  runSpacing: 4.h,
                                  children: dept.roles.map((role) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ConstColors.accent.withOpacity(
                                          0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          6.r,
                                        ),
                                        border: Border.all(
                                          color: ConstColors.accent.withOpacity(
                                            0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        role,
                                        style: getTextTheme().labelSmall
                                            ?.copyWith(
                                              color: ConstColors.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        size: 20.r,
                        color: ConstColors.primary,
                      ),
                      tooltip: 'Manage ${dept.name}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => DepartmentRoleManager.showManageSheet(
                        context,
                        provider,
                        dept,
                      ),
                    ),
                  ],
                ),
                if (!isLast) Divider(height: 20.h),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- 3. Employee Leave Balances ---
  Widget _buildEmployeeLeaveSection(
    EmployeeManagementProvider empProvider,
    DashboardProvider dashProvider,
  ) {
    final onboardedEmployees = empProvider.employees
        .where((e) => e.isOnboarded)
        .toList();

    if (dashProvider.isLoadingEmployeeLeaves) {
      return _buildEmployeeLeaveShimmer();
    }

    if (onboardedEmployees.isEmpty) {
      return _buildEmptyCard('No onboarded employees');
    }

    return Column(
      children: onboardedEmployees.map((emp) {
        final leave = dashProvider.employeeLeaves[emp.id];
        final isExpanded = dashProvider.expandedEmployeeId == emp.id;

        return Card(
          elevation: isExpanded ? 3 : 1,
          margin: EdgeInsets.only(bottom: 8.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: isExpanded
                ? BorderSide(color: ConstColors.primary.withOpacity(0.3))
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => dashProvider.toggleExpandedEmployee(emp.id),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18.r,
                        backgroundColor: ConstColors.primary.withOpacity(0.1),
                        child: Text(
                          emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                          style: getTextTheme().titleSmall?.copyWith(
                            color: ConstColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.name,
                              style: getTextTheme().bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${emp.department ?? 'N/A'} • ${emp.jobRole ?? 'N/A'}',
                              style: getTextTheme().labelSmall?.copyWith(
                                color: ConstColors.textColorLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (leave != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: ConstColors.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '${leave.totalBalance} left',
                            style: getTextTheme().labelSmall?.copyWith(
                              color: ConstColors.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: ConstColors.warningAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'No data',
                            style: getTextTheme().labelSmall?.copyWith(
                              color: ConstColors.warningAmber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(width: 4.w),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: ConstColors.textColorLight,
                        size: 20.r,
                      ),
                    ],
                  ),
                  // Expanded details
                  if (isExpanded && leave != null) ...[
                    SizedBox(height: 12.h),
                    const Divider(height: 1),
                    SizedBox(height: 12.h),
                    _buildLeaveBalanceRow(
                      'Privilege Leave (PL)',
                      leave.plTotal,
                      leave.plUsed,
                      leave.plBalance,
                      ConstColors.infoBlue,
                      emp.id,
                      'pl',
                      dashProvider,
                    ),
                    SizedBox(height: 10.h),
                    _buildLeaveBalanceRow(
                      'Sick Leave (SL)',
                      leave.slTotal,
                      leave.slUsed,
                      leave.slBalance,
                      ConstColors.successGreen,
                      emp.id,
                      'sl',
                      dashProvider,
                    ),
                    SizedBox(height: 10.h),
                    _buildLeaveBalanceRow(
                      'Casual Leave (CL)',
                      leave.clTotal,
                      leave.clUsed,
                      leave.clBalance,
                      ConstColors.inProgressOrange,
                      emp.id,
                      'cl',
                      dashProvider,
                    ),
                    SizedBox(height: 12.h),
                    // Summary bar
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.h,
                        horizontal: 12.w,
                      ),
                      decoration: BoxDecoration(
                        color: ConstColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryItem(
                            'Allocated',
                            leave.totalAllocated,
                            ConstColors.primary,
                          ),
                          _buildSummaryItem(
                            'Used',
                            leave.totalUsed,
                            ConstColors.errorRed,
                          ),
                          _buildSummaryItem(
                            'Balance',
                            leave.totalBalance,
                            ConstColors.successGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isExpanded && leave == null) ...[
                    SizedBox(height: 12.h),
                    Text(
                      'Leave balance not allocated yet',
                      style: getTextTheme().bodySmall?.copyWith(
                        color: ConstColors.textColorLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveBalanceRow(
    String label,
    int total,
    int used,
    int balance,
    Color color,
    String employeeId,
    String leaveType,
    DashboardProvider dashProvider,
  ) {
    final progress = total > 0 ? used / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: getTextTheme().bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '$used / $total',
                  style: getTextTheme().bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(width: 4.w),
                InkWell(
                  onTap: () => _showEditLeaveDialog(
                    employeeId,
                    leaveType,
                    total,
                    dashProvider,
                  ),
                  borderRadius: BorderRadius.circular(4.r),
                  child: Padding(
                    padding: EdgeInsets.all(2.r),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14.r,
                      color: ConstColors.textColorLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 4.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6.h,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: getTextTheme().titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: getTextTheme().labelSmall?.copyWith(
            color: ConstColors.textColorLight,
          ),
        ),
      ],
    );
  }

  // --- Edit Leave Dialog ---
  void _showEditLeaveDialog(
    String employeeId,
    String leaveType,
    int currentTotal,
    DashboardProvider dashProvider,
  ) {
    final controller = TextEditingController(text: currentTotal.toString());
    final leaveLabel = leaveType == 'pl'
        ? 'Privilege Leave'
        : leaveType == 'sl'
        ? 'Sick Leave'
        : 'Casual Leave';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $leaveLabel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set total allocated days:',
              style: getTextTheme().bodyMedium?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Total Days',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 10.h,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ConstantButton(
            text: 'Save',
            backgroundColor: ConstColors.primary,
            isFullWidth: false,
            height: 40.h,
            onPressed: () async {
              final newTotal = int.tryParse(controller.text);
              if (newTotal == null || newTotal < 0) return;
              Navigator.pop(ctx);

              final empProvider = Provider.of<EmployeeManagementProvider>(
                context,
                listen: false,
              );
              final onboardingProvider = Provider.of<OnboardingProvider>(
                context,
                listen: false,
              );

              await dashProvider.updateLeaveAllocation(
                employeeId,
                leaveType,
                newTotal,
                empProvider,
                onboardingProvider,
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 3. Leave Configuration ---
  Widget _buildLeaveConfigSection(OrganizationProvider org) {
    if (!org.leaveConfigLoaded) {
      return _buildLeaveConfigShimmer();
    }

    if (!_form.leaveConfigInitialized) {
      // Left empty until the admin sets the defaults for the first time
      final config = org.leaveConfig;
      if (config != null) {
        _plController.text = config.privilegeLeaves.toString();
        _slController.text = config.sickLeaves.toString();
        _clController.text = config.casualLeaves.toString();
      }
      _form.initLeaveConfig(config);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set default annual leave allocation for new employees',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            SizedBox(height: 16.h),
            _buildLeaveConfigField(
              'Privilege Leave (PL)',
              _plController,
              ConstColors.infoBlue,
            ),
            SizedBox(height: 12.h),
            _buildLeaveConfigField(
              'Sick Leave (SL)',
              _slController,
              ConstColors.successGreen,
            ),
            SizedBox(height: 12.h),
            _buildLeaveConfigField(
              'Casual Leave (CL)',
              _clController,
              ConstColors.inProgressOrange,
            ),
            SizedBox(height: 12.h),
            const Divider(height: 1),
            Text(
              'When next year\'s leave is assigned',
              style: getTextTheme().labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Ticked: unused days move to the new year. Unticked: they reset to 0. '
              'Sick and casual leave always reset.',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            Consumer<AdminSettingsFormProvider>(
              builder: (context, form, _) => Column(
                children: [
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: ConstColors.primary,
                    title: const Text('Carry forward Privilege Leave (PL)'),
                    value: form.carryForwardPL,
                    onChanged: (v) => form.setCarryForwardPL(v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: ConstColors.primary,
                    title: const Text('Carry forward Comp Off'),
                    value: form.carryForwardCompOff,
                    onChanged: (v) => form.setCarryForwardCompOff(v ?? false),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              child: ConstantButton(
                text: 'Save Defaults',
                onPressed: org.isSavingLeaveConfig
                    ? null
                    : () => _saveLeaveConfig(org),
                backgroundColor: ConstColors.primary,
                isLoading: org.isSavingLeaveConfig,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveConfigField(
    String label,
    TextEditingController controller,
    Color accentColor,
  ) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
            style: getTextTheme().bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 80.w,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8.w,
                vertical: 8.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              suffixText: 'days',
              suffixStyle: getTextTheme().labelSmall,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveLeaveConfig(OrganizationProvider org) async {
    final pl = int.tryParse(_plController.text);
    final sl = int.tryParse(_slController.text);
    final cl = int.tryParse(_clController.text);

    if (pl == null || sl == null || cl == null || pl < 0 || sl < 0 || cl < 0) {
      ConstantSnackbar.showError(
        title: 'Please enter valid numbers for all leave types',
      );
      return;
    }

    final success = await org.saveLeaveConfig(
      pl,
      sl,
      cl,
      carryForwardPL: _form.carryForwardPL,
      carryForwardCompOff: _form.carryForwardCompOff,
    );
    if (success) {
      ConstantSnackbar.showSuccess(title: 'Leave defaults saved successfully');
    } else {
      ConstantSnackbar.showError(title: 'Failed to save leave defaults');
    }
  }

  // --- Office Hours ---
  Widget _buildOfficeHoursSection(OrganizationProvider org) {
    if (!org.officeHoursLoaded) {
      return _buildLeaveConfigShimmer();
    }

    // Fill the form once from the saved values; stays empty until configured
    if (!_form.officeHoursInitialized) {
      final saved = org.officeHours;
      if (saved != null) {
        _lateAfterController.text = saved.lateAfterMinutes?.toString() ?? '';
        _halfDayAfterController.text =
            saved.halfDayAfterMinutes?.toString() ?? '';
      }
      _form.initOfficeHours(saved);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set the office timing and when a punch in counts as late or a half day',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            SizedBox(height: 16.h),
            Consumer<AdminSettingsFormProvider>(
              builder: (context, form, _) => Row(
                children: [
                  Expanded(
                    child: _buildTimeButton(
                      'Office start',
                      form.officeStart,
                      form.setOfficeStart,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildTimeButton(
                      'Office end',
                      form.officeEnd,
                      form.setOfficeEnd,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _buildMinutesField(
              'Late after (optional)',
              _lateAfterController,
              ConstColors.calendarLate,
              _form.setLateAfterText,
            ),
            SizedBox(height: 12.h),
            _buildMinutesField(
              'Half day after (optional)',
              _halfDayAfterController,
              ConstColors.calendarHalfDay,
              _form.setHalfDayAfterText,
            ),
            Consumer<AdminSettingsFormProvider>(
              builder: (context, form, _) {
                final preview = _officeHoursPreview(context, form);
                if (preview == null) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: ConstColors.infoBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      preview,
                      style: getTextTheme().bodySmall?.copyWith(
                        color: ConstColors.infoBlue,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ConstantButton(
                text: 'Save Office Hours',
                onPressed: org.isSavingOfficeHours
                    ? null
                    : () => _saveOfficeHours(org),
                backgroundColor: ConstColors.primary,
                isLoading: org.isSavingOfficeHours,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Late and half day rules are optional; a blank field means "not used"
  String? _officeHoursPreview(
    BuildContext context,
    AdminSettingsFormProvider form,
  ) {
    final startTime = form.officeStart;
    final lateAfter = form.lateAfter;
    final halfDayAfter = form.halfDayAfter;
    if (startTime == null || (lateAfter == null && halfDayAfter == null)) {
      return null;
    }

    final start = OfficeHoursModel(
      startTime: startTime,
      endTime: form.officeEnd ?? startTime,
    );
    final parts = <String>[];
    if (lateAfter != null) {
      parts.add('On time until ${start.startPlus(lateAfter).format(context)}');
    }
    if (lateAfter != null && halfDayAfter != null) {
      parts.add('Late until ${start.startPlus(halfDayAfter).format(context)}');
    }
    if (halfDayAfter != null) {
      parts.add(
        'Half day after ${start.startPlus(halfDayAfter).format(context)}',
      );
    }
    return parts.join(' • ');
  }

  Widget _buildTimeButton(
    String label,
    TimeOfDay? value,
    ValueChanged<TimeOfDay> onPicked,
  ) {
    return ConstantButton(
      text: '$label: ${value == null ? 'Select' : value.format(context)}',
      isOutlined: true,
      backgroundColor: ConstColors.primary,
      height: 44.h,
      maxLines: 2,
      horizontalInnerPadding: 8.w,
      onPressed: () async {
        final picked = await ConstantTimePicker.pick(
          context,
          initialTime: value ?? const TimeOfDay(hour: 10, minute: 0),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }

  Widget _buildMinutesField(
    String label,
    TextEditingController controller,
    Color accentColor,
    ValueChanged<String> onChanged,
  ) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.h,
          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            '$label (minutes after start)',
            style: getTextTheme().bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 80.w,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: onChanged,
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8.w,
                vertical: 8.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              suffixText: 'min',
              suffixStyle: getTextTheme().labelSmall,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveOfficeHours(OrganizationProvider org) async {
    final start = _form.officeStart;
    final end = _form.officeEnd;
    final lateText = _lateAfterController.text.trim();
    final halfDayText = _halfDayAfterController.text.trim();
    // Blank means the rule is not used; anything typed must be a valid number
    final lateAfter = lateText.isEmpty ? null : int.tryParse(lateText);
    final halfDayAfter = halfDayText.isEmpty ? null : int.tryParse(halfDayText);

    if (start == null || end == null) {
      ConstantSnackbar.showError(title: 'Select the office start and end time');
      return;
    }
    if ((lateText.isNotEmpty && (lateAfter == null || lateAfter < 0)) ||
        (halfDayText.isNotEmpty && (halfDayAfter == null || halfDayAfter < 0))) {
      ConstantSnackbar.showError(title: 'Enter valid minutes or leave blank');
      return;
    }
    if (lateAfter != null && halfDayAfter != null && halfDayAfter <= lateAfter) {
      ConstantSnackbar.showError(
        title: 'Half day minutes must be more than late minutes',
      );
      return;
    }
    if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
      ConstantSnackbar.showError(
        title: 'Office end time must be after the start time',
      );
      return;
    }

    final success = await org.saveOfficeHours(
      OfficeHoursModel(
        startTime: start,
        endTime: end,
        lateAfterMinutes: lateAfter,
        halfDayAfterMinutes: halfDayAfter,
      ),
    );
    if (success) {
      ConstantSnackbar.showSuccess(title: 'Office hours saved successfully');
    } else {
      ConstantSnackbar.showError(title: 'Failed to save office hours');
    }
  }

  // --- Holiday Calendar ---
  Widget _buildHolidaySection(OrganizationProvider org) {
    if (!org.holidaysLoaded) {
      return _buildLeaveConfigShimmer();
    }

    final holidays = org.holidays;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Public holidays & festival days',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddHolidayDialog(org),
                  icon: Icon(Icons.add, size: 18.r),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (holidays.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Center(
                  child: Text(
                    'No holidays added yet',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                ),
              )
            else
              ...holidays.map((h) => _buildHolidayTile(h, org)),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayTile(HolidayModel holiday, OrganizationProvider provider) {
    final isPast = holiday.date.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );

    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Row(
        children: [
          Container(
            width: 48.w,
            padding: EdgeInsets.symmetric(vertical: 6.h),
            decoration: BoxDecoration(
              color: (isPast ? Colors.grey : ConstColors.primary).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(holiday.date),
                  style: getTextTheme().titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPast ? Colors.grey : ConstColors.primary,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(holiday.date),
                  style: getTextTheme().labelSmall?.copyWith(
                    color: isPast ? Colors.grey : ConstColors.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  style: getTextTheme().bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isPast ? Colors.grey : null,
                  ),
                ),
                Text(
                  [
                    DateFormat('EEEE, yyyy').format(holiday.date),
                    if (holiday.description != null) holiday.description!,
                  ].join(' • '),
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20.r, color: Colors.red),
            onPressed: () => _confirmDeleteHoliday(holiday, provider),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteHoliday(
    HolidayModel holiday,
    OrganizationProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Remove "${holiday.name}" from the holiday calendar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: getTextTheme().labelLarge?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await provider.deleteHoliday(holiday.id);
    if (success) {
      ConstantSnackbar.showSuccess(title: 'Holiday deleted');
    } else {
      ConstantSnackbar.showError(title: 'Failed to delete holiday');
    }
  }

  Future<void> _showAddHolidayDialog(OrganizationProvider provider) async {
    final result = await showDialog<_HolidayInput>(
      context: context,
      builder: (_) => const _AddHolidayDialog(),
    );

    if (result == null) return;

    final success = await provider.addHoliday(
      result.name,
      result.date,
      description: result.description,
    );
    if (success) {
      ConstantSnackbar.showSuccess(title: 'Holiday added');
    } else {
      ConstantSnackbar.showError(title: 'Failed to add holiday');
    }
  }

  // --- Shimmer Helpers ---
  Widget _buildShimmerBox({
    double? width,
    required double height,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius.r),
      ),
    );
  }

  Widget _buildEmployeeLeaveShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          3,
          (_) => Card(
            elevation: 1,
            margin: EdgeInsets.only(bottom: 8.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  CircleAvatar(radius: 18.r, backgroundColor: Colors.white),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBox(width: 120.w, height: 12.h),
                        SizedBox(height: 6.h),
                        _buildShimmerBox(width: 180.w, height: 10.h),
                      ],
                    ),
                  ),
                  _buildShimmerBox(width: 50.w, height: 20.h, radius: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveConfigShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShimmerBox(width: 250.w, height: 12.h),
              SizedBox(height: 16.h),
              ...List.generate(
                3,
                (_) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    children: [
                      _buildShimmerBox(width: 8.w, height: 8.h, radius: 4),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildShimmerBox(height: 12.h),
                      ),
                      SizedBox(width: 12.w),
                      _buildShimmerBox(width: 80.w, height: 36.h),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              _buildShimmerBox(height: 44.h),
            ],
          ),
        ),
      ),
    );
  }

  // --- Empty State ---
  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Center(
          child: Text(
            message,
            style: getTextTheme().bodyMedium?.copyWith(
              color: ConstColors.textColorLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

class _HolidayInput {
  final String name;
  final DateTime date;
  final String? description;

  _HolidayInput(this.name, this.date, this.description);
}

// Owns its controllers so they are disposed only after the dialog's close
// animation has finished.
class _AddHolidayDialog extends StatefulWidget {
  const _AddHolidayDialog();

  @override
  State<_AddHolidayDialog> createState() => _AddHolidayDialogState();
}

class _AddHolidayDialogState extends State<_AddHolidayDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  // Picked date, scoped to this dialog
  final ValueProvider<DateTime?> _selectedDate = ValueProvider<DateTime?>(null);

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _selectedDate.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await ConstantDatePicker.pick(
      context,
      initialDate: _selectedDate.value ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked != null) _selectedDate.value = picked;
  }

  void _save() {
    final name = _nameController.text.trim();
    final date = _selectedDate.value;
    if (name.isEmpty || date == null) {
      ConstantSnackbar.showError(title: 'Enter holiday name and select a date');
      return;
    }
    final description = _descController.text.trim();
    Navigator.of(context).pop(
      _HolidayInput(name, date, description.isEmpty ? null : description),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Holiday'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Holiday name',
              hintText: 'e.g. Independence Day',
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          SizedBox(height: 12.h),
          ChangeNotifierProvider.value(
            value: _selectedDate,
            child: Consumer<ValueProvider<DateTime?>>(
              builder: (context, picked, _) => ConstantButton(
                icon: Icon(
                  Icons.calendar_today,
                  size: 18.r,
                  color: ConstColors.primary,
                ),
                text: picked.value == null
                    ? 'Select date'
                    : DateFormat('dd MMM yyyy').format(picked.value!),
                isOutlined: true,
                backgroundColor: ConstColors.primary,
                isFullWidth: false,
                height: 40.h,
                onPressed: _pickDate,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ConstantButton(
          text: 'Save',
          onPressed: _save,
          isFullWidth: false,
          height: 40.h,
        ),
      ],
    );
  }
}

class _ChartItem {
  final String label;
  final int count;
  final Color color;

  _ChartItem(this.label, this.count, this.color);
}
