import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animated_number/animated_number.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';
import '../../app_constants.dart';
import '../../constants/const_textstyle.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({Key? key}) : super(key: key);

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  Stream<List<RequestModel>>? _leavesStream;
  final bool isAnimated = true; // Default to true, can be changed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      _initializeNotifications();
    });
  }

  void _initializeData() {
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );
    final employeeProvider = Provider.of<EmployeeManagementProvider>(
      context,
      listen: false,
    );

    setState(() {
      _leavesStream = requestProvider.getAllRequestsStream();
    });

    // Fetch employee data
    employeeProvider.fetchAllEmployees();
  }

  void _initializeNotifications() async {
    try {
      await PushNotificationsService().initAfterLogin();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final employeeProvider = Provider.of<EmployeeManagementProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Dashboard Panel',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r),
            onPressed: _initializeData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: authProvider.userModel == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<RequestModel>>(
              stream: _leavesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // Handle different types of errors with user-friendly messages
                  String errorMessage =
                      'Unable to load leave requests at the moment.';

                  if (snapshot.error.toString().contains('permission-denied') ||
                      snapshot.error.toString().contains('PERMISSION_DENIED')) {
                    errorMessage =
                        'Access denied. Please check your admin permissions.';
                  } else if (snapshot.error.toString().contains('network') ||
                      snapshot.error.toString().contains('connection')) {
                    errorMessage =
                        'Network error. Please check your internet connection.';
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64.r,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          errorMessage,
                          style: getTextTheme().bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton.icon(
                          onPressed: _initializeData,
                          icon: Icon(Icons.refresh, size: 20.r),
                          label: Text(
                            'Try Again',
                            style: getTextTheme().labelLarge,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allRequests = snapshot.data ?? [];

                // Count request statistics
                final pendingRequests = allRequests
                    .where((r) => r.status == AppConstants.statusPending)
                    .length;
                final approvedRequests = allRequests
                    .where((r) => r.status == AppConstants.statusApproved)
                    .length;
                final rejectedRequests = allRequests
                    .where((r) => r.status == AppConstants.statusRejected)
                    .length;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card with Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.indigo.shade700,
                              Colors.indigo.shade400,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(20.w),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 30.r,
                              child: Text(
                                authProvider.userModel?.name.isNotEmpty == true
                                    ? authProvider.userModel!.name[0]
                                          .toUpperCase()
                                    : "A",
                                style: getTextTheme().displayMedium?.copyWith(
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome Back!',
                                    style: getTextTheme().bodyMedium?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    authProvider.userModel?.name ?? "Admin",
                                    style: getTextTheme().titleLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    authProvider.userModel?.email ?? "",
                                    style: getTextTheme().bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Employee Statistics Section
                      _buildSectionHeader('Employee Overview', Icons.people),
                      SizedBox(height: 12.h),
                      _buildEmployeeStatsCard(employeeProvider),
                      SizedBox(height: 24.h),

                      // Leave Requests Statistics Section
                      _buildSectionHeader(
                        'Leave Requests Overview',
                        Icons.event_note,
                      ),
                      SizedBox(height: 12.h),
                      _buildLeaveRequestsStatsCard(
                        allRequests.length,
                        pendingRequests,
                        approvedRequests,
                        rejectedRequests,
                      ),
                      SizedBox(height: 24.h),

                      // Quick Actions
                      _buildSectionHeader('Quick Actions', Icons.touch_app),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              'Manage Leaves',
                              Icons.approval,
                              Colors.indigo,
                              () async {
                                await Get.toNamed('/leave_requests_screen');
                                if (mounted) _initializeData();
                              },
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildActionCard(
                              'Employees',
                              Icons.people,
                              Colors.teal,
                              () async {
                                await Get.toNamed(
                                  '/employee_management_screen',
                                );
                                if (mounted) _initializeData();
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              'Attendance',
                              Icons.access_time,
                              Colors.orange,
                              () async {
                                await Get.toNamed('/admin_attendance_screen');
                                if (mounted) _initializeData();
                              },
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildActionCard(
                              'Onboarding',
                              Icons.person_add,
                              Colors.purple,
                              () async {
                                await Get.toNamed(
                                  '/employee_onboarding_screen',
                                );
                                if (mounted) _initializeData();
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // Recent Requests
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            'Recent Requests',
                            Icons.history,
                            showDivider: false,
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Get.toNamed('/leave_requests_screen');
                              if (mounted) _initializeData();
                            },
                            icon: Icon(Icons.arrow_forward, size: 18.r),
                            label: Text(
                              'View All',
                              style: getTextTheme().labelMedium,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      allRequests.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.w),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox,
                                      size: 64.r,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'No leave requests yet',
                                      style: getTextTheme().titleMedium
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: allRequests.length > 5
                                  ? 5
                                  : allRequests.length,
                              itemBuilder: (context, index) {
                                final request = allRequests[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    side: BorderSide(
                                      color: request.status == 'pending'
                                          ? Colors.orange.withOpacity(0.5)
                                          : request.status == 'approved'
                                          ? Colors.green.withOpacity(0.5)
                                          : Colors.red.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(12.w),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                request.userName,
                                                style: getTextTheme().titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            _getStatusChip(request.status),
                                          ],
                                        ),
                                        SizedBox(height: 8.h),
                                        Text(
                                          'From: ${_formatDate(request.fromDate!)} To: ${_formatDate(request.toDate!)}',
                                          style: getTextTheme().bodyMedium,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          'Reason: ${request.reason}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: getTextTheme().bodyMedium,
                                        ),
                                        SizedBox(height: 8.h),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () async {
                                              await Get.toNamed(
                                                '/leave_requests_screen',
                                              );
                                              if (mounted) _initializeData();
                                            },
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12.w,
                                                vertical: 8.h,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              'View Details',
                                              style: getTextTheme().labelMedium,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // Section Header
  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    bool showDivider = true,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24.r, color: Colors.indigo),
        SizedBox(width: 8.w),
        Text(
          title,
          style: getTextTheme().titleLarge?.copyWith(color: Colors.black87),
        ),
      ],
    );
  }

  // Employee Statistics Card with Pie Chart
  Widget _buildEmployeeStatsCard(EmployeeManagementProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: provider.totalEmployees > 0
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pie Chart with Total in Center
                  SizedBox(
                    width: 140.w,
                    height: 140.h,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40.r,
                            sections: [
                              PieChartSectionData(
                                value: provider.onboardedEmployees.toDouble(),
                                title: '${provider.onboardedEmployees}',
                                color: Colors.green,
                                radius: 35.r,
                                titleStyle: getTextTheme().bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                value: provider.pendingEmployees.toDouble(),
                                title: '${provider.pendingEmployees}',
                                color: Colors.orange,
                                radius: 35.r,
                                titleStyle: getTextTheme().bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Total Count in Center
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isAnimated
                                ? AnimatedNumber(
                                    startValue:
                                        provider.totalEmployees.toDouble() / 2,
                                    endValue: provider.totalEmployees
                                        .toDouble(),
                                    duration: const Duration(seconds: 1),
                                    isFloatingPoint: false,
                                    style: getTextTheme().displayMedium
                                        ?.copyWith(color: Colors.indigo),
                                  )
                                : Text(
                                    provider.totalEmployees.toString(),
                                    style: getTextTheme().displayMedium
                                        ?.copyWith(color: Colors.indigo),
                                  ),
                            SizedBox(height: 2.h),
                            Text(
                              'Total',
                              style: getTextTheme().bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Legend
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendItem('Onboarded', Colors.green),
                      SizedBox(height: 12.h),
                      _buildLegendItem('Pending', Colors.orange),
                    ],
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.all(40.w),
                child: Text(
                  'No employee data available',
                  style: getTextTheme().bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
      ),
    );
  }

  // Legend Item
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16.w,
          height: 16.h,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: getTextTheme().bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Leave Requests Statistics Card - Compact Version
  Widget _buildLeaveRequestsStatsCard(
    int total,
    int pending,
    int approved,
    int rejected,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Stats Row with Animated Numbers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactStatItem(
                  'Total',
                  total,
                  Colors.blue,
                  Icons.list_alt,
                ),
                _buildCompactStatItem(
                  'Pending',
                  pending,
                  Colors.orange,
                  Icons.pending_actions,
                ),
                _buildCompactStatItem(
                  'Approved',
                  approved,
                  Colors.green,
                  Icons.check_circle,
                ),
                _buildCompactStatItem(
                  'Rejected',
                  rejected,
                  Colors.red,
                  Icons.cancel,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            // Compact Bar Chart
            if (total > 0)
              SizedBox(
                height: 140.h,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: total.toDouble() * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return Text(
                                  'Pending',
                                  style: getTextTheme().bodySmall,
                                );
                              case 1:
                                return Text(
                                  'Approved',
                                  style: getTextTheme().bodySmall,
                                );
                              case 2:
                                return Text(
                                  'Rejected',
                                  style: getTextTheme().bodySmall,
                                );
                              default:
                                return const Text('');
                            }
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: getTextTheme().bodySmall?.copyWith(
                                fontSize: 10.sp,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: pending.toDouble(),
                            color: Colors.orange,
                            width: 30,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: approved.toDouble(),
                            color: Colors.green,
                            width: 30,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: rejected.toDouble(),
                            color: Colors.red,
                            width: 30,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Compact Stat Item (for Leave Requests)
  Widget _buildCompactStatItem(
    String label,
    int value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 25.r),
        SizedBox(height: 4.h),
        isAnimated
            ? AnimatedNumber(
                startValue: value.toDouble() / 2,
                endValue: value.toDouble(),
                duration: const Duration(seconds: 1),
                isFloatingPoint: false,
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 18.sp,
                ),
              )
            : Text(
                value.toString(),
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: getTextTheme().bodyMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  // Action Card
  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32.r),
            SizedBox(height: 12.h),
            Text(
              title,
              style: getTextTheme().labelLarge?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: getTextTheme().labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
