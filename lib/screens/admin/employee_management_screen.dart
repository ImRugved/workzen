import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:workzen/constants/constant_colors.dart';
import 'package:workzen/constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../constants/permissions.dart';
import '../../widgets/app_drawer.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/apploading_indicator.dart';
import 'employee_details_screen.dart';
import 'add_employee_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  // Search text and status filter live in EmployeeManagementProvider
  final TextEditingController _searchController = TextEditingController();

  // Controllers for add employee dialog

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EmployeeManagementProvider>(
        context,
        listen: false,
      ).fetchAllEmployees();
      Provider.of<EmployeeManagementProvider>(
        context,
        listen: false,
      ).fetchDepartments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToAddEmployee() {
    Get.to(() => const AddEmployeeScreen());
  }

  void _showRenewYearlyLeavesDialog() {
    final nextYear = DateTime.now().year + 1;
    final currentYear = DateTime.now().year;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Renew Yearly Leaves',
          style: getTextTheme().titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create leave allocations for $nextYear for all onboarded employees.',
              style: getTextTheme().bodyMedium,
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: ConstColors.lightShade,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carry-forward rules:',
                    style: getTextTheme().bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'PL: Unused balance from $currentYear carries forward',
                    style: getTextTheme().bodySmall,
                  ),
                  Text(
                    'SL: Fresh allocation (no carry forward)',
                    style: getTextTheme().bodySmall,
                  ),
                  Text(
                    'CL: Fresh allocation (no carry forward)',
                    style: getTextTheme().bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ConstantButton(
            text: 'Renew for $nextYear',
            onPressed: () async {
              Navigator.pop(context);
              await _executeYearlyRenewal(nextYear);
            },
            isFullWidth: false,
            height: 40.h,
            backgroundColor: ConstColors.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _executeYearlyRenewal(int year) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const AppLoadingIndicator(size: 40),
            SizedBox(width: 16.w),
            Text('Renewing leaves for $year...'),
          ],
        ),
      ),
    );

    final onboardingProvider = Provider.of<OnboardingProvider>(
      context,
      listen: false,
    );
    // Leave defaults are kept live by OrganizationProvider
    if (!onboardingProvider.isLeaveConfigured) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ConstantSnackbar.show(
          title:
              'Set the default leave counts first: Admin Dashboard > Leave Configuration',
          backgroundColor: ConstColors.inProgressOrange,
        );
      }
      return;
    }

    final count = await onboardingProvider.renewYearlyLeaves(newYear: year);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (count > 0) {
        ConstantSnackbar.showSuccess(
          title: 'Leave for $year is renewed for $count employee(s)',
        );
      } else {
        ConstantSnackbar.show(
          title:
              'Nothing to renew: leave is already renewed or nobody is onboarded',
          backgroundColor: ConstColors.inProgressOrange,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Management',
          style: getTextTheme().titleMedium?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
        backgroundColor: ConstColors.primary,
        foregroundColor: ConstColors.textColor,
        actions: [
          if (context.read<AuthProvider>().can(Permissions.onboarding))
            IconButton(
              icon: Icon(Icons.autorenew, size: 20.r),
              onPressed: () => _showRenewYearlyLeavesDialog(),
              tooltip: 'Renew Yearly Leaves',
            ),
          IconButton(
            icon: Icon(Icons.refresh, size: 20.r),
            onPressed: () {
              Provider.of<EmployeeManagementProvider>(
                context,
                listen: false,
              ).refreshEmployees();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton:
          context.read<AuthProvider>().can(Permissions.addEmployee)
          ? FloatingActionButton(
              onPressed: _navigateToAddEmployee,
              backgroundColor: ConstColors.primary,
              child: Icon(Icons.person_add, color: ConstColors.textColor),
            )
          : null,
      body: Consumer<EmployeeManagementProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: Column(
              children: [
                // Search and Filter Section
                _buildSearchAndFilterSection(provider),

                // Statistics Section
                _buildStatisticsSection(provider),

                // Employee List
                Expanded(child: _buildEmployeeList(provider)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilterSection(EmployeeManagementProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: ConstColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: ConstColors.neuShadowDark,
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or emp ID...',
              hintStyle: getTextTheme().bodySmall,
              prefixIcon: Icon(Icons.search, size: 20.r),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 20.r),
                      onPressed: () {
                        _searchController.clear();
                        provider.searchEmployees('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onChanged: (value) {
              provider.searchEmployees(value);
            },
          ),

          SizedBox(height: 12.h),

          // Filter Dropdown
          Row(
            children: [
              Expanded(
                child: ConstantDropdown<String>(
                  value: switch (provider.onboardingFilter) {
                    true => 'onboarded',
                    false => 'pending',
                    null => 'all',
                  },
                  label: 'Filter by Status',
                  items: const ['all', 'onboarded', 'pending'],
                  itemLabel: (v) => switch (v) {
                    'onboarded' => 'Onboarded',
                    'pending' => 'Pending Onboarding',
                    _ => 'All Employees',
                  },
                  onChanged: (value) {
                    if (value == null || value == 'all') {
                      provider.clearFilters();
                    } else if (value == 'onboarded') {
                      provider.filterByOnboardingStatus(true);
                    } else if (value == 'pending') {
                      provider.filterByOnboardingStatus(false);
                    }
                  },
                ),
              ),
              SizedBox(width: 12.w),
              ConstantButton(
                text: 'Clear',
                onPressed: () {
                  _searchController.clear();
                  provider.clearFilters();
                },
                isFullWidth: false,
                height: 40.h,
                backgroundColor: ConstColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(EmployeeManagementProvider provider) {
    return Container(
      height: 95.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Employees',
              provider.totalEmployees.toString(),
              ConstColors.infoBlue,
              Icons.people,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildStatCard(
              'Onboarded',
              provider.onboardedEmployees.toString(),
              ConstColors.successGreen,
              Icons.check_circle,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildStatCard(
              'Pending',
              provider.pendingEmployees.toString(),
              ConstColors.warningAmber,
              Icons.pending,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return NeuCard(
      radius: 10,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20.r),
          SizedBox(height: 3.h),
          Text(
            value,
            style: getTextTheme().titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            title,
            style: getTextTheme().labelSmall?.copyWith(
              fontSize: 9.sp,
              color: ConstColors.textColorLight,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList(EmployeeManagementProvider provider) {
    if (provider.isLoading) {
      return Center(child: AppLoadingIndicator(size: 40));
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80.r, color: ConstColors.errorRed),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Text(
                provider.errorMessage!,
                style: getTextTheme().bodyLarge?.copyWith(
                  color: ConstColors.textColorLight,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24.h),
            ConstantButton(
              text: 'Retry',
              onPressed: () => provider.refreshEmployees(),
              isFullWidth: false,
              backgroundColor: ConstColors.primary,
              borderRadius: 12.r,
              icon: Icon(
                Icons.refresh,
                size: 20.r,
                color: ConstColors.textColor,
              ),
            ),
          ],
        ),
      );
    }

    if (provider.employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80.r,
              color: ConstColors.textColorLight,
            ),
            SizedBox(height: 16.h),
            Text(
              'No employees found',
              style: getTextTheme().bodyLarge?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
          ],
        ),
      );
    }

    final canManage = context.read<AuthProvider>().can(
      Permissions.manageEmployees,
    );
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Name, ID, department, role, joining date and status in a table; the
    // row's edit button opens the edit bottom sheet
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20.w,
          headingRowColor: WidgetStatePropertyAll(
            ConstColors.primary.withValues(alpha: 0.08),
          ),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Emp ID')),
            DataColumn(label: Text('Department')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Job Role')),
            DataColumn(label: Text('Joined')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: provider.employees.map((employee) {
            final statusColor = employee.isOnboarded
                ? ConstColors.successGreen
                : ConstColors.warningAmber;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    employee.name,
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(Text(employee.employeeId ?? '-')),
                DataCell(Text(employee.department ?? '-')),
                DataCell(Text(employee.roleLabel)),
                DataCell(Text(employee.jobRole ?? '-')),
                DataCell(
                  Text(
                    employee.joiningDate != null
                        ? dateFormat.format(employee.joiningDate!)
                        : '-',
                  ),
                ),
                DataCell(
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      employee.isOnboarded ? 'Onboarded' : 'Pending',
                      style: getTextTheme().labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  canManage
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, size: 20.r),
                              color: ConstColors.primaryDeep,
                              tooltip: 'Edit',
                              onPressed: () => Get.to(
                                () => EmployeeDetailsScreen(
                                  employee: employee,
                                  startInEditMode: true,
                                ),
                                transition: Transition.rightToLeft,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.visibility, size: 20.r),
                              tooltip: 'Details',
                              onPressed: () => Get.to(
                                () => EmployeeDetailsScreen(employee: employee),
                                transition: Transition.rightToLeft,
                              ),
                            ),
                          ],
                        )
                      : const Text('-'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
