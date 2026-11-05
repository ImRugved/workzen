import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/employee_model.dart';
import '../../providers/employee_directory_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../providers/toggle_provider.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/app_theme.dart';

/// Employee directory: a table of the employees (name, ID, department, email,
/// role, job role, mobile) with search and department / role filters. Opened
/// from the Info tab.
class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() =>
      _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  // Loading flag and directory filters (scoped state, no setState)
  final ToggleProvider _isLoading = ToggleProvider(true);
  final EmployeeDirectoryProvider _directory = EmployeeDirectoryProvider();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _directory.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final empProvider = context.read<EmployeeManagementProvider>();
    await Future.wait([
      empProvider.fetchDepartments(),
      empProvider.fetchAllEmployees(),
    ]);
    if (!mounted) return;
    _isLoading.set(false);
  }

  Future<void> _refresh() async {
    _isLoading.set(true);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _isLoading),
        ChangeNotifierProvider.value(value: _directory),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Employee Directory')),
        backgroundColor: ConstColors.backgroundColor,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.screen,
            children: [_buildDirectory()],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectory() {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline, color: ConstColors.primary),
                SizedBox(width: 8.w),
                Text(
                  'Employee Directory',
                  style: getTextTheme().titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _searchController,
              onChanged: _directory.setSearch,
              decoration: InputDecoration(
                hintText: 'Search name, ID, department, role, email...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            _buildFilters(),
            SizedBox(height: 8.h),
            Consumer2<ToggleProvider, EmployeeManagementProvider>(
              builder: (context, loading, employees, _) {
                if (loading.value) return _buildShimmer();
                return _EmployeeTable(employees: employees.allEmployees);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Consumer2<EmployeeDirectoryProvider, EmployeeManagementProvider>(
      builder: (context, directory, employees, _) {
        final departments = employees.departments.map((d) => d.name).toList()
          ..sort();
        final roles = directory.rolesFor(employees.allEmployees);

        return Row(
          children: [
            Expanded(
              child: ConstantDropdown<String?>(
                label: 'Department',
                isDense: true,
                value: directory.department,
                items: [null, ...departments],
                itemLabel: (d) => d ?? 'All',
                onChanged: directory.setDepartment,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: ConstantDropdown<String?>(
                // A new key resets the field when the department changes
                key: ValueKey('role-${directory.department}'),
                label: 'Role',
                isDense: true,
                value: directory.role,
                items: [null, ...roles],
                itemLabel: (r) => r ?? 'All',
                onChanged: directory.setRole,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: ConstColors.borderColor,
      highlightColor: ConstColors.backgroundColor,
      child: Container(
        height: 160.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: ConstColors.cardBackground,
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }
}

/// Employees in a data table: name, ID, department, email, role and mobile.
class _EmployeeTable extends StatelessWidget {
  final List<EmployeeModel> employees;

  const _EmployeeTable({required this.employees});

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<EmployeeDirectoryProvider>();
    final rows = directory.apply(employees);

    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Text(
            employees.isEmpty
                ? 'No employees found'
                : 'No employees match your filters',
            style: getTextTheme().bodySmall?.copyWith(
              color: ConstColors.textColorLight,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: 0,
        sortAscending: directory.sortAscending,
        headingRowColor: WidgetStateProperty.all(ConstColors.lightShade),
        columnSpacing: 20.w,
        horizontalMargin: 12.w,
        headingRowHeight: 40.h,
        dataRowMinHeight: 40.h,
        dataRowMaxHeight: 52.h,
        columns: [
          DataColumn(
            label: const Text('Name'),
            onSort: (_, ascending) => directory.setSortAscending(ascending),
          ),
          const DataColumn(label: Text('Emp ID')),
          const DataColumn(label: Text('Department')),
          const DataColumn(label: Text('Email')),
          const DataColumn(label: Text('Role')),
          const DataColumn(label: Text('Job Role')),
          const DataColumn(label: Text('Mobile')),
        ],
        rows: rows
            .map(
              (e) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      e.name,
                      style: getTextTheme().bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(Text(e.employeeId ?? '-')),
                  DataCell(Text(e.department ?? '-')),
                  DataCell(Text(e.email)),
                  DataCell(Text(e.roleLabel)),
                  DataCell(Text(e.jobRole ?? '-')),
                  DataCell(Text(e.mobileNumber ?? '-')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
