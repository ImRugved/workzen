import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animated_number/animated_number.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../models/request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/dot_indicator.dart';
import '../../app_constants.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../utils/logger.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({Key? key}) : super(key: key);

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  Stream<List<RequestModel>>? _leavesStream;
  final bool isAnimated = true; // Default to true, can be changed
  int _currentCarouselIndex = 0; // Track current carousel index

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      _initializeNotifications();
      _requestLocationAndStore();
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

  Future<void> _requestLocationAndStore() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logDebug('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          logDebug('Location permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        logDebug('Location permission permanently denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final storage = GetStorage();
      await storage.write('latitude', position.latitude);
      await storage.write('longitude', position.longitude);

      logDebug(
        'Admin Location - Latitude: ${position.latitude}, Longitude: ${position.longitude}',
      );
    } catch (e) {
      logDebug('Error getting location: $e');
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
          style: getTextTheme().titleMedium?.copyWith(color: Colors.white),
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
                  padding: EdgeInsets.all(10.w),
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
                        padding: EdgeInsets.all(15.w),
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
                      SizedBox(height: 20.h),

                      // Employee Statistics Section with Carousel
                      _buildSectionHeader(
                        _getCarouselSectionTitle(allRequests),
                        Icons.people,
                      ),
                      SizedBox(height: 12.h),
                      _buildOverviewCarousel(employeeProvider, allRequests),
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
                                        // Leave Type (only for leave requests)
                                        if (request.isLeaveRequest &&
                                            request.additionalData?['leaveType'] !=
                                                null)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 8.h,
                                            ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getLeaveTypeColor(
                                                  request
                                                      .additionalData!['leaveType'],
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6.r),
                                                border: Border.all(
                                                  color: _getLeaveTypeColor(
                                                    request
                                                        .additionalData!['leaveType'],
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                _getLeaveTypeFullName(
                                                  request
                                                      .additionalData!['leaveType'],
                                                ),
                                                style: getTextTheme()
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: _getLeaveTypeColor(
                                                        request
                                                            .additionalData!['leaveType'],
                                                      ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ),
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

  // Get section title based on current carousel index
  String _getCarouselSectionTitle(List<RequestModel> allRequests) {
    // Count pending leave requests to determine if leave chart exists
    final pendingLeaveRequests = allRequests
        .where(
          (r) =>
              r.type == AppConstants.requestTypeLeave &&
              r.status == AppConstants.statusPending,
        )
        .toList();

    int plCount = 0;
    int slCount = 0;
    int clCount = 0;

    for (var request in pendingLeaveRequests) {
      final leaveType = request.additionalData?['leaveType'] as String?;
      if (leaveType != null) {
        switch (leaveType.toLowerCase()) {
          case 'pl':
            plCount++;
            break;
          case 'sl':
            slCount++;
            break;
          case 'cl':
            clCount++;
            break;
        }
      }
    }

    final totalPendingLeaves = plCount + slCount + clCount;
    final hasLeaveChart = totalPendingLeaves > 0;

    // If only one chart (employee chart), always show "Employee Overview"
    if (!hasLeaveChart) {
      return 'Employee Overview';
    }

    // If two charts, show based on current index
    if (_currentCarouselIndex == 0) {
      return 'Onboarding Overview';
    } else {
      return 'Leave Request Overview';
    }
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

  // Overview Carousel with Employee and Leave Type Charts
  Widget _buildOverviewCarousel(
    EmployeeManagementProvider employeeProvider,
    List<RequestModel> allRequests,
  ) {
    // Count only PENDING leave requests by type
    final pendingLeaveRequests = allRequests
        .where(
          (r) =>
              r.type == AppConstants.requestTypeLeave &&
              r.status == AppConstants.statusPending,
        )
        .toList();

    int plCount = 0;
    int slCount = 0;
    int clCount = 0;

    for (var request in pendingLeaveRequests) {
      final leaveType = request.additionalData?['leaveType'] as String?;
      if (leaveType != null) {
        switch (leaveType.toLowerCase()) {
          case 'pl':
            plCount++;
            break;
          case 'sl':
            slCount++;
            break;
          case 'cl':
            clCount++;
            break;
        }
      }
    }

    final totalPendingLeaves = plCount + slCount + clCount;

    // Build items list - always include employee chart
    List<Widget> carouselItems = [
      SizedBox(
        width: double.infinity,
        child: _buildEmployeeChartCard(employeeProvider),
      ),
    ];

    // Only add leave type chart if there are pending leave requests
    if (totalPendingLeaves > 0) {
      carouselItems.add(
        SizedBox(
          width: double.infinity,
          child: _buildLeaveTypeChartCard(
            plCount,
            slCount,
            clCount,
            totalPendingLeaves,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: CarouselSlider(
            options: CarouselOptions(
              height: 160.h,
              autoPlay:
                  carouselItems.length >
                  1, // Only auto-play if more than one item
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              enlargeCenterPage: false,
              viewportFraction: 1.0,
              enableInfiniteScroll: carouselItems.length > 1,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
            ),
            items: carouselItems,
          ),
        ),
        SizedBox(height: 8.h),
        // Dot Indicator
        DotIndicator(
          itemCount: carouselItems.length,
          currentIndex: _currentCarouselIndex,
        ),
      ],
    );
  }

  // Employee Statistics Card with Pie Chart
  Widget _buildEmployeeChartCard(EmployeeManagementProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: provider.totalEmployees > 0
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Chart and Total in Center
                  SizedBox(
                    width: 120.w,
                    height: 110.h,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 28.r,
                            sections: [
                              PieChartSectionData(
                                value: provider.onboardedEmployees.toDouble(),
                                title: '${provider.onboardedEmployees}',
                                color: ConstColors.successGreen,
                                radius: 25.r,
                                titleStyle: getTextTheme().bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ConstColors.white,
                                  fontSize: 11.sp,
                                ),
                              ),
                              PieChartSectionData(
                                value: provider.pendingEmployees.toDouble(),
                                title: '${provider.pendingEmployees}',
                                color: ConstColors.warningAmber,
                                radius: 25.r,
                                titleStyle: getTextTheme().bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ConstColors.white,
                                  fontSize: 11.sp,
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
                                    style: getTextTheme().titleMedium?.copyWith(
                                      color: ConstColors.primary,
                                    ),
                                  )
                                : Text(
                                    provider.totalEmployees.toString(),
                                    style: getTextTheme().titleMedium?.copyWith(
                                      color: ConstColors.primary,
                                    ),
                                  ),
                            SizedBox(height: 2.h),
                            Text(
                              'Total',
                              style: getTextTheme().labelSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: ConstColors.textColorLight,
                                fontSize: 9.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Legend next to chart
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('Onboarded', ConstColors.successGreen),
                      SizedBox(height: 12.h),
                      _buildLegendItem('Pending', ConstColors.warningAmber),
                    ],
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.all(20.w),
                child: Text(
                  'No employee data available',
                  style: getTextTheme().bodyMedium?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ),
      ),
    );
  }

  // Leave Type Chart Card (PL, SL, CL)
  Widget _buildLeaveTypeChartCard(
    int plCount,
    int slCount,
    int clCount,
    int totalLeaves,
  ) {
    // Count how many distinct leave types have requests
    final activeTypes = [
      if (plCount > 0)
        {
          'label': 'Privilege Leave (PL)',
          'short': 'PL',
          'count': plCount,
          'color': ConstColors.infoBlue,
        },
      if (slCount > 0)
        {
          'label': 'Sick Leave (SL)',
          'short': 'SL',
          'count': slCount,
          'color': ConstColors.successGreen,
        },
      if (clCount > 0)
        {
          'label': 'Casual Leave (CL)',
          'short': 'CL',
          'count': clCount,
          'color': ConstColors.inProgressOrange,
        },
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: totalLeaves > 0
            ? activeTypes.length == 1
                  // Single leave type — show a clean stat layout instead of pie chart
                  ? _buildSingleLeaveTypeLayout(activeTypes.first)
                  // Multiple leave types — show pie chart
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Chart and Total in Center
                        SizedBox(
                          width: 120.w,
                          height: 110.h,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 28.r,
                                  sections: [
                                    if (plCount > 0)
                                      PieChartSectionData(
                                        value: plCount.toDouble(),
                                        title: '$plCount',
                                        color: ConstColors.infoBlue,
                                        radius: 25.r,
                                        titleStyle: getTextTheme().bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: ConstColors.white,
                                              fontSize: 11.sp,
                                            ),
                                      ),
                                    if (slCount > 0)
                                      PieChartSectionData(
                                        value: slCount.toDouble(),
                                        title: '$slCount',
                                        color: ConstColors.successGreen,
                                        radius: 25.r,
                                        titleStyle: getTextTheme().bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: ConstColors.white,
                                              fontSize: 11.sp,
                                            ),
                                      ),
                                    if (clCount > 0)
                                      PieChartSectionData(
                                        value: clCount.toDouble(),
                                        title: '$clCount',
                                        color: ConstColors.inProgressOrange,
                                        radius: 25.r,
                                        titleStyle: getTextTheme().bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: ConstColors.white,
                                              fontSize: 11.sp,
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
                                              totalLeaves.toDouble() / 2,
                                          endValue: totalLeaves.toDouble(),
                                          duration: const Duration(seconds: 1),
                                          isFloatingPoint: false,
                                          style: getTextTheme().titleMedium
                                              ?.copyWith(
                                                color: ConstColors.primary,
                                              ),
                                        )
                                      : Text(
                                          totalLeaves.toString(),
                                          style: getTextTheme().titleMedium
                                              ?.copyWith(
                                                color: ConstColors.primary,
                                              ),
                                        ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Total',
                                    style: getTextTheme().labelSmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: ConstColors.textColorLight,
                                      fontSize: 9.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16.w),
                        // Legend next to chart
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (plCount > 0)
                              _buildLegendItem('PL', ConstColors.infoBlue),
                            if (plCount > 0 && (slCount > 0 || clCount > 0))
                              SizedBox(height: 10.h),
                            if (slCount > 0)
                              _buildLegendItem('SL', ConstColors.successGreen),
                            if (slCount > 0 && clCount > 0)
                              SizedBox(height: 10.h),
                            if (clCount > 0)
                              _buildLegendItem(
                                'CL',
                                ConstColors.inProgressOrange,
                              ),
                          ],
                        ),
                      ],
                    )
            : Padding(
                padding: EdgeInsets.all(20.w),
                child: Text(
                  'No leave requests available',
                  style: getTextTheme().bodyMedium?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ),
      ),
    );
  }

  // Layout for when only a single leave type has pending requests
  Widget _buildSingleLeaveTypeLayout(Map<String, dynamic> leaveType) {
    final String label = leaveType['label'] as String;
    final String shortLabel = leaveType['short'] as String;
    final int count = leaveType['count'] as int;
    final Color color = leaveType['color'] as Color;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Colored circle with count
        Container(
          width: 90.w,
          height: 90.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                isAnimated
                    ? AnimatedNumber(
                        startValue: count.toDouble() / 2,
                        endValue: count.toDouble(),
                        duration: const Duration(seconds: 1),
                        isFloatingPoint: false,
                        style: getTextTheme().headlineSmall?.copyWith(
                          color: ConstColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Text(
                        count.toString(),
                        style: getTextTheme().headlineSmall?.copyWith(
                          color: ConstColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                Text(
                  'Pending',
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.white.withOpacity(0.9),
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 20.w),
        // Leave type info
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              shortLabel,
              style: getTextTheme().titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                '$count pending request${count > 1 ? 's' : ''}',
                style: getTextTheme().labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
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

  String _getLeaveTypeFullName(String leaveType) {
    switch (leaveType.toLowerCase()) {
      case AppConstants.leaveTypePL:
        return 'Privilege Leave (PL)';
      case AppConstants.leaveTypeSL:
        return 'Sick Leave (SL)';
      case AppConstants.leaveTypeCL:
        return 'Casual Leave (CL)';
      default:
        return '${leaveType.toUpperCase()} (${leaveType.toUpperCase()})';
    }
  }

  Color _getLeaveTypeColor(String leaveType) {
    switch (leaveType.toLowerCase()) {
      case AppConstants.leaveTypePL:
        return ConstColors.infoBlue;
      case AppConstants.leaveTypeSL:
        return ConstColors.successGreen;
      case AppConstants.leaveTypeCL:
        return ConstColors.inProgressOrange;
      default:
        return Colors.grey;
    }
  }
}
