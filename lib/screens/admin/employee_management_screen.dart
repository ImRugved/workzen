import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:workzen/constants/constant_colors.dart';
import '../../providers/employee_management_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../models/employee_model.dart';
import '../../widgets/app_drawer.dart';
import '../../constants/const_textstyle.dart';
import 'employee_details_screen.dart';
import 'add_employee_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFilter;

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
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
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
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeYearlyRenewal(nextYear);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ConstColors.primary,
              foregroundColor: ConstColors.white,
            ),
            child: Text('Renew for $nextYear'),
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
            const CircularProgressIndicator(),
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
    await onboardingProvider.loadLeaveDefaults();
    final count = await onboardingProvider.renewYearlyLeaves(newYear: year);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Successfully renewed leaves for $count employee(s) for $year'
                : 'No employees to renew (already renewed or none onboarded)',
          ),
          backgroundColor: count > 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Management',
          style: getTextTheme().titleMedium?.copyWith(
            color: ConstColors.textColorWhite,
          ),
        ),
        backgroundColor: ConstColors.primary,
        foregroundColor: ConstColors.textColorWhite,
        actions: [
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddEmployee,
        backgroundColor: ConstColors.primary,
        child: Icon(Icons.person_add, color: ConstColors.white),
      ),
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
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: ConstColors.white,
        boxShadow: [
          BoxShadow(
            color: ConstColors.grey.withOpacity(0.2),
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
              suffixIcon: _searchController.text.isNotEmpty
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
                child: DropdownButtonFormField<String>(
                  value: _selectedFilter,
                  decoration: InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        'All Employees',
                        style: getTextTheme().bodyMedium,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'onboarded',
                      child: Text('Onboarded'),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pending Onboarding'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value;
                    });

                    if (value == null) {
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
              ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedFilter = null;
                  });
                  provider.clearFilters();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConstColors.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text('Clear', style: getTextTheme().labelMedium),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      child: Padding(
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
      ),
    );
  }

  Widget _buildEmployeeList(EmployeeManagementProvider provider) {
    if (provider.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: ConstColors.primary),
      );
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
            ElevatedButton.icon(
              onPressed: () => provider.refreshEmployees(),
              style: ElevatedButton.styleFrom(
                backgroundColor: ConstColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              icon: Icon(Icons.refresh, size: 20.r),
              label: Text('Retry', style: getTextTheme().labelMedium),
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

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: provider.employees.length,
      itemBuilder: (context, index) {
        final employee = provider.employees[index];
        return _buildEmployeeCard(employee, provider);
      },
    );
  }

  Widget _buildEmployeeCard(
    EmployeeModel employee,
    EmployeeManagementProvider provider,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return GestureDetector(
      onTap: () {
        Get.to(
          () => EmployeeDetailsScreen(employee: employee),
          transition: Transition.rightToLeft,
        );
      },
      child: Card(
        color: ConstColors.white,
        margin: EdgeInsets.only(bottom: 12.h),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              colors: [
                ConstColors.white,
                ConstColors.lightShade.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Status Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.name,
                        style: getTextTheme().titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Status Chip
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: employee.isOnboarded
                            ? ConstColors.successGreen.withOpacity(0.1)
                            : ConstColors.warningAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: employee.isOnboarded
                              ? ConstColors.successGreen
                              : ConstColors.warningAmber,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            employee.isOnboarded
                                ? Icons.check_circle
                                : Icons.pending,
                            color: employee.isOnboarded
                                ? ConstColors.successGreen
                                : ConstColors.warningAmber,
                            size: 12.r,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            employee.isOnboarded ? 'Onboarded' : 'Pending',
                            style: getTextTheme().labelSmall?.copyWith(
                              color: employee.isOnboarded
                                  ? ConstColors.successGreen
                                  : ConstColors.warningAmber,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                // Email and Arrow Icon Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.email,
                        style: getTextTheme().bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Arrow Icon
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16.r,
                      color: ConstColors.textColorLight,
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                // Employee Details: ID, Department, Joining Date
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Emp ID',
                        employee.employeeId ?? 'Not Set',
                        Icons.badge,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildInfoItem(
                        'Department',
                        employee.department ?? 'Not Set',
                        Icons.work,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildInfoItem(
                        'Joining Date',
                        employee.joiningDate != null
                            ? dateFormat.format(employee.joiningDate!)
                            : 'Not Set',
                        Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12.r, color: color ?? ConstColors.primary),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                label,
                style: getTextTheme().labelSmall?.copyWith(fontSize: 10.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: getTextTheme().bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
            fontSize: 11.sp,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
