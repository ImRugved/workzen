import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import '../models/department_model.dart';
import '../providers/employee_management_provider.dart';

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
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ConstColors.errorRed,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        // ListTile paints ink on the nearest Material, so keep one above it
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: ConstColors.primary),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          dept.name,
                          style: getTextTheme().titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.edit, color: ConstColors.primary),
                    title: const Text('Edit Department Name'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(ctx);
                      showEditDialog(
                        context: context,
                        title: 'Edit Department',
                        initialValue: dept.name,
                        onSave: (newName) async {
                          final success = await provider.updateDepartmentName(
                            dept.id,
                            newName,
                          );
                          if (success) {
                            ConstantSnackbar.showSuccess(
                              title: 'Department updated',
                            );
                          } else {
                            ConstantSnackbar.showError(
                              title: 'Failed to update',
                            );
                          }
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.add_circle_outline,
                        color: ConstColors.primary),
                    title: const Text('Add Role(s)'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(ctx);
                      showAddRoleDialog(context, provider, dept);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete, color: ConstColors.errorRed),
                    title: const Text('Delete Department'),
                    subtitle: Text(
                      'This will delete all roles',
                      style: getTextTheme().bodySmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirmed = await _confirmDelete(
                        context,
                        'Delete Department?',
                        'Delete "${dept.name}" and all its roles?',
                      );
                      if (!confirmed) return;
                      final success = await provider.deleteDepartment(dept.id);
                      if (success) {
                        ConstantSnackbar.showSuccess(
                          title: 'Department deleted',
                        );
                      } else {
                        ConstantSnackbar.showError(title: 'Failed to delete');
                      }
                    },
                  ),
                  if (dept.roles.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    const Divider(),
                    Text(
                      'Roles',
                      style: getTextTheme().titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ...dept.roles.map(
                      (role) => ListTile(
                        leading: Icon(Icons.badge_outlined, size: 20.r),
                        title: Text(role),
                        contentPadding: EdgeInsets.zero,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 20.r,
                                color: ConstColors.primary,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                showEditDialog(
                                  context: context,
                                  title: 'Edit Role',
                                  initialValue: role,
                                  onSave: (newName) async {
                                    final success =
                                        await provider.updateRoleName(
                                          dept.id,
                                          role,
                                          newName,
                                        );
                                    if (success) {
                                      ConstantSnackbar.showSuccess(
                                        title: 'Role updated',
                                      );
                                    } else {
                                      ConstantSnackbar.showError(
                                        title: 'Failed to update',
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                size: 20.r,
                                color: ConstColors.errorRed,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final confirmed = await _confirmDelete(
                                  context,
                                  'Delete Role?',
                                  'Delete "$role"?',
                                );
                                if (!confirmed) return;
                                final success = await provider
                                    .removeRoleFromDepartment(dept.id, role);
                                if (success) {
                                  ConstantSnackbar.showSuccess(
                                    title: 'Role deleted',
                                  );
                                } else {
                                  ConstantSnackbar.showError(
                                    title: 'Failed to delete',
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),
        ),
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
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final names = _controller.text.trim();
    if (names.isEmpty) {
      ConstantSnackbar.showError(title: widget.emptyError);
      return;
    }

    setState(() => _isSaving = true);
    final success = await widget.onSave(names);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ConstantSnackbar.showSuccess(title: widget.successMessage);
    } else {
      setState(() => _isSaving = false);
      ConstantSnackbar.showError(title: widget.failureMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: Icon(widget.icon, size: 20.r),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
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
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: ConstColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? SizedBox(
                  width: 18.r,
                  height: 18.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add'),
        ),
      ],
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
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) Navigator.of(context).pop(value);
          },
          style: ElevatedButton.styleFrom(backgroundColor: ConstColors.primary),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
