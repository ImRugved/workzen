import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/constant_snackbar.dart';
import '../../models/employee_model.dart';
import '../../models/past_request_entry.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/update_employee_leave_provider.dart';
import '../../widgets/app_dialog_card.dart';
import '../../widgets/past_request_form.dart';

/// The Update Leaves tab of Manage Employee Leaves. HR records leave an
/// employee already took (PL, SL, CL, comp off leave, work from home, comp off,
/// half days): pick the employee, add each record, check them in the list
/// below grouped by type, then press Update to save them all as approved
/// requests. The employee and the admin leave requests screen see them
/// straight away.
class UpdateLeavesTab extends StatefulWidget {
  const UpdateLeavesTab({super.key});

  @override
  State<UpdateLeavesTab> createState() => _UpdateLeavesTabState();
}

// Kept alive, so records added and not yet saved are still there after a look
// at the other tab
class _UpdateLeavesTabState extends State<UpdateLeavesTab>
    with AutomaticKeepAliveClientMixin {
  // The tab's state lives in this scoped provider
  final UpdateEmployeeLeaveProvider _page = UpdateEmployeeLeaveProvider();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final employees = context.read<EmployeeManagementProvider>();
      if (employees.allEmployees.isEmpty) employees.fetchAllEmployees();
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Color _kindColor(PastRequestKind kind) {
    switch (kind) {
      case PastRequestKind.pl:
        return ConstColors.primary;
      case PastRequestKind.sl:
        return ConstColors.successGreen;
      case PastRequestKind.cl:
        return ConstColors.inProgressOrange;
      case PastRequestKind.co:
      case PastRequestKind.compOff:
        return ConstColors.calendarCompOff;
      case PastRequestKind.wfh:
        return ConstColors.calendarWfh;
    }
  }

  // Changing the employee drops the records added so far, so ask first
  Future<void> _selectEmployee(EmployeeModel? employee) async {
    if (employee?.id == _page.employee?.id) return;

    if (_page.entries.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppDialogCard(
          icon: Icons.swap_horiz,
          iconColor: ConstColors.errorRed,
          title: 'Change employee?',
          message:
              'The ${_page.entries.length} record(s) added for '
              '${_page.employee?.name ?? 'this employee'} are not saved and '
              'will be removed.',
          confirmLabel: 'Change',
          confirmColor: ConstColors.errorRed,
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onConfirm: () => Navigator.of(dialogContext).pop(true),
        ),
      );
      if (confirmed != true) return;
    }
    _page.selectEmployee(employee);
  }

  Future<void> _update() async {
    final requests = context.read<RequestProvider>();
    final name = _page.employee?.name ?? 'the employee';
    final count = _page.entries.length;

    final dashboard = context.read<DashboardProvider>();
    final employees = context.read<EmployeeManagementProvider>();
    final onboarding = context.read<OnboardingProvider>();

    final result = await _page.save(requests);
    if (result.isSuccess) {
      // The Leave Balances tab shows the new numbers without a pull to refresh
      unawaited(dashboard.loadDashboardData(employees, onboarding));

      ConstantSnackbar.showSuccess(
        title: '$count record(s) updated for $name',
      );
      // Anything HR should know, for example a balance that could not change
      for (final note in result.notes) {
        ConstantSnackbar.show(
          title: note,
          backgroundColor: ConstColors.inProgressOrange,
        );
      }
    } else {
      ConstantSnackbar.showError(title: result.error!);
    }
  }

  // Edit one record in a bottom sheet
  void _edit(PastRequestEntry entry, DateTime firstDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
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
                  'Edit record',
                  style: getTextTheme().titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                SizedBox(height: 14.h),
                PastRequestForm(
                  initial: entry,
                  submitLabel: 'Save changes',
                  firstDate: firstDate,
                  onSubmit: (updated) {
                    _page.updateEntry(updated);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keeps the tab alive
    return ChangeNotifierProvider.value(
      value: _page,
      child: Column(
        children: [
          Expanded(
            child: Consumer<UpdateEmployeeLeaveProvider>(
              builder: (context, page, _) => ListView(
                padding: AppSpacing.screen,
                children: [
                  Text(
                    'Add the leave an employee already took. Saved records are '
                    'approved at once and show for the employee and in leave '
                    'requests. The leave left today does not change: the '
                    'days are added to used and to the total.',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _employeeDropdown(page),
                  if (page.employee != null) ...[
                    SizedBox(height: 16.h),
                    _addCard(page),
                    SizedBox(height: 16.h),
                    ..._sections(page),
                    SizedBox(height: 16.h),
                  ],
                ],
              ),
            ),
          ),
          // The Update button sits at the bottom once there is something to
          // save
          Consumer<UpdateEmployeeLeaveProvider>(
            builder: (context, page, _) {
              if (page.entries.isEmpty) return const SizedBox.shrink();
              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                  child: SizedBox(
                    width: double.infinity,
                    child: ConstantButton(
                      text: 'Update (${page.entries.length})',
                      isLoading: page.isSaving,
                      backgroundColor: ConstColors.primary,
                      onPressed: page.isSaving ? null : _update,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Onboarded employees in a dropdown; the chosen one shows as its name
  Widget _employeeDropdown(UpdateEmployeeLeaveProvider page) {
    return Consumer<EmployeeManagementProvider>(
      builder: (context, employees, _) {
        final list = employees.allEmployees.where((e) => e.isOnboarded).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return ConstantDropdown<String>(
          label: 'Employee',
          hint: 'Select employee',
          value: page.employee?.id,
          items: [for (final e in list) e.id],
          itemLabel: (id) {
            final e = list.firstWhere((e) => e.id == id);
            return e.employeeId == null ? e.name : '${e.name} (${e.employeeId})';
          },
          onChanged: (id) {
            if (id == null) return;
            _selectEmployee(list.firstWhere((e) => e.id == id));
          },
        );
      },
    );
  }

  // The date pickers start in 2000 and run to 2100: no date is refused, so old
  // leave from earlier years can be added
  DateTime _firstDate(UpdateEmployeeLeaveProvider page) => DateTime(2000);

  Widget _addCard(UpdateEmployeeLeaveProvider page) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a record for ${page.employee!.name}',
              style: getTextTheme().titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
            ),
            SizedBox(height: 12.h),
            // A new key after each add, so the form starts empty again
            PastRequestForm(
              key: ValueKey('${page.employee!.id}-${page.formVersion}'),
              submitLabel: 'Add',
              firstDate: _firstDate(page),
              onSubmit: page.addEntry,
            ),
          ],
        ),
      ),
    );
  }

  // The added records, one section per type, each card with edit and remove
  List<Widget> _sections(UpdateEmployeeLeaveProvider page) {
    final sections = page.sections;
    if (sections.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Text(
              'No records added yet',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      for (final section in sections.entries) ...[
        Padding(
          padding: EdgeInsets.only(top: 6.h, bottom: 2.h),
          child: Text(
            '${section.key.sectionTitle} (${section.value.length})',
            style: getTextTheme().labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: ConstColors.textColor,
            ),
          ),
        ),
        for (final entry in section.value) _entryCard(page, entry),
      ],
    ];
  }

  Widget _entryCard(UpdateEmployeeLeaveProvider page, PastRequestEntry entry) {
    final color = _kindColor(entry.kind);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: NeuCard(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: Row(
            children: [
              Container(
                width: 38.r,
                height: 38.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
                child: Text(
                  entry.kind.code,
                  style: getTextTheme().labelSmall?.copyWith(
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
                      entry.kind.sectionTitle,
                      style: getTextTheme().bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.textColor,
                      ),
                    ),
                    Text(
                      entry.dateText,
                      style: getTextTheme().bodySmall?.copyWith(
                        color: ConstColors.textColor,
                      ),
                    ),
                    Text(
                      entry.daysText,
                      style: getTextTheme().labelSmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20.r,
                  color: ConstColors.primaryDeep,
                ),
                tooltip: 'Edit',
                onPressed: () => _edit(entry, _firstDate(page)),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20.r,
                  color: ConstColors.errorRed,
                ),
                tooltip: 'Remove',
                onPressed: () => page.removeEntry(entry.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
