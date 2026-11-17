import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_theme.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/constant_snackbar.dart';
import '../../models/comp_off_balance_model.dart';
import '../../models/employee_model.dart';
import '../../models/leave_balance_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../constants/permissions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/value_provider.dart';
import '../../widgets/app_dialog_card.dart';
import '../../widgets/leave_records_sheet.dart';

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

  // An admin does everything. A sub admin edits the days with the "approve leave
  // requests" or the "onboarding" permission (what the leave documents allow);
  // deleting records and resetting needs "approve leave requests".
  bool _canEdit(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return auth.can(Permissions.leaveRequests) ||
        auth.can(Permissions.onboarding);
  }

  bool _canManageRecords(BuildContext context) =>
      context.read<AuthProvider>().can(Permissions.leaveRequests);

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
            // The year whose leave is shown and edited
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
              child: Selector<DashboardProvider, int>(
                selector: (_, dash) => dash.selectedYear,
                builder: (context, year, _) {
                  final thisYear = DateTime.now().year;
                  return ConstantDropdown<int>(
                    label: 'Year',
                    isDense: true,
                    value: year,
                    items: [for (var y = thisYear; y > thisYear - 5; y--) y],
                    itemLabel: (y) => '$y',
                    onChanged: (y) {
                      if (y == null) return;
                      context.read<DashboardProvider>().setYear(
                        y,
                        context.read<EmployeeManagementProvider>(),
                        context.read<OnboardingProvider>(),
                      );
                    },
                  );
                },
              ),
            ),
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
              _unpaidRow(context, leave.ulUsed, emp.id, dashProvider),
              SizedBox(height: 10.h),
              // Comp off credit: earned, used and what is left
              _compOffRow(
                context,
                emp.id,
                dashProvider.compOff[emp.id] ?? const CompOffBalanceModel(),
                dashProvider,
              ),
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
              if (_canManageRecords(context)) ...[
              SizedBox(height: 10.h),
              // The leave records of the employee, month by month, to delete
              // one added by mistake
              Row(
                children: [
                  Expanded(
                    child: ConstantButton(
                      text: 'Leave records',
                      isOutlined: true,
                      icon: Icon(Icons.history, size: 18.r),
                      height: 40.h,
                      horizontalInnerPadding: 6.w,
                      onPressed: () => LeaveRecordsSheet.show(
                        context,
                        employeeId: emp.id,
                        employeeName: emp.name,
                        onChanged: () => dashProvider.loadDashboardData(
                          context.read<EmployeeManagementProvider>(),
                          context.read<OnboardingProvider>(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ConstantButton(
                      text: 'Reset to 0',
                      isOutlined: true,
                      backgroundColor: ConstColors.errorRed,
                      icon: Icon(Icons.restart_alt, size: 18.r),
                      height: 40.h,
                      horizontalInnerPadding: 6.w,
                      onPressed: () => _resetLeaveData(
                        context,
                        emp.id,
                        emp.name,
                        dashProvider,
                      ),
                    ),
                  ),
                ],
              ),
              ],
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
                if (_canEdit(context))
                InkWell(
                  onTap: () => _editAllocation(
                    context,
                    employeeId,
                    leaveType,
                    total.toInt(),
                    used,
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
  // no progress bar; the pencil corrects the days taken. It is not part of the
  // summary below.
  Widget _unpaidRow(
    BuildContext context,
    num taken,
    String employeeId,
    DashboardProvider dashProvider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8.r,
              height: 8.r,
              decoration: const BoxDecoration(
                color: ConstColors.calendarUnpaidLeave,
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
        Row(
          children: [
            Text(
              '${leaveCount(taken)} ${taken == 1 ? 'day' : 'days'} taken',
              style: getTextTheme().bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
            ),
            SizedBox(width: 4.w),
            if (_canEdit(context))
            InkWell(
              onTap: () =>
                  _editAllocation(context, employeeId, 'ul', 0, taken, dashProvider),
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
    );
  }

  // Comp off credit: days left, with the days earned and used; the pencil
  // corrects the earned and used days. Not part of the summary below.
  Widget _compOffRow(
    BuildContext context,
    String employeeId,
    CompOffBalanceModel comp,
    DashboardProvider dashProvider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8.r,
              height: 8.r,
              decoration: const BoxDecoration(
                color: ConstColors.calendarCompOff,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              'Comp Off (CO)',
              style: getTextTheme().bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: ConstColors.textColor,
              ),
            ),
          ],
        ),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  '${leaveCount(comp.balance)} left '
                  '(${leaveCount(comp.earned)} earned, '
                  '${leaveCount(comp.used)} used)',
                  style: getTextTheme().bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4.w),
              if (_canEdit(context))
              InkWell(
                onTap: () => _editAllocation(
                  context,
                  employeeId,
                  'co',
                  comp.earned,
                  comp.used,
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

  // Clear all the leave data of an employee after a confirmation: requests
  // deleted, used and unpaid days at 0, balances back to the allocation
  Future<void> _resetLeaveData(
    BuildContext context,
    String employeeId,
    String employeeName,
    DashboardProvider dashProvider,
  ) async {
    final requests = context.read<RequestProvider>();
    final empProvider = context.read<EmployeeManagementProvider>();
    final onboardingProvider = context.read<OnboardingProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialogCard(
        icon: Icons.restart_alt,
        iconColor: ConstColors.errorRed,
        title: 'Reset leave data?',
        message:
            'All leave and comp off records of $employeeName are deleted, used '
            'and unpaid days go to 0 and the comp off credit goes to 0. Leave '
            'balances go back to the allocated days. The attendance history '
            'and exports are updated. This cannot be undone.',
        confirmLabel: 'Reset',
        confirmColor: ConstColors.errorRed,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirm != true) return;

    final done = await requests.resetLeaveData(employeeId);
    if (done) {
      ConstantSnackbar.showSuccess(title: 'Leave data of $employeeName reset');
      await dashProvider.loadDashboardData(empProvider, onboardingProvider);
    } else {
      ConstantSnackbar.showError(title: 'Could not reset the leave data');
    }
  }

  // Correct the days allocated and the days used of one leave type (only the
  // days taken for unpaid leave). The balance and totals follow.
  Future<void> _editAllocation(
    BuildContext context,
    String employeeId,
    String leaveType,
    num currentTotal,
    num currentUsed,
    DashboardProvider dashProvider,
  ) async {
    final label = switch (leaveType) {
      'pl' => 'Privilege Leave',
      'sl' => 'Sick Leave',
      'cl' => 'Casual Leave',
      'co' => 'Comp Off',
      _ => 'Unpaid Leave',
    };
    final empProvider = context.read<EmployeeManagementProvider>();
    final onboardingProvider = context.read<OnboardingProvider>();

    // What the saved leave records add up to, shown in the dialog: History, the
    // calendar and the exports follow the records, not this number
    final recorded = await dashProvider.recordedLeaveDays(
      employeeId,
      leaveType,
      year: leaveType == 'co' ? null : dashProvider.selectedYear,
    );
    if (!context.mounted) return;

    final result = await showDialog<({num allocated, num used})>(
      context: context,
      builder: (_) => _AllocationDialog(
        label: label,
        allocated: currentTotal,
        used: currentUsed,
        hasAllocation: leaveType != 'ul',
        isCompOff: leaveType == 'co',
        recordedDays: recorded,
      ),
    );
    if (result == null) return;

    // Comp off is kept apart from the yearly leave documents
    final saved = leaveType == 'co'
        ? await dashProvider.updateCompOff(
            employeeId,
            earned: result.allocated,
            used: result.used,
            empProvider: empProvider,
            onboardingProvider: onboardingProvider,
          )
        : await dashProvider.updateLeaveAllocation(
            employeeId,
            leaveType,
            allocated: result.allocated.toInt(),
            used: result.used,
            empProvider: empProvider,
            onboardingProvider: onboardingProvider,
          );
    if (saved) {
      ConstantSnackbar.showSuccess(title: '$label updated');
    } else {
      ConstantSnackbar.showError(title: 'Could not update $label');
    }
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
  final num allocated;
  final num used;

  /// False for unpaid leave: only the days taken can be changed.
  final bool hasAllocation;

  /// Comp off: the first field is the days earned (not allocated) and half
  /// days are allowed in it.
  final bool isCompOff;

  /// Days the employee's saved leave records add up to, or null when unknown.
  final num? recordedDays;

  const _AllocationDialog({
    required this.label,
    required this.allocated,
    required this.used,
    required this.hasAllocation,
    this.isCompOff = false,
    this.recordedDays,
  });

  @override
  State<_AllocationDialog> createState() => _AllocationDialogState();
}

class _AllocationDialogState extends State<_AllocationDialog> {
  late final TextEditingController _allocatedController =
      TextEditingController(text: leaveCount(widget.allocated));
  late final TextEditingController _usedController = TextEditingController(
    text: leaveCount(widget.used),
  );

  @override
  void dispose() {
    _allocatedController.dispose();
    _usedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogCard(
      icon: Icons.edit_outlined,
      title: 'Edit ${widget.label}',
      message: widget.hasAllocation
          ? 'Correct the days ${widget.isCompOff ? 'earned' : 'allocated'} and '
                'used. The balance is worked out from them.'
          : 'Correct the days taken',
      confirmLabel: 'Save',
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        final text = _allocatedController.text.trim();
        // Leave is allocated in whole days; comp off can be earned in halves
        final num? allocated = !widget.hasAllocation
            ? widget.allocated
            : widget.isCompOff
            ? num.tryParse(text)
            : int.tryParse(text);
        final used = num.tryParse(_usedController.text.trim());
        if (allocated == null || allocated < 0 || used == null || used < 0) {
          ConstantSnackbar.showError(title: 'Enter a valid number of days');
          return;
        }
        // Half days are the smallest step
        if (used * 2 != (used * 2).roundToDouble() ||
            allocated * 2 != (allocated * 2).roundToDouble()) {
          ConstantSnackbar.showError(title: 'Days go in steps of 0.5');
          return;
        }
        if (widget.hasAllocation && used > allocated) {
          ConstantSnackbar.showError(
            title:
                'Used days can not be more than the days '
                '${widget.isCompOff ? 'earned' : 'allocated'}',
          );
          return;
        }
        Navigator.of(context).pop((allocated: allocated, used: used));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.hasAllocation) ...[
            TextField(
              controller: _allocatedController,
              keyboardType: widget.isCompOff
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.isCompOff ? 'Earned days' : 'Allocated days',
              ),
            ),
            SizedBox(height: 12.h),
          ],
          TextField(
            controller: _usedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.hasAllocation ? 'Used days' : 'Days taken',
            ),
          ),
          // History, the calendar and the exports follow the saved leave
          // records. Warn when this number would no longer match them.
          if (widget.recordedDays != null)
            ListenableBuilder(
              listenable: _usedController,
              builder: (context, _) {
                final recorded = widget.recordedDays!;
                final entered = num.tryParse(_usedController.text.trim());
                final differs = entered != null && entered != recorded;
                return Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Text(
                    differs
                        ? 'Saved leave records show ${leaveCount(recorded)} '
                              '${recorded == 1 ? 'day' : 'days'}. History, '
                              'calendar and exports follow the records, so they '
                              'will not match this number. To change them, '
                              'delete or add a record in Leave records.'
                        : 'Saved leave records show ${leaveCount(recorded)} '
                              '${recorded == 1 ? 'day' : 'days'}.',
                    style: getTextTheme().labelSmall?.copyWith(
                      color: differs
                          ? ConstColors.inProgressOrange
                          : ConstColors.textColorLight,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
