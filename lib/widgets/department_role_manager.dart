import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import '../models/department_model.dart';
import '../providers/employee_management_provider.dart';
import '../providers/toggle_provider.dart';
import 'app_dialog_card.dart';

/// Dialogs and sheets for creating and managing departments and roles.
/// Used from the admin dashboard page.
class DepartmentRoleManager {
  DepartmentRoleManager._();

  // --- Add department(s) ---
  static Future<void> showAddDepartmentDialog(
    BuildContext context,
    EmployeeManagementProvider provider,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddNamesDialog(
        title: 'Add Department',
        icon: Icons.business,
        label: 'Department name(s)',
        helper: 'Separate multiple names with commas.',
        emptyError: 'Enter department name(s)',
        successMessage: 'Department(s) added',
        failureMessage: 'Failed to add department(s)',
        onSave: provider.addDepartments,
      ),
    );
  }

  // --- Add role(s) to a department ---
  static Future<void> showAddRoleDialog(
    BuildContext context,
    EmployeeManagementProvider provider,
    DepartmentModel dept,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddNamesDialog(
        title: 'Add Role to ${dept.name}',
        icon: Icons.badge,
        label: 'Role name(s)',
        helper: 'Separate multiple names with commas.',
        emptyError: 'Enter role name(s)',
        successMessage: 'Role(s) added',
        failureMessage: 'Failed to add role(s)',
        onSave: (names) => provider.addRolesToDepartment(dept.id, names),
      ),
    );
  }

  // --- Rename dialog (department or role) ---
  static Future<void> showEditDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
  }) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(title: title, initialValue: initialValue),
    );
    if (newName != null) {
      await onSave(newName);
    }
  }

  static Future<bool> _confirmDelete(
    BuildContext context,
    String title,
    String message,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialogCard(
        icon: Icons.delete_outline,
        iconColor: ConstColors.errorRed,
        title: title,
        message: message,
        confirmLabel: 'Delete',
        confirmColor: ConstColors.errorRed,
        onCancel: () => Navigator.pop(c, false),
        onConfirm: () => Navigator.pop(c, true),
      ),
    );
    return confirm == true;
  }

  // --- Manage a department: rename, delete, add / rename / delete roles ---
  static void showManageSheet(
    BuildContext context,
    EmployeeManagementProvider provider,
    DepartmentModel dept,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ManageSheet(
        parentContext: context,
        sheetContext: sheetContext,
        provider: provider,
        dept: dept,
      ),
    );
  }

  static void _renameDepartment(
    BuildContext context,
    EmployeeManagementProvider provider,
    DepartmentModel dept,
  ) {
    showEditDialog(
      context: context,
      title: 'Edit Department',
      initialValue: dept.name,
      onSave: (newName) async {
        final success = await provider.updateDepartmentName(dept.id, newName);
        if (success) {
          ConstantSnackbar.showSuccess(title: 'Department updated');
        } else {
          ConstantSnackbar.showError(title: 'Failed to update');
        }
      },
    );
  }

  static Future<void> _deleteDepartment(
    BuildContext context,
    EmployeeManagementProvider provider,
    DepartmentModel dept,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      'Delete Department?',
      'Delete "${dept.name}" and all its roles?',
    );
    if (!confirmed) return;
    final success = await provider.deleteDepartment(dept.id);
    if (success) {
      ConstantSnackbar.showSuccess(title: 'Department deleted');
    } else {
      ConstantSnackbar.showError(title: 'Failed to delete');
    }
  }

  static void _renameRole(
    BuildContext context,
    EmployeeManagementProvider provider,
    DepartmentModel dept,
    String role,
  ) {
    showEditDialog(
      context: context,
      title: 'Edit Role',
      initialValue: role,
      onSave: (newName) async {
        final success = await provider.updateRoleName(dept.id, role, newName);
        if (success) {
          ConstantSnackbar.showSuccess(title: 'Role updated');
        } else {
          ConstantSnackbar.showError(title: 'Failed to update');
        }
      },
    );
  }

  static Future<void> _deleteRole(
    BuildContext context,
    EmployeeManagementProvider provider,
    DepartmentModel dept,
    String role,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      'Delete Role?',
      'Delete "$role"?',
    );
    if (!confirmed) return;
    final success = await provider.removeRoleFromDepartment(dept.id, role);
    if (success) {
      ConstantSnackbar.showSuccess(title: 'Role deleted');
    } else {
      ConstantSnackbar.showError(title: 'Failed to delete');
    }
  }
}

/// Bottom sheet to manage one department: three actions on top, then its
/// roles, each with rename and delete.
class _ManageSheet extends StatelessWidget {
  // The screen's context opens the follow-up dialogs once the sheet is closed
  final BuildContext parentContext;
  final BuildContext sheetContext;
  final EmployeeManagementProvider provider;
  final DepartmentModel dept;

