import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/employee_management_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../models/attendance_model.dart';
import '../../../constants/const_textstyle.dart';
import '../../../constants/constant_colors.dart';
import '../../../constants/constant_snackbar.dart';
import 'package:shimmer/shimmer.dart';

class AdminDemoPage extends StatefulWidget {
  const AdminDemoPage({Key? key}) : super(key: key);

  @override
  State<AdminDemoPage> createState() => _AdminDemoPageState();
}

class _AdminDemoPageState extends State<AdminDemoPage> {
  final TextEditingController _plController = TextEditingController();
  final TextEditingController _slController = TextEditingController();
  final TextEditingController _clController = TextEditingController();
  bool _leaveConfigInitialized = false;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics & Overview',
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
              return RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Today's Attendance
                      _buildAttendanceSection(empProvider, attProvider),

                      // 2. Department & Roles
                      _buildSectionHeader(
                        'Departments & Roles',
                        Icons.business,
                      ),
                      SizedBox(height: 10.h),
                      _buildDepartmentSection(empProvider),
                      SizedBox(height: 24.h),

                      // 3. Leave Configuration
                      _buildSectionHeader(
                        'Leave Configuration',
                        Icons.settings_outlined,
                      ),
                      SizedBox(height: 10.h),
                      _buildLeaveConfigSection(dashProvider),
                      SizedBox(height: 24.h),

                      // 4. Employee Leave Balances
                      _buildSectionHeader(
                        'Employee Leave Balances',
                        Icons.people_outline,
                      ),
                      SizedBox(height: 10.h),
                      _buildEmployeeLeaveSection(empProvider, dashProvider),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              );
            },
          ),
    );
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
                                      titleStyle: TextStyle(
                                        fontSize: 12.sp,
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
      return _buildEmptyCard('No departments found');
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
                              '${emp.department ?? 'N/A'} • ${emp.role ?? 'N/A'}',
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
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: ConstColors.primary,
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 3. Leave Configuration ---
  Widget _buildLeaveConfigSection(DashboardProvider dashProvider) {
    if (!_leaveConfigInitialized && !dashProvider.isLoadingLeaveConfig) {
      _plController.text = dashProvider.defaultPL.toString();
      _slController.text = dashProvider.defaultSL.toString();
      _clController.text = dashProvider.defaultCL.toString();
      _leaveConfigInitialized = true;
    }

    if (dashProvider.isLoadingLeaveConfig) {
      return _buildLeaveConfigShimmer();
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
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: dashProvider.isSavingLeaveConfig
                    ? null
                    : () => _saveLeaveConfig(dashProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConstColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: dashProvider.isSavingLeaveConfig
                    ? SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Save Defaults',
                        style: getTextTheme().labelLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
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

  Future<void> _saveLeaveConfig(DashboardProvider dashProvider) async {
    final pl = int.tryParse(_plController.text);
    final sl = int.tryParse(_slController.text);
    final cl = int.tryParse(_clController.text);

    if (pl == null || sl == null || cl == null || pl < 0 || sl < 0 || cl < 0) {
      ConstantSnackbar.showError(
        title: 'Please enter valid numbers for all leave types',
      );
      return;
    }

    final success = await dashProvider.saveLeaveDefaults(pl, sl, cl);
    if (success) {
      ConstantSnackbar.showSuccess(title: 'Leave defaults saved successfully');
    } else {
      ConstantSnackbar.showError(title: 'Failed to save leave defaults');
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

class _ChartItem {
  final String label;
  final int count;
  final Color color;

  _ChartItem(this.label, this.count, this.color);
}
