import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import '../../app_constants.dart';
import '../../constants/constant_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../constants/constant_textfield.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../constants/app_theme.dart';
import '../../utils/validators.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_dropdown.dart';
import '../../widgets/sub_admin_permissions_picker.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<EmployeeManagementProvider>(
        context,
        listen: false,
      );
      provider.resetAddEmployeeForm();
      // Departments and roles the admin created in the Settings tab
      provider.fetchDepartments();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  // Department, then a job role from that department. Both are optional and
  // come from the Settings tab; with none created yet a hint explains where.
  Widget _buildDepartmentAndJobRole(EmployeeManagementProvider provider) {
    final departments = provider.departments;

    if (departments.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: ConstColors.warningAmber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.business_outlined,
              size: 18.r,
              color: ConstColors.inProgressOrange,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'No departments yet. You can add departments and roles from the Settings tab.',
                style: getTextTheme().bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final roles = departments
        .where((d) => d.name == provider.selectedDepartment)
        .expand((d) => d.roles)
        .toList();

    return Column(
      children: [
        ConstantDropdown<String>(
          value: provider.selectedDepartment,
          label: 'Department (optional)',
          prefixIcon: Icon(Icons.work_outline, size: 20.r),
          items: departments.map((d) => d.name).toList(),
          itemLabel: (d) => d,
          onChanged: provider.setSelectedDepartment,
        ),
        SizedBox(height: 16.h),
        if (provider.selectedDepartment != null && roles.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'This department has no roles yet. You can add roles from the Settings tab.',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
          )
        else
          ConstantDropdown<String>(
            // A new key resets the field when the department changes
            key: ValueKey('job-role-${provider.selectedDepartment}'),
            value: provider.selectedRole,
            label: 'Job Role (optional)',
            prefixIcon: Icon(Icons.badge_outlined, size: 20.r),
            items: roles,
            itemLabel: (r) => r,
            onChanged: provider.selectedDepartment == null
                ? null
                : provider.setSelectedRole,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add New Employee',
          style: getTextTheme().titleMedium?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
        backgroundColor: ConstColors.primary,
        foregroundColor: ConstColors.textColor,
      ),
      body: Consumer<EmployeeManagementProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.screen,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Details',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.primaryDeep,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    ConstTextField(
                      controller: _nameController,
                      customText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline, size: 20.r),
                      validator: Validators.required('employee name'),
                    ),
                    SizedBox(height: 12.h),
                    ConstTextField(
                      controller: _emailController,
                      customText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, size: 20.r),
                      keyoardType: TextInputType.emailAddress,
                      validator: Validators.email,
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
                      validator: Validators.mobileNumber,
                    ),
                    SizedBox(height: 12.h),

                    // Sub Admin Checkbox
                    // Role: employee, intern or freelancer
                    ConstantDropdown<String>(
                      value: provider.newEmployeeRole,
                      label: 'Role',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20.r),
                      items: AppConstants.assignableRoles,
                      itemLabel: AppConstants.roleLabel,
                      onChanged: (role) {
                        if (role != null) provider.setNewEmployeeRole(role);
                      },
                    ),
                    SizedBox(height: 16.h),
                    _buildDepartmentAndJobRole(provider),
                    SizedBox(height: 12.h),
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

                    // What this sub admin may access (admin chooses)
                    if (provider.isSubAdminChecked &&
                        Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).isAdmin) ...[
                      SizedBox(height: 8.h),
                      SubAdminPermissionsPicker(
                        selected: provider.subAdminPermissions,
                        onChanged: provider.setSubAdminPermission,
                        onSelectAll: provider.setAllSubAdminPermissions,
                      ),
                    ],

                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: ConstColors.infoBlue.withValues(alpha: 0.1),
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
                          child: ConstantButton(
                            text: 'Cancel',
                            isOutlined: true,
                            backgroundColor: ConstColors.grey,
                            textColor: ConstColors.textColorLight,
                            onPressed: () {
                              provider.resetAddEmployeeForm();
                              Get.back();
                            },
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ConstantButton(
                            text: 'Add Employee',
                            isLoading: provider.isLoading,
                            backgroundColor: ConstColors.primary,
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
                                        employmentRole:
                                            provider.newEmployeeRole,
                                        isSubAdmin: provider.isSubAdminChecked,
                                        subAdminPermissions: provider
                                            .subAdminPermissions
                                            .toList(),
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
