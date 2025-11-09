import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../../providers/employee_management_provider.dart';
import '../../models/employee_model.dart';
import '../../widgets/app_drawer.dart';
import '../../constants/const_textstyle.dart';
import 'employee_details_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EmployeeManagementProvider>(
        context,
        listen: false,
      ).fetchAllEmployees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Management',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r),
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
      body: Consumer<EmployeeManagementProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Search and Filter Section
              _buildSearchAndFilterSection(provider),

              // Statistics Section
              _buildStatisticsSection(provider),

              // Employee List
              Expanded(child: _buildEmployeeList(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilterSection(EmployeeManagementProvider provider) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
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
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Employees')),
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
                  backgroundColor: Colors.indigo,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'Clear',
                  style: getTextTheme().labelMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
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
              Colors.blue,
              Icons.people,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildStatCard(
              'Onboarded',
              provider.onboardedEmployees.toString(),
              Colors.green,
              Icons.check_circle,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildStatCard(
              'Pending',
              provider.pendingEmployees.toString(),
              Colors.orange,
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
              style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600),
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
      return Center(child: CircularProgressIndicator(color: Colors.indigo));
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80.r, color: Colors.red.shade300),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Text(
                provider.errorMessage!,
                style: getTextTheme().bodyLarge?.copyWith(
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () => provider.refreshEmployees(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              icon: Icon(Icons.refresh, size: 20.r),
              label: Text(
                'Retry',
                style: getTextTheme().labelLarge?.copyWith(color: Colors.white),
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
            Icon(Icons.people_outline, size: 80.r, color: Colors.grey.shade400),
            SizedBox(height: 16.h),
            Text(
              'No employees found',
              style: getTextTheme().bodyLarge?.copyWith(
                color: Colors.grey.shade600,
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
        margin: EdgeInsets.only(bottom: 12.h),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Profile Picture with Hero animation
                    Hero(
                      tag: 'employee_${employee.id}',
                      child: CircleAvatar(
                        radius: 35.r,
                        backgroundColor: Colors.indigo.shade100,
                        child:
                            employee.profileImageUrl != null &&
                                employee.profileImageUrl!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: employee.profileImageUrl!,
                                  width: 70.w,
                                  height: 70.h,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.indigo,
                                      ),
                                  errorWidget: (context, url, error) => Text(
                                    employee.name.isNotEmpty
                                        ? employee.name[0].toUpperCase()
                                        : 'E',
                                    style: getTextTheme().headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                  ),
                                ),
                              )
                            : Text(
                                employee.name.isNotEmpty
                                    ? employee.name[0].toUpperCase()
                                    : 'E',
                                style: getTextTheme().headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(width: 16.w),

                    // Employee Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.name,
                            style: getTextTheme().titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            employee.email,
                            style: getTextTheme().bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8.h),
                          // Status Chip
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: employee.isOnboarded
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: employee.isOnboarded
                                    ? Colors.green
                                    : Colors.orange,
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
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 14.r,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  employee.isOnboarded
                                      ? 'Onboarded'
                                      : 'Pending',
                                  style: getTextTheme().labelSmall?.copyWith(
                                    color: employee.isOnboarded
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrow Icon
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 20.r,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Employee Details Grid
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              'Employee ID',
                              employee.employeeId ?? 'Not Set',
                              Icons.badge,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildInfoItem(
                              'Department',
                              employee.department ?? 'Not Set',
                              Icons.work,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildInfoItem(
                        'Joining Date',
                        employee.joiningDate != null
                            ? dateFormat.format(employee.joiningDate!)
                            : 'Not Set',
                        Icons.calendar_today,
                      ),
                    ],
                  ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16.r, color: color ?? Colors.indigo.shade300),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: getTextTheme().labelSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: getTextTheme().bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
