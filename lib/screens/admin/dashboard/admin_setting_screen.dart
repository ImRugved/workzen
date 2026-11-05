import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../providers/employee_management_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/admin_settings_form_provider.dart';
import '../../../constants/permissions.dart';
import 'package:intl/intl.dart';
import '../../../models/attendance_model.dart';
import '../../../models/office_hours_model.dart';
import '../../../widgets/department_role_manager.dart';
import '../../../widgets/holiday_calendar_card.dart';
import '../../../widgets/office_location_form.dart';
import '../../../widgets/donut_stat_card.dart';
import '../../../widgets/employee_name_sheet.dart';
import '../../../constants/const_textstyle.dart';
import '../../../constants/constant_button.dart';
import '../../../constants/constant_colors.dart';
import '../../../constants/app_theme.dart';
import '../../../constants/constant_date_time_picker.dart';
import '../../../constants/constant_snackbar.dart';
import 'package:shimmer/shimmer.dart';

/// The Settings tab of the admin dashboard: today's attendance, departments and
/// roles, leave configuration, office hours, the holiday calendar and the way in
/// to Manage Employee Leaves. Each section shows only for an admin or sub admin
/// with its permission.
class AdminSettingScreen extends StatefulWidget {
  const AdminSettingScreen({super.key});

  @override
  State<AdminSettingScreen> createState() => _AdminSettingScreenState();
}

class _AdminSettingScreenState extends State<AdminSettingScreen> {
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

  // Today's attendance listener, kept so rebuilds reuse it. Dropped on refresh,
  // which also picks up a new day if the screen stayed open overnight.
  Stream<List<AttendanceModel>>? _todayAttendance;

  void _loadData() {
    _todayAttendance = null;
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
          style: getTextTheme().titleMedium?.copyWith(
            color: ConstColors.textColor,
          ),
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
                  padding: AppSpacing.screen,
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
                                onPressed: () =>
                                    DepartmentRoleManager.showAddDepartmentDialog(
                                      context,
                                      empProvider,
                                    ),
                                icon: Icon(
                                  Icons.add,
                                  size: 18.r,
                                  color: ConstColors.primaryDeep,
                                ),
                                label: Text(
                                  'Add',
                                  style: getTextTheme().labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: ConstColors.primaryDeep,
                                  ),
                                ),
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

                      // Office Location
                      if (auth.can(Permissions.officeHours)) ...[
                        _buildSectionHeader(
                          'Office Location',
                          Icons.location_on_outlined,
                        ),
                        SizedBox(height: 10.h),
                        _buildOfficeLocationSection(org),
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
                          auth.can(Permissions.onboarding) ||
                          auth.can(Permissions.leaveRequests)) ...[
                        _buildSectionHeader(
                          'Employee Leaves',
                          Icons.people_outline,
                        ),
                        SizedBox(height: 10.h),
                        // One button: the leave balances and the past leave
                        // records are on that screen, in two tabs
                        SizedBox(
                          width: double.infinity,
                          child: ConstantButton(
                            text: 'Manage Employee Leaves',
                            icon: Icon(
                              Icons.event_note_outlined,
                              size: 20.r,
                              color: ConstColors.textColor,
                            ),
                            onPressed: () =>
                                Get.toNamed('/manage_employee_leave_screen'),
                            backgroundColor: ConstColors.primary,
                          ),
                        ),
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

    return NeuCard(
      color: ConstColors.inProgressOrange.withValues(alpha: 0.08),
      borderColor: ConstColors.inProgressOrange.withValues(alpha: 0.4),
      radius: NeuStyle.radiusSmall,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: ConstColors.inProgressOrange,
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
                      color: ConstColors.inProgressOrange,
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
        backgroundColor: ConstColors.inProgressOrange,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Assign $year leaves?'),
        content: Text(
          'Every onboarded employee without leave for $year gets the default '
          '${onboarding.isPrivilegeLeaveOffered ? 'PL / ' : ''}SL / CL '
          '(for the types enabled for them).\n\n'
          '${onboarding.isPrivilegeLeaveOffered ? 'Unused PL: ${onboarding.carryForwardPL ? 'carried forward' : 'reset to 0'}\n' : ''}'
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
        backgroundColor: ConstColors.inProgressOrange,
      );
    }
    _loadData();
  }