  const _ManageSheet({
    required this.parentContext,
    required this.sheetContext,
    required this.provider,
    required this.dept,
  });

  void _closeThen(VoidCallback action) {
    Navigator.pop(sheetContext);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      // InkWell paints its ink on the nearest Material
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
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
                _header(),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: _action(
                        Icons.edit_outlined,
                        'Rename',
                        ConstColors.primaryDeep,
                        () => _closeThen(
                          () => DepartmentRoleManager._renameDepartment(
                            parentContext,
                            provider,
                            dept,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _action(
                        Icons.add_circle_outline,
                        'Add Role',
                        ConstColors.primaryDeep,
                        () => _closeThen(
                          () => DepartmentRoleManager.showAddRoleDialog(
                            parentContext,
                            provider,
                            dept,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _action(
                        Icons.delete_outline,
                        'Delete',
                        ConstColors.errorRed,
                        () => _closeThen(
                          () => DepartmentRoleManager._deleteDepartment(
                            parentContext,
                            provider,
                            dept,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  'Roles (${dept.roles.length})',
                  style: getTextTheme().titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                SizedBox(height: 8.h),
                if (dept.roles.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Center(
                      child: Text(
                        'No roles yet. Tap Add Role to create one.',
                        style: getTextTheme().bodySmall?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                    ),
                  )
                else
                  for (final role in dept.roles) _roleRow(role),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 40.r,
          height: 40.r,
          decoration: BoxDecoration(
            color: ConstColors.lightShade,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.business,
            size: 22.r,
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
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              Text(
                'Manage department',
                style: getTextTheme().labelSmall?.copyWith(
                  color: ConstColors.textColorLight,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, size: 22.r, color: ConstColors.textColor),
          onPressed: () => Navigator.pop(sheetContext),
        ),
      ],
    );
  }

  // A tinted tile with an icon above its label
  Widget _action(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Ink(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22.r, color: color),
            SizedBox(height: 4.h),
            Text(
              label,
              style: getTextTheme().labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleRow(String role) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.only(left: 12.w, right: 4.w),
      decoration: BoxDecoration(
        color: ConstColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: ConstColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.badge_outlined, size: 18.r, color: ConstColors.primaryDeep),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              role,
              overflow: TextOverflow.ellipsis,
              style: getTextTheme().bodyMedium?.copyWith(
                color: ConstColors.textColor,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 20.r,
              color: ConstColors.primaryDeep,
            ),
            tooltip: 'Rename',
            onPressed: () => _closeThen(
              () => DepartmentRoleManager._renameRole(
                parentContext,
                provider,
                dept,
                role,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20.r,
              color: ConstColors.errorRed,
            ),
            tooltip: 'Delete',
            onPressed: () => _closeThen(
              () => DepartmentRoleManager._deleteRole(
                parentContext,
                provider,
                dept,
                role,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog that takes comma separated names, shows a spinner while saving, and
// owns/disposes its own controller.
class _AddNamesDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final String label;
  final String helper;
  final String emptyError;
  final String successMessage;
  final String failureMessage;
  final Future<bool> Function(String names) onSave;

  const _AddNamesDialog({
    required this.title,
    required this.icon,
    required this.label,
    required this.helper,
    required this.emptyError,
    required this.successMessage,
    required this.failureMessage,
    required this.onSave,
  });

  @override
  State<_AddNamesDialog> createState() => _AddNamesDialogState();
}

class _AddNamesDialogState extends State<_AddNamesDialog> {
  final _controller = TextEditingController();
  // Saving flag, scoped to this dialog
  final ToggleProvider _saving = ToggleProvider();

  @override
  void dispose() {
    _controller.dispose();
    _saving.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final names = _controller.text.trim();
    if (names.isEmpty) {
      ConstantSnackbar.showError(title: widget.emptyError);
      return;
    }

    _saving.set(true);
    final success = await widget.onSave(names);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ConstantSnackbar.showSuccess(title: widget.successMessage);
    } else {
      _saving.set(false);
      ConstantSnackbar.showError(title: widget.failureMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _saving,
      child: Consumer<ToggleProvider>(
        builder: (context, saving, _) => _buildDialog(saving.value),
      ),
    );
  }

  Widget _buildDialog(bool isSaving) {
    return AppDialogCard(
      icon: widget.icon,
      title: widget.title,
      confirmLabel: 'Add',
      isBusy: isSaving,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !isSaving,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: Icon(widget.icon, size: 20.r),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.helper,
            style: getTextTheme().bodySmall?.copyWith(
              color: ConstColors.textColorLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const _EditNameDialog({required this.title, required this.initialValue});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
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
      title: widget.title,
      confirmLabel: 'Save',
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        final value = _controller.text.trim();
        if (value.isNotEmpty) Navigator.of(context).pop(value);
      },
      child: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
    );
  }
}
