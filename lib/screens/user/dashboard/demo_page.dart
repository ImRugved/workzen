import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../models/employee_model.dart';
import '../../../models/leave_config_model.dart';
import '../../../models/office_hours_model.dart';
import '../../../providers/employee_directory_provider.dart';
import '../../../providers/employee_management_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/toggle_provider.dart';
import '../../../constants/const_textstyle.dart';
import '../../../constants/constant_colors.dart';
import '../../../constants/constant_dropdown.dart';
import '../../../constants/app_theme.dart';

/// "Info" tab: the organization's yearly leave and office timings, a place for
/// the company rules, and the employee directory table with search and
/// department / role filters.
class UserDemoPage extends StatefulWidget {
  const UserDemoPage({super.key});

  @override
  State<UserDemoPage> createState() => _UserDemoPageState();
}

class _UserDemoPageState extends State<UserDemoPage> {
  // Loading flag and directory filters (scoped state, no setState)
  final ToggleProvider _isLoading = ToggleProvider(true);
  final EmployeeDirectoryProvider _directory = EmployeeDirectoryProvider();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Live leave counts and office hours set by the admin
      context.read<OrganizationProvider>().start();
      _loadData();
    });
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
        appBar: AppBar(title: const Text('Info')),
        backgroundColor: ConstColors.backgroundColor,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.screen,
            children: [
              const _OrganizationCard(),
              SizedBox(height: 16.h),
              const _CompanyRulesCard(),
              SizedBox(height: 16.h),
              _buildDirectory(),
            ],
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

/// Yearly leave counts and office timings set by the admin.
class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard();

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<OrganizationProvider>(
          builder: (context, org, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heading(Icons.beach_access_outlined, 'Yearly Leave'),
              SizedBox(height: 10.h),
              _leaveRow(org.leaveConfigLoaded, org.leaveConfig),
              SizedBox(height: 16.h),
              _heading(Icons.access_time, 'Office Timings'),
              SizedBox(height: 10.h),
              _officeRows(context, org.officeHoursLoaded, org.officeHours),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: ConstColors.primary, size: 22.r),
        SizedBox(width: 8.w),
        Text(
          title,
          style: getTextTheme().titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _muted(String text) => Text(
    text,
    style: getTextTheme().bodySmall?.copyWith(
      color: ConstColors.textColorLight,
    ),
  );

  Widget _leaveRow(bool loaded, LeaveConfigModel? config) {
    if (!loaded) return _muted('Loading...');
    if (config == null) return _muted('Not set by the admin yet');

    final total =
        config.privilegeLeaves + config.sickLeaves + config.casualLeaves;
    return Row(
      children: [
        _stat('PL', config.privilegeLeaves, ConstColors.infoBlue),
        SizedBox(width: 8.w),
        _stat('SL', config.sickLeaves, ConstColors.successGreen),
        SizedBox(width: 8.w),
        _stat('CL', config.casualLeaves, ConstColors.inProgressOrange),
        SizedBox(width: 8.w),
        _stat('Total', total, ConstColors.primary),
      ],
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: getTextTheme().titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: getTextTheme().labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _officeRows(
    BuildContext context,
    bool loaded,
    OfficeHoursModel? hours,
  ) {
    if (!loaded) return _muted('Loading...');
    if (hours == null) return _muted('Not set by the admin yet');

    final lines = <MapEntry<String, String>>[
      MapEntry(
        'Working hours',
        '${hours.startTime.format(context)} - ${hours.endTime.format(context)}',
      ),
      if (hours.lateAfterMinutes != null)
        MapEntry(
          'Late after',
          '${hours.startPlus(hours.lateAfterMinutes!).format(context)} '
              '(${hours.lateAfterMinutes} min)',
        ),
      if (hours.halfDayAfterMinutes != null)
        MapEntry(
          'Half day after',
          '${hours.startPlus(hours.halfDayAfterMinutes!).format(context)} '
              '(${hours.halfDayAfterMinutes} min)',
        ),
    ];

    return Column(
      children: lines
          .map(
            (line) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    line.key,
                    style: getTextTheme().bodyMedium?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                  Text(
                    line.value,
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Placeholder until the company rules are written.
class _CompanyRulesCard extends StatelessWidget {
  const _CompanyRulesCard();

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_outlined, color: ConstColors.primary),
                SizedBox(width: 8.w),
                Text(
                  'Company Rules',
                  style: getTextTheme().titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              'Company rules will be added here soon.',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