  // --- Section Header ---
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22.r, color: ConstColors.primaryDeep),
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
      // One listener for today's records, created once: creating it inside the
      // builder would open a new listener (and re-read) on every rebuild
      stream: _todayAttendance ??= attProvider.getAttendanceStream(
        from: DateTime.now(),
        to: DateTime.now(),
      ),
      builder: (context, snapshot) {
        final allRecords = snapshot.data ?? [];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final todayRecords = allRecords.where((a) {
          final aDate = DateTime(a.date.year, a.date.month, a.date.day);
          return aDate.isAtSameMomentAs(today);
        }).toList();

        // Someone who has punched in is present even before punching out
        // (their record is "pending" until then)
        // A half day leave is counted as a half day, not as present
        final presentRecords = todayRecords
            .where(
              (a) =>
                  a.halfDayLeave == null &&
                  (a.status == 'present' ||
                      (a.status == 'pending' && a.punchInTime != null)),
            )
            .toList();
        final absentRecords = todayRecords
            .where((a) => a.status == 'absent')
            .toList();
        final leaveRecords = todayRecords
            .where((a) => a.status == 'on-leave')
            .toList();
        final halfDayRecords = todayRecords
            .where((a) => a.status == 'half-day' || a.halfDayLeave != null)
            .toList();

        // Onboarded employees with no record today have not punched in yet
        final recordedIds = todayRecords.map((a) => a.userId).toSet();
        final notInYet = empProvider.employees
            .where((e) => e.isOnboarded && !recordedIds.contains(e.id))
            .toList();

        final total =
            presentRecords.length +
            halfDayRecords.length +
            leaveRecords.length +
            absentRecords.length +
            notInYet.length;

        if (total == 0) return const SizedBox.shrink();

        // Names of the people counted in a row, shown in a bottom sheet
        void showNames(
          String title,
          Color color,
          List<AttendanceModel> records,
        ) {
          final time = DateFormat('hh:mm a');
          EmployeeNameSheet.show(
            context,
            title: title,
            color: color,
            entries: [
              for (final a in records)
                EmployeeNameEntry(
                  a.userName,
                  [
                    if (a.punchInTime != null)
                      'In ${time.format(a.punchInTime!)}',
                    if (a.punchOutTime != null)
                      'Out ${time.format(a.punchOutTime!)}',
                  ].join(' • '),
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSectionHeader(
                    "Today's Attendance",
                    Icons.access_time,
                  ),
                ),
                Text(
                  DateFormat('EEE, dd MMM').format(now),
                  style: getTextTheme().labelMedium?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // The app's donut: today's employees by attendance type
            DonutStatCard(
              centerLabel: 'Employees',
              // Tap a row to see who is in it
              items: [
                DonutStatItem(
                  'Present',
                  presentRecords.length,
                  ConstColors.successGreen,
                  onTap: () => showNames(
                    'Present',
                    ConstColors.successGreen,
                    presentRecords,
                  ),
                ),
                DonutStatItem(
                  'Half Day',
                  halfDayRecords.length,
                  ConstColors.warningAmber,
                  onTap: () => showNames(
                    'Half Day',
                    ConstColors.warningAmber,
                    halfDayRecords,
                  ),
                ),
                DonutStatItem(
                  'On Leave',
                  leaveRecords.length,
                  ConstColors.inProgressOrange,
                  onTap: () => showNames(
                    'On Leave',
                    ConstColors.inProgressOrange,
                    leaveRecords,
                  ),
                ),
                DonutStatItem(
                  'Absent',
                  absentRecords.length,
                  ConstColors.errorRed,
                  onTap: () => showNames(
                    'Absent',
                    ConstColors.errorRed,
                    absentRecords,
                  ),
                ),
                DonutStatItem(
                  'Not in yet',
                  notInYet.length,
                  ConstColors.pendingGrey,
                  onTap: () => EmployeeNameSheet.show(
                    context,
                    title: 'Not in yet',
                    color: ConstColors.pendingGrey,
                    entries: [
                      for (final e in notInYet)
                        EmployeeNameEntry(
                          e.name,
                          [
                            if (e.department != null) e.department!,
                            if (e.jobRole != null) e.jobRole!,
                          ].join(' • '),
                        ),
                    ],
                  ),
                ),
              ],
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
      return NeuCard(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: ConstColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.business,
                  size: 28.r,
                  color: ConstColors.primaryDeep,
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
                  onPressed: () =>
                      DepartmentRoleManager.showAddDepartmentDialog(
                        context,
                        provider,
                      ),
                  icon: Icon(
                    Icons.add,
                    size: 20.r,
                    color: ConstColors.textColor,
                  ),
                  backgroundColor: ConstColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // One tappable card per department; tapping opens its manage sheet
    return Column(
      children: provider.departments.map((dept) {
        final empCount = provider.employees
            .where((e) => e.department == dept.name)
            .length;

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 5.h),
          child: NeuCard(
            onTap: () => DepartmentRoleManager.showManageSheet(
              context,
              provider,
              dept,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36.r,
                        height: 36.r,
                        decoration: BoxDecoration(
                          color: ConstColors.lightShade,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.business,
                          size: 20.r,
                          color: ConstColors.primaryDeep,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dept.name,
                              overflow: TextOverflow.ellipsis,
                              style: getTextTheme().bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ConstColors.textColor,
                              ),
                            ),
                            Text(
                              '$empCount ${empCount == 1 ? 'employee' : 'employees'}'
                              '  •  ${dept.roles.length} ${dept.roles.length == 1 ? 'role' : 'roles'}',
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
                  if (dept.roles.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      children: [
                        for (final role in dept.roles)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: ConstColors.lightShade,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              role,
                              style: getTextTheme().labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: ConstColors.textColor,
                              ),
                            ),
                          ),
                      ],
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

    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default leave days each employee gets per year',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            SizedBox(height: 12.h),
            _buildLeaveConfigField(
              'PL',
              'Privilege Leave',
              _plController,
              ConstColors.primary,
            ),
            SizedBox(height: 8.h),
            _buildLeaveConfigField(
              'SL',
              'Sick Leave',
              _slController,
              ConstColors.successGreen,
            ),
            SizedBox(height: 8.h),
            _buildLeaveConfigField(
              'CL',
              'Casual Leave',
              _clController,
              ConstColors.inProgressOrange,
            ),
            SizedBox(height: 8.h),
            // Live total of the three fields
            ListenableBuilder(
              listenable: Listenable.merge([
                _plController,
                _slController,
                _clController,
              ]),
              builder: (context, _) {
                final total =
                    (int.tryParse(_plController.text) ?? 0) +
                    (int.tryParse(_slController.text) ?? 0) +
                    (int.tryParse(_clController.text) ?? 0);
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total $total days a year',
                    style: getTextTheme().labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ConstColors.textColor,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 12.h),
            Divider(height: 1, color: ConstColors.borderColor),
            SizedBox(height: 12.h),
            Text(
              'When next year\'s leave is assigned',
              style: getTextTheme().labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
            ),
            SizedBox(height: 8.h),
            Consumer<AdminSettingsFormProvider>(
              builder: (context, form, _) => Column(
                children: [
                  _buildCarryForwardTile(
                    'Carry forward Privilege Leave',
                    'Unused PL moves to the new year',
                    form.carryForwardPL,
                    form.setCarryForwardPL,
                  ),
                  SizedBox(height: 8.h),
                  _buildCarryForwardTile(
                    'Carry forward Comp Off',
                    'Unused comp off moves to the new year',
                    form.carryForwardCompOff,
                    form.setCarryForwardCompOff,
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16.r,
                  color: ConstColors.textColorLight,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Switched off, unused days reset to 0. Sick and casual '
                    'leave always reset.',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
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

  // One leave type: coloured code badge, its name and a - / number / + stepper
  Widget _buildLeaveConfigField(
    String code,
    String name,
    TextEditingController controller,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Container(
            width: 34.r,
            height: 34.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              code,
              style: getTextTheme().labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: getTextTheme().bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                Text(
                  'days per year',
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          ),
          _stepButton(Icons.remove, () => _stepLeave(controller, -1)),
          SizedBox(
            width: 46.w,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: getTextTheme().bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 8.h,
                ),
              ),
            ),
          ),
          _stepButton(Icons.add, () => _stepLeave(controller, 1)),
        ],
      ),
    );
  }

  // Round white button, 40 wide so it is easy to tap
  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          color: ConstColors.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: ConstColors.borderColor),
        ),
        child: Icon(icon, size: 20.r, color: ConstColors.textColor),
      ),
    );
  }

  // Moves a leave field by one day, never below 0 or above 365
  void _stepLeave(TextEditingController controller, int delta) {
    final current = int.tryParse(controller.text) ?? 0;
    controller.text = (current + delta).clamp(0, 365).toString();
  }

  // A switch row for a carry forward rule
  Widget _buildCarryForwardTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: EdgeInsets.only(left: 12.w, right: 4.w, top: 4.h, bottom: 4.h),
      decoration: BoxDecoration(
        color: ConstColors.lightShade,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
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
          Switch(
            value: value,
            activeThumbColor: ConstColors.white,
            activeTrackColor: ConstColors.primaryDeep,
            onChanged: onChanged,
          ),
        ],
      ),
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

    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Office timing, and when a punch in counts as late or a half day',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            SizedBox(height: 12.h),
            Consumer<AdminSettingsFormProvider>(
              builder: (context, form, _) => Row(
                children: [
                  Expanded(
                    child: _buildTimeButton(
                      'Office start',
                      Icons.wb_sunny_outlined,
                      form.officeStart,
                      form.setOfficeStart,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildTimeButton(
                      'Office end',
                      Icons.nightlight_outlined,
                      form.officeEnd,
                      form.setOfficeEnd,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Attendance rules (optional)',
              style: getTextTheme().labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
            ),
            SizedBox(height: 8.h),
            _buildMinutesField(
              'Late after',
              Icons.schedule,
              _lateAfterController,
              ConstColors.calendarLate,
              _form.setLateAfterText,
            ),
            SizedBox(height: 8.h),
            _buildMinutesField(
              'Half day after',
              Icons.timelapse,
              _halfDayAfterController,
              ConstColors.calendarHalfDay,
              _form.setHalfDayAfterText,
            ),
            Consumer<AdminSettingsFormProvider>(
              builder: (context, form, _) {
                final preview = _officeHoursPreview(context, form);
                if (preview == null) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: ConstColors.lightShade,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16.r,
                          color: ConstColors.primaryDeep,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            preview,
                            style: getTextTheme().bodySmall?.copyWith(
                              color: ConstColors.textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 14.h),
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

  // A tappable tile: small label, the chosen time big, opens the time picker
  Widget _buildTimeButton(
    String label,
    IconData icon,
    TimeOfDay? value,
    ValueChanged<TimeOfDay> onPicked,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () async {
        final picked = await ConstantTimePicker.pick(
          context,
          initialTime: value ?? const TimeOfDay(hour: 10, minute: 0),
        );
        if (picked != null) onPicked(picked);
      },
      child: Ink(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: ConstColors.lightShade,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: ConstColors.cardBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18.r, color: ConstColors.primaryDeep),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: getTextTheme().labelSmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                  Text(
                    value == null ? 'Select' : value.format(context),
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ConstColors.textColor,
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

  // A rule in minutes after office start: badge, title, and a - / number / +
  // stepper. A blank field means the rule is off.
  Widget _buildMinutesField(
    String label,
    IconData icon,
    TextEditingController controller,
    Color color,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Container(
            width: 34.r,
            height: 34.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 18.r, color: ConstColors.textColor),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: getTextTheme().bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                Text(
                  'minutes after start',
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          ),
          _stepButton(
            Icons.remove,
            () => _stepMinutes(controller, -1, onChanged),
          ),
          SizedBox(
            width: 46.w,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: onChanged,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: getTextTheme().bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Off',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 8.h,
                ),
              ),
            ),
          ),
          _stepButton(Icons.add, () => _stepMinutes(controller, 1, onChanged)),
        ],
      ),
    );
  }

  // Moves a minutes field by one; stepping down from 0 (or blank) switches the
  // rule off by clearing the field
  void _stepMinutes(
    TextEditingController controller,
    int delta,
    ValueChanged<String> onChanged,
  ) {
    final current = int.tryParse(controller.text);
    if (delta < 0 && (current == null || current <= 0)) {
      controller.text = '';
    } else {
      controller.text = ((current ?? 0) + delta).clamp(0, 999).toString();
    }
    onChanged(controller.text);
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
        (halfDayText.isNotEmpty &&
            (halfDayAfter == null || halfDayAfter < 0))) {
      ConstantSnackbar.showError(title: 'Enter valid minutes or leave blank');
      return;
    }
    if (lateAfter != null &&
        halfDayAfter != null &&
        halfDayAfter <= lateAfter) {
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

  // --- Office Location ---
  Widget _buildOfficeLocationSection(OrganizationProvider org) {
    if (!org.officeLocationLoaded) {
      return _buildLeaveConfigShimmer();
    }

    final location = org.officeLocation;
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (location == null)
              Text(
                'Not set yet. Until it is set, nobody can punch in, punch out '
                'or take a break.',
                style: getTextTheme().bodySmall?.copyWith(
                  color: ConstColors.inProgressOrange,
                  fontWeight: FontWeight.bold,
                ),
              )
            else ...[
              Text(
                location.name,
                style: getTextTheme().titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              if (location.address != null) ...[
                SizedBox(height: 2.h),
                Text(
                  location.address!,
                  style: getTextTheme().bodySmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
              SizedBox(height: 8.h),
              Text(
                '${location.latitude.toStringAsFixed(6)}, '
                '${location.longitude.toStringAsFixed(6)}  •  '
                '${location.radiusMeters.round()} m radius',
                style: getTextTheme().bodySmall?.copyWith(
                  color: ConstColors.textColor,
                ),
              ),
            ],
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ConstantButton(
                text: location == null
                    ? 'Set Office Location'
                    : 'Change Office Location',
                icon: Icon(
                  Icons.edit_location_alt_outlined,
                  size: 20.r,
                  color: ConstColors.textColor,
                ),
                onPressed: () => OfficeLocationForm.show(context, location),
                backgroundColor: ConstColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Holiday Calendar ---
  Widget _buildHolidaySection(OrganizationProvider org) {
    if (!org.holidaysLoaded) {
      return _buildLeaveConfigShimmer();
    }

    // A short summary only; the full list is managed on its own screen
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Public holidays shown to every employee',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            SizedBox(height: 12.h),
            HolidayStatsRow(holidays: org.holidays, year: DateTime.now().year),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ConstantButton(
                text: 'Manage Holidays',
                icon: Icon(
                  Icons.event_note_outlined,
                  size: 20.r,
                  color: ConstColors.textColor,
                ),
                onPressed: () => Get.toNamed('/holiday_management_screen'),
                backgroundColor: ConstColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
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
        color: ConstColors.cardBackground,
        borderRadius: BorderRadius.circular(radius.r),
      ),
    );
  }

  Widget _buildLeaveConfigShimmer() {
    return Shimmer.fromColors(
      baseColor: ConstColors.borderColor,
      highlightColor: ConstColors.cardBackground,
      child: NeuCard(
        radius: NeuStyle.radiusSmall,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShimmerBox(width: 250.w, height: 12.h),
              SizedBox(height: 16.h),
              ...List.generate(
                3,
                (_) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Row(
                    children: [
                      _buildShimmerBox(width: 8.w, height: 8.h, radius: 4),
                      SizedBox(width: 8.w),
                      Expanded(child: _buildShimmerBox(height: 12.h)),
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
}
