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
    super.dispose();
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
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: ConstColors.warningAmber.withOpacity(0.12),
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
                              'Department and role can be assigned from the employee details after adding.',
                              style: getTextTheme().bodySmall,
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
