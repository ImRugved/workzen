import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import '../../constants/constant_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../constants/constant_textfield.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../models/department_model.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({Key? key}) : super(key: key);

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _newDeptController = TextEditingController();
  final _newRoleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EmployeeManagementProvider>(
        context,
        listen: false,
      ).resetAddEmployeeForm();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _newDeptController.dispose();
    _newRoleController.dispose();
    super.dispose();
  }

  // Show list of all departments for management
  void _showManageDepartmentsListDialog(
    BuildContext context,
    EmployeeManagementProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, color: ConstColors.primary),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Manage Departments & Roles',
                        style: getTextTheme().titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Divider(),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: provider.departments.length,
                    separatorBuilder: (_, __) => Divider(height: 1),
                    itemBuilder: (_, index) {
                      final dept = provider.departments[index];
                      return ListTile(
                        leading: Icon(
                          Icons.business,
                          color: ConstColors.primary,
                        ),
                        title: Text(
                          dept.name,
                          style: getTextTheme().bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          dept.roles.isEmpty
                              ? 'No roles Availble'
                              : '${dept.roles.length} role(s)',
                          style: getTextTheme().bodySmall?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: ConstColors.primary,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showManageDepartmentDialog(context, provider, dept);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show manage department dialog (edit/delete department or roles)
  void _showManageDepartmentDialog(
    BuildContext context,
    EmployeeManagementProvider provider,
    DepartmentModel dept,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Divider(),

                // Department Actions
                ListTile(
                  leading: Icon(Icons.edit, color: ConstColors.primary),
                  title: Text('Edit Department Name'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(
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
                          ConstantSnackbar.showError(title: 'Failed to update');
                        }
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: ConstColors.errorRed),
                  title: Text('Delete Department'),
                  subtitle: Text(
                    'This will delete all roles',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('Delete Department?'),
                        content: Text(
                          'Delete "${dept.name}" and all its roles?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(c, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ConstColors.errorRed,
                            ),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final success = await provider.deleteDepartment(dept.id);
                      if (success) {
                        ConstantSnackbar.showSuccess(
                          title: 'Department deleted',
                        );
                      } else {
                        ConstantSnackbar.showError(title: 'Failed to delete');
                      }
                    }
                  },
                ),

                if (dept.roles.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Divider(),
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
                              _showEditDialog(
                                context: context,
                                title: 'Edit Role',
                                initialValue: role,
                                onSave: (newName) async {
                                  final success = await provider.updateRoleName(
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
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text('Delete Role?'),
                                  content: Text('Delete "$role"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ConstColors.errorRed,
                                      ),
                                      child: Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
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
    );
  }

  // Helper method for edit dialog
  void _showEditDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                onSave(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ConstColors.primary,
            ),
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add New Employee',
          style: getTextTheme().titleMedium?.copyWith(
            color: ConstColors.textColorWhite,
          ),
        ),
        backgroundColor: ConstColors.primary,
        foregroundColor: ConstColors.textColorWhite,
      ),
      body: Consumer<EmployeeManagementProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(5.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organization Details',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.primary,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Department Section
                    if (provider.departments.isEmpty ||
                        provider.isAddingNewDept)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ConstTextField(
                              controller: _newDeptController,
                              customText:
                                  'Add Department(s)(comma separated or single)',

                              prefixIcon: Icon(Icons.business, size: 20.r),
                              validator: (value) {
                                if (provider.isAddingNewDept ||
                                    provider.departments.isEmpty) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter department name(s)';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          if (provider.departments.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: ConstColors.errorRed,
                              ),
                              onPressed: () =>
                                  provider.setIsAddingNewDept(false),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.check_circle,
                              color: ConstColors.successGreen,
                            ),
                            onPressed: () async {
                              if (_newDeptController.text.trim().isNotEmpty) {
                                final success = await provider.addDepartments(
                                  _newDeptController.text.trim(),
                                );
                                if (success) {
                                  ConstantSnackbar.showSuccess(
                                    title: 'Department(s) added',
                                  );
                                  _newDeptController.clear();
                                  provider.setIsAddingNewDept(false);
                                } else {
                                  ConstantSnackbar.showError(
                                    title: 'Failed to add department(s)',
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Select Department',
                                prefixIcon: Icon(
                                  Icons.work_outline,
                                  size: 20.r,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              value: provider.selectedDepartment,
                              items: provider.departments.map((dept) {
                                return DropdownMenuItem(
                                  value: dept.name,
                                  child: Text(dept.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                provider.setSelectedDepartment(value);
                              },
                              validator: (value) {
                                if (!provider.isAddingNewDept &&
                                    provider.departments.isNotEmpty) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select department';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: ConstColors.primary,
                            ),
                            onPressed: () => provider.setIsAddingNewDept(true),
                            tooltip: 'Add New Department',
                          ),
                        ],
                      ),

                    SizedBox(height: 12.h),

                    // Role Section (Only if department selected)
                    if (provider.selectedDepartment != null &&
                        provider.selectedDepartment!.isNotEmpty)
                      () {
                        final selectedDept = provider.departments.firstWhere(
                          (d) => d.name == provider.selectedDepartment,
                          orElse: () =>
                              DepartmentModel(id: '', name: '', roles: []),
                        );

                        if (selectedDept.id.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        if (selectedDept.roles.isEmpty ||
                            provider.isAddingNewRole) {
                          return Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ConstTextField(
                                    controller: _newRoleController,
                                    customText: selectedDept.roles.isEmpty
                                        ? 'No roles found.\nAdd Role(s) (comma separated)'
                                        : 'Add Role(s)',
                                    prefixIcon: Icon(Icons.badge, size: 20.r),
                                    validator: (value) {
                                      if (selectedDept.roles.isEmpty ||
                                          provider.isAddingNewRole) {
                                        if (value == null || value.isEmpty) {
                                          return 'Enter role name(s)';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (selectedDept.roles.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: ConstColors.errorRed,
                                    ),
                                    onPressed: () =>
                                        provider.setIsAddingNewRole(false),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle,
                                    color: ConstColors.successGreen,
                                  ),
                                  onPressed: () async {
                                    if (_newRoleController.text
                                        .trim()
                                        .isNotEmpty) {
                                      final success = await provider
                                          .addRolesToDepartment(
                                            selectedDept.id,
                                            _newRoleController.text.trim(),
                                          );
                                      if (success) {
                                        ConstantSnackbar.showSuccess(
                                          title: 'Role(s) added',
                                        );
                                        _newRoleController.clear();
                                        provider.setIsAddingNewRole(false);
                                      } else {
                                        ConstantSnackbar.showError(
                                          title: 'Failed to add role(s)',
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: provider.selectedRole,
                                    decoration: InputDecoration(
                                      labelText: 'Select Role',
                                      prefixIcon: Icon(
                                        Icons.badge_outlined,
                                        size: 20.r,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                    ),
                                    items: selectedDept.roles.map((role) {
                                      return DropdownMenuItem(
                                        value: role,
                                        child: Text(role),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      provider.setSelectedRole(value);
                                    },
                                    validator: (value) {
                                      if (selectedDept.roles.isNotEmpty &&
                                          !provider.isAddingNewRole) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select role';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: ConstColors.primary,
                                  ),
                                  onPressed: () =>
                                      provider.setIsAddingNewRole(true),
                                  tooltip: 'Add New Role',
                                ),
                              ],
                            ),
                          );
                        }
                      }(),

                    SizedBox(height: 20.h),

                    // Department & Roles Overview - DataTable
                    if (provider.departments.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Departments & Roles',
                                style: getTextTheme().titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: ConstColors.primary,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.settings,
                                  size: 20.r,
                                  color: ConstColors.primary,
                                ),
                                tooltip: 'Manage Departments & Roles',
                                onPressed: () =>
                                    _showManageDepartmentsListDialog(
                                      context,
                                      provider,
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth:
                                    MediaQuery.of(context).size.width - 10.w,
                              ),
                              child: DataTable(
                                columnSpacing: 12.w,
                                horizontalMargin: 8.w,
                                headingRowHeight: 36.h,
                                dataRowMinHeight: 36.h,
                                dataRowMaxHeight: double.infinity,
                                headingRowColor: WidgetStatePropertyAll(
                                  ConstColors.primary.withOpacity(0.1),
                                ),
                                border: TableBorder.all(
                                  color: ConstColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Department',
                                      style: getTextTheme().bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: ConstColors.primary,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Roles',
                                      style: getTextTheme().bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: ConstColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: provider.departments.map((dept) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.h,
                                          ),
                                          child: Text(
                                            dept.name,
                                            style: getTextTheme().bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: 180.w,
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8.h,
                                            ),
                                            child: dept.roles.isEmpty
                                                ? Text(
                                                    'No roles available',
                                                    style: getTextTheme()
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: ConstColors
                                                              .textColorLight,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                  )
                                                : Wrap(
                                                    spacing: 4.w,
                                                    runSpacing: 4.h,
                                                    children: dept.roles.map((
                                                      role,
                                                    ) {
                                                      return Container(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 6.w,
                                                              vertical: 2.h,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: ConstColors
                                                              .primary
                                                              .withOpacity(
                                                                0.08,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4.r,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          role,
                                                          style: getTextTheme()
                                                              .labelSmall
                                                              ?.copyWith(
                                                                color:
                                                                    ConstColors
                                                                        .primary,
                                                              ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                        ],
                      ),
                    Text(
                      'Personal Details',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.primary,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    ConstTextField(
                      controller: _nameController,
                      customText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline, size: 20.r),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter employee name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12.h),
                    ConstTextField(
                      controller: _emailController,
                      customText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, size: 20.r),
                      keyoardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12.h),
                    ConstTextField(
                      controller: _mobileController,
                      customText: 'Mobile Number',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20.r),
                      keyoardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter mobile number';
                        }
                        if (value.length != 10) {
                          return 'Please enter a valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12.h),

                    // Sub Admin Checkbox
                    if (Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).isAdmin)
                      Row(
                        children: [
                          Checkbox(
                            value: provider.isSubAdminChecked,
                            onChanged: (value) {
                              provider.setSubAdminChecked(value ?? false);
                            },
                            activeColor: ConstColors.primary,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                provider.setSubAdminChecked(
                                  !provider.isSubAdminChecked,
                                );
                              },
                              child: Text(
                                'Make this employee a Sub Admin',
                                style: getTextTheme().bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: ConstColors.infoBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18.r,
                            color: ConstColors.infoBlue,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Default password: Welcome@2026',
                              style: getTextTheme().bodyMedium?.copyWith(
                                color: ConstColors.infoBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              provider.resetAddEmployeeForm();
                              Get.back();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              side: BorderSide(color: ConstColors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: getTextTheme().bodyMedium?.copyWith(
                                color: ConstColors.textColorLight,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: provider.isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      final result = await provider.addEmployee(
                                        name: _nameController.text.trim(),
                                        email: _emailController.text.trim(),
                                        mobileNumber: _mobileController.text
                                            .trim(),
                                        department: provider.selectedDepartment,
                                        role: provider.selectedRole,
                                        isSubAdmin: provider.isSubAdminChecked,
                                      );

                                      if (result['success']) {
                                        provider.resetAddEmployeeForm();
                                        Get.back();
                                        ConstantSnackbar.showSuccess(
                                          title: result['message'],
                                        );
                                      } else {
                                        ConstantSnackbar.showError(
                                          title: result['error'],
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ConstColors.primary,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: provider.isLoading
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ConstColors.white,
                                    ),
                                  )
                                : Text(
                                    'Add Employee',
                                    style: getTextTheme().bodyMedium?.copyWith(
                                      color: ConstColors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
