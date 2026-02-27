import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../providers/employee_management_provider.dart';
import '../../../constants/const_textstyle.dart';
import '../../../constants/constant_colors.dart';

class UserDemoPage extends StatefulWidget {
  const UserDemoPage({Key? key}) : super(key: key);

  @override
  State<UserDemoPage> createState() => _UserDemoPageState();
}

class _UserDemoPageState extends State<UserDemoPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final empProvider = Provider.of<EmployeeManagementProvider>(
      context,
      listen: false,
    );
    await Future.wait([
      empProvider.fetchDepartments(),
      empProvider.fetchAllEmployees(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments & Employees'),
        backgroundColor: ConstColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: ConstColors.backgroundColor,
      body: Consumer<EmployeeManagementProvider>(
        builder: (context, empProvider, _) {
          if (_isLoading) {
            return _buildShimmerLoading();
          }

          if (empProvider.departments.isEmpty) {
            return Center(
              child: Text(
                'No departments found',
                style: getTextTheme().bodyMedium,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _isLoading = true);
              await Future.wait([
                empProvider.fetchDepartments(),
                empProvider.fetchAllEmployees(),
              ]);
              if (mounted) setState(() => _isLoading = false);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              itemCount: empProvider.departments.length,
              itemBuilder: (context, index) {
                final dept = empProvider.departments[index];
                final deptEmployees = empProvider.employees
                    .where((e) => e.department == dept.name)
                    .toList();

                return Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Department header
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            color: ConstColors.primary,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12.r),
                              topRight: Radius.circular(12.r),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                color: Colors.white,
                                size: 20.r,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  dept.name,
                                  style: getTextTheme().titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  '${deptEmployees.length} emp',
                                  style: getTextTheme().labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Roles chips
                        if (dept.roles.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                            child: Wrap(
                              spacing: 6.w,
                              runSpacing: 4.h,
                              children: dept.roles.map((role) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ConstColors.accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6.r),
                                    border: Border.all(
                                      color: ConstColors.accent.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    role,
                                    style: getTextTheme().labelSmall?.copyWith(
                                      color: ConstColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // Employee data table
                        if (deptEmployees.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(
                              'No employees in this department',
                              style: getTextTheme().bodySmall?.copyWith(
                                color: ConstColors.textColorLight,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  ConstColors.lightShade,
                                ),
                                columnSpacing: 16.w,
                                horizontalMargin: 12.w,
                                headingRowHeight: 40.h,
                                dataRowMinHeight: 36.h,
                                dataRowMaxHeight: 48.h,
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Name',
                                      style: getTextTheme().bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: ConstColors.textColor,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Role',
                                      style: getTextTheme().bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: ConstColors.textColor,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: deptEmployees.map((emp) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          emp.name,
                                          style: getTextTheme().bodySmall
                                              ?.copyWith(
                                                color: ConstColors.textColor,
                                              ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                            vertical: 2.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: ConstColors.accent
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4.r,
                                            ),
                                          ),
                                          child: Text(
                                            emp.role ?? '-',
                                            style: getTextTheme().labelSmall
                                                ?.copyWith(
                                                  color: ConstColors.primary,
                                                  fontWeight: FontWeight.w500,
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
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(
            3,
            (_) => Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 160.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
