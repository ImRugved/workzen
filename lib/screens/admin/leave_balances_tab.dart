import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_theme.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_snackbar.dart';
import '../../models/employee_model.dart';
import '../../models/leave_balance_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/value_provider.dart';
import '../../widgets/app_dialog_card.dart';

/// The Leave Balances tab of Manage Employee Leaves: one card per onboarded
/// employee with the leave left; tap a card to see PL, SL and CL with their
/// progress, and the pencil next to a type to change the days allocated.
class LeaveBalancesTab extends StatefulWidget {
  const LeaveBalancesTab({super.key});

  @override
  State<LeaveBalancesTab> createState() => _LeaveBalancesTabState();
}

class _LeaveBalancesTabState extends State<LeaveBalancesTab> {
  // The search box and its text (lowercase, trimmed), owned here and read by
  // the list through a scoped provider
  final TextEditingController _searchController = TextEditingController();
  final ValueProvider<String> _query = ValueProvider<String>('');

  @override
  void dispose() {
    _searchController.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _reload(BuildContext context) {
    return context.read<DashboardProvider>().loadDashboardData(
      context.read<EmployeeManagementProvider>(),
      context.read<OnboardingProvider>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _query,
      child: SafeArea(
        child: Column(
          children: [
            // Search by employee name
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (text) => _query.value = text.trim().toLowerCase(),
                decoration: InputDecoration(
                  hintText: 'Search employee by name',
                  prefixIcon: Icon(Icons.search, size: 20.r),
                  isDense: true,
                  suffixIcon: Selector<ValueProvider<String>, bool>(
                    selector: (_, q) => q.value.isNotEmpty,
                    builder: (context, hasText, _) => hasText
                        ? IconButton(
                            icon: Icon(Icons.close, size: 18.r),
                            onPressed: () {
                              _searchController.clear();
                              _query.value = '';
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _reload(context),
                child:
                    Consumer3<
                      EmployeeManagementProvider,
                      DashboardProvider,
                      ValueProvider<String>
                    >(
                      builder: (context, empProvider, dashProvider, query, _) {
                        final onboarded = empProvider.allEmployees
                            .where((e) => e.isOnboarded)
                            .toList();
                        final employees = query.value.isEmpty
                            ? onboarded
                            : onboarded
                                  .where(
                                    (e) => e.name.toLowerCase().contains(
                                      query.value,
                                    ),
                                  )
                                  .toList();

                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.screen,
                          children: [
                            if (dashProvider.isLoadingEmployeeLeaves)
                              _shimmer()
                            else if (onboarded.isEmpty)
                              _emptyCard('No onboarded employees')
                            else if (employees.isEmpty)
                              _emptyCard('No employee matches "${query.value}"')
                            else
                              for (final emp in employees)
                                _employeeCard(context, emp, dashProvider),
                          ],
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeeCard(
    BuildContext context,
    EmployeeModel emp,
    DashboardProvider dashProvider,
  ) {
    final leave = dashProvider.employeeLeaves[emp.id];
    final isExpanded = dashProvider.expandedEmployeeId == emp.id;

    return NeuCard(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      radius: NeuStyle.radiusSmall,
      borderColor: isExpanded
          ? ConstColors.primary.withValues(alpha: 0.6)
          : null,
      onTap: () => dashProvider.toggleExpandedEmployee(emp.id),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: ConstColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                    style: getTextTheme().titleSmall?.copyWith(
                      color: ConstColors.primaryDeep,
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
                          color: ConstColors.textColor,
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
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color:
                        (leave != null
                                ? ConstColors.successGreen
                                : ConstColors.warningAmber)
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    leave != null
                        ? '${leaveCount(leave.totalBalance)} left'
                        : 'No data',
                    style: getTextTheme().labelSmall?.copyWith(
                      color: ConstColors.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
              Divider(height: 1, color: ConstColors.borderColor),
              SizedBox(height: 12.h),
              // PL shows only for an employee who has it: switched on in the
              // settings and not 0 days
              if (leave.plTotal > 0) ...[
                _balanceRow(
                  context,
                  'Privilege Leave (PL)',
                  leave.plTotal,
                  leave.plUsed,
                  ConstColors.primary,
                  emp.id,
                  'pl',
                  dashProvider,
                ),
                SizedBox(height: 10.h),
              ],
              _balanceRow(
                context,
                'Sick Leave (SL)',
                leave.slTotal,
                leave.slUsed,
                ConstColors.successGreen,
                emp.id,
                'sl',
                dashProvider,
              ),
              SizedBox(height: 10.h),
              _balanceRow(
                context,
                'Casual Leave (CL)',
                leave.clTotal,
                leave.clUsed,
                ConstColors.inProgressOrange,
                emp.id,
                'cl',
                dashProvider,
              ),
              SizedBox(height: 10.h),
              // Unpaid leave: no days allocated, so it shows the days taken
              _unpaidRow(leave.ulUsed),
              SizedBox(height: 12.h),
              // Summary bar
              Container(
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: ConstColors.lightShade,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryItem('Allocated', leave.totalAllocated),
                    _summaryItem('Used', leave.totalUsed),
                    _summaryItem('Balance', leave.totalBalance),
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
    );
  }

  // One leave type: used / allocated with a progress bar and an edit pencil
  Widget _balanceRow(
    BuildContext context,
    String label,
    num total,
    num used,
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
                  width: 8.r,
                  height: 8.r,
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
                    color: ConstColors.textColor,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '${leaveCount(used)} / ${leaveCount(total)}',
                  style: getTextTheme().bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                SizedBox(width: 4.w),
                InkWell(
                  onTap: () => _editAllocation(
                    context,
                    employeeId,
                    leaveType,
                    total.toInt(),
                    dashProvider,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                  child: Padding(
                    padding: EdgeInsets.all(6.r),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18.r,
                      color: ConstColors.primaryDeep,
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
            value: progress.clamp(0.0, 1.0).toDouble(),
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6.h,
          ),
        ),
      ],
    );
  }

  // Unpaid Leave (UL): days taken so far this year. There is no allocation, so
  // no progress bar and no pencil; it is not part of the summary below.
  Widget _unpaidRow(num taken) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8.r,
              height: 8.r,
              decoration: const BoxDecoration(
                color: ConstColors.errorRed,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              'Unpaid Leave (UL)',
              style: getTextTheme().bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: ConstColors.textColor,
              ),
            ),
          ],
        ),
        Text(
          '${leaveCount(taken)} ${taken == 1 ? 'day' : 'days'} taken',
          style: getTextTheme().bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: ConstColors.textColor,
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(String label, num value) {
    return Column(
      children: [
        Text(
          leaveCount(value),
          style: getTextTheme().titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: ConstColors.textColor,
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

  // Change the days allocated of one leave type
  Future<void> _editAllocation(
    BuildContext context,
    String employeeId,
    String leaveType,
    int currentTotal,
    DashboardProvider dashProvider,
  ) async {
    final label = leaveType == 'pl'
        ? 'Privilege Leave'
        : leaveType == 'sl'
        ? 'Sick Leave'
        : 'Casual Leave';
    final empProvider = context.read<EmployeeManagementProvider>();
    final onboardingProvider = context.read<OnboardingProvider>();

    final newTotal = await showDialog<int>(
      context: context,
      builder: (_) => _AllocationDialog(label: label, current: currentTotal),
    );
    if (newTotal == null) return;

    await dashProvider.updateLeaveAllocation(
      employeeId,
      leaveType,
      newTotal,
      empProvider,
      onboardingProvider,
    );
  }

  Widget _shimmer() {
    Widget box({double? width, required double height, double radius = 8}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: ConstColors.cardBackground,
            borderRadius: BorderRadius.circular(radius.r),
          ),
        );

    return Shimmer.fromColors(
      baseColor: ConstColors.borderColor,
      highlightColor: ConstColors.cardBackground,
      child: Column(
        children: List.generate(
          4,
          (_) => NeuCard(
            margin: EdgeInsets.symmetric(vertical: 8.h),
            radius: NeuStyle.radiusSmall,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: ConstColors.cardBackground,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        box(width: 120.w, height: 12.h),
                        SizedBox(height: 6.h),
                        box(width: 180.w, height: 10.h),
                      ],
                    ),
                  ),
                  box(width: 50.w, height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return NeuCard(
      radius: NeuStyle.radiusSmall,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
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

// Asks for the new number of days; owns its text controller
class _AllocationDialog extends StatefulWidget {
  final String label;
  final int current;

  const _AllocationDialog({required this.label, required this.current});

  @override
  State<_AllocationDialog> createState() => _AllocationDialogState();
}

class _AllocationDialogState extends State<_AllocationDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogCard(
      icon: Icons.edit_outlined,
      title: 'Edit ${widget.label}',
      message: 'Set the total days allocated',
      confirmLabel: 'Save',
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        final value = int.tryParse(_controller.text.trim());
        if (value == null || value < 0) {
          ConstantSnackbar.showError(title: 'Enter a valid number of days');
          return;
        }
        Navigator.of(context).pop(value);
      },
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Total days'),
      ),
    );
  }
}
