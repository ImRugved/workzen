import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/birthday_banner.dart';
import '../../widgets/donut_stat_card.dart';
import '../../widgets/quick_action_tile.dart';
import '../../widgets/request_type_style.dart';
import '../../widgets/holiday_calendar_card.dart';
import '../../app_constants.dart';
import '../../providers/value_provider.dart';
import '../../widgets/attendance_calendar_card.dart';
import '../../constants/permissions.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../constants/app_theme.dart';
import '../../constants/constant_button.dart';
import '../../utils/logger.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({Key? key}) : super(key: key);

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  // Both are scoped state holders, so this screen needs no setState
  final ValueProvider<Stream<List<RequestModel>>?> _leavesStream =
      ValueProvider<Stream<List<RequestModel>>?>(null);

  @override
  void dispose() {
    _leavesStream.dispose();
    super.dispose();
  }

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

    // Only someone allowed to see leave requests may read them all
    final canSeeRequests = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).can(Permissions.leaveRequests);

    _leavesStream.value = canSeeRequests
        ? requestProvider.getAllRequestsStream()
        : Stream.value(<RequestModel>[]);

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _leavesStream),
      ],
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final employeeProvider = Provider.of<EmployeeManagementProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Dashboard Panel',
          style: getTextTheme().titleMedium?.copyWith(
            color: ConstColors.textColor,
          ),
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
          ? const Center(child: AppLoadingIndicator(size: 40))
          : StreamBuilder<List<RequestModel>>(
              stream: context
                  .watch<ValueProvider<Stream<List<RequestModel>>?>>()
                  .value,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppLoadingIndicator(size: 40));
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
                          color: ConstColors.inProgressOrange,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          errorMessage,
                          style: getTextTheme().bodyLarge?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                        ConstantButton(
                          text: 'Try Again',
                          onPressed: _initializeData,
                          icon: Icon(
                            Icons.refresh,
                            size: 20.r,
                            color: ConstColors.textColor,
                          ),
                          isFullWidth: false,
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
                  padding: AppSpacing.screen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome card: white raised card, same as the user's
                      NeuCard(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: ConstColors.lightShade,
                              radius: 22.r,
                              child: Text(
                                authProvider.userModel?.name.isNotEmpty == true
                                    ? authProvider.userModel!.name[0]
                                          .toUpperCase()
                                    : "A",
                                style: getTextTheme().displayMedium?.copyWith(
                                  color: ConstColors.primaryDeep,
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
                                      color: ConstColors.textColorLight,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    authProvider.userModel?.name ?? "Admin",
                                    style: getTextTheme().titleLarge?.copyWith(
                                      color: ConstColors.textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Shown only when someone has a birthday today
                      const BirthdayBanner(),

                      // The admin's own punch times and month attendance calendar
                      const AttendanceCalendarCard(),
                      SizedBox(height: 20.h),

                      // Employee onboarding overview
                      _buildSectionHeader('Onboarding Overview', Icons.people),
                      SizedBox(height: 12.h),
                      _buildEmployeeChartCard(employeeProvider),
                      SizedBox(height: 24.h),

                      // Leave Requests Statistics Section
                      if (authProvider.can(Permissions.leaveRequests)) ...[
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
                      ],

                      // Quick Actions: only what this admin / sub admin may use
                      ..._buildQuickActions(authProvider),

                      // Recent Requests
                      if (authProvider.can(Permissions.leaveRequests)) ...[
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
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox,
                                      size: 50.r,
                                      color: ConstColors.borderColor,
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'No leave requests yet',
                                      style: getTextTheme().titleMedium
                                          ?.copyWith(
                                            color: ConstColors.textColorLight,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: allRequests.length > 5
                                    ? 5
                                    : allRequests.length,
                                itemBuilder: (context, index) {
                                  return _buildRecentRequestTile(
                                    allRequests[index],
                                  );
                                },
                              ),
                      ],
                      SizedBox(height: 16.h),
                      const HolidayCalendarCard(),
                      SizedBox(height: 16.h),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // Quick action cards the signed-in user is allowed to open, two per row
  List<Widget> _buildQuickActions(AuthProvider auth) {
    final actions = <Widget>[
      if (auth.can(Permissions.leaveRequests))
        _buildActionCard(
          'Manage Leaves',
          Icons.approval,
          () async {
            await Get.toNamed('/leave_requests_screen');
            if (mounted) _initializeData();
          },
        ),
      if (auth.can(Permissions.manageEmployees) ||
          auth.can(Permissions.addEmployee))
        _buildActionCard(
          'Employees',
          Icons.people,
          () async {
            await Get.toNamed('/employee_management_screen');
            if (mounted) _initializeData();
          },
        ),
      if (auth.can(Permissions.viewAttendance))
        _buildActionCard(
          'Attendance',
          Icons.access_time,
          () async {
            await Get.toNamed('/admin_attendance_screen');
            if (mounted) _initializeData();
          },
        ),
      if (auth.can(Permissions.onboarding))
        _buildActionCard(
          'Onboarding',
          Icons.person_add,
          () async {
            await Get.toNamed('/employee_onboarding_screen');
            if (mounted) _initializeData();
          },
        ),
    ];

    if (actions.isEmpty) return const [];

    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: actions[i]),
            SizedBox(width: 10.w),
            Expanded(
              child: i + 1 < actions.length
                  ? actions[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      rows.add(SizedBox(height: 10.h));
    }

    return [
      _buildSectionHeader('Quick Actions', Icons.touch_app),
      SizedBox(height: 12.h),
      ...rows,
      SizedBox(height: 14.h),
    ];
  }

  // Section Header
  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    bool showDivider = true,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24.r, color: ConstColors.primaryDeep),
        SizedBox(width: 8.w),
        Text(
          title,
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
      ],
    );
  }

  // Employee onboarding card
  Widget _buildEmployeeChartCard(EmployeeManagementProvider provider) {
    if (provider.totalEmployees == 0) {
      return SizedBox(
        width: double.infinity,
        child: NeuCard(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Text(
              'No employee data available',
              textAlign: TextAlign.center,
              style: getTextTheme().bodyMedium?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
          ),
        ),
      );
    }
    return DonutStatCard(
      centerLabel: 'Employees',
      items: [
        DonutStatItem(
          'Onboarded',
          provider.onboardedEmployees,
          ConstColors.successGreen,
        ),
        DonutStatItem(
          'Pending',
          provider.pendingEmployees,
          ConstColors.warningAmber,
        ),
      ],
    );
  }

  // Leave requests by status: same donut card as the other overviews
  Widget _buildLeaveRequestsStatsCard(
    int total,
    int pending,
    int approved,
    int rejected,
  ) {
    return DonutStatCard(
      centerLabel: 'Requests',
      items: [
        DonutStatItem('Pending', pending, ConstColors.inProgressOrange),
        DonutStatItem('Approved', approved, ConstColors.successGreen),
        DonutStatItem('Rejected', rejected, ConstColors.errorRed),
      ],
    );
  }

  // Action Card
  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return QuickActionTile(title: title, icon: icon, onTap: onTap);
  }

  Widget _getStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = ConstColors.inProgressOrange;
        label = 'Pending';
        break;
      case 'approved':
        color = ConstColors.successGreen;
        label = 'Approved';
        break;
      case 'rejected':
        color = ConstColors.errorRed;
        label = 'Rejected';
        break;
      default:
        color = ConstColors.textColorLight;
        label = 'Unknown';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
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

  // One recent request: type badge, who and what, status, one line of reason.
  // Same look as the request card, only smaller.
  Widget _buildRecentRequestTile(RequestModel request) {
    final style = RequestTypeStyle.of(request);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: NeuCard(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(NeuStyle.radiusMedium.r),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coloured edge shows the type at a glance
                Container(width: 4.w, color: style.color),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32.r,
                          height: 32.r,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: style.color),
                          ),
                          child: Text(
                            style.code,
                            style: getTextTheme().labelMedium?.copyWith(
                              color: style.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.userName,
                                overflow: TextOverflow.ellipsis,
                                style: getTextTheme().bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ConstColors.textColor,
                                ),
                              ),
                              Text(
                                '${style.name} · ${request.displayDate}',
                                overflow: TextOverflow.ellipsis,
                                style: getTextTheme().bodySmall?.copyWith(
                                  color: ConstColors.textColor,
                                ),
                              ),
                              if (request.reason.isNotEmpty)
                                Text(
                                  request.reason,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: getTextTheme().bodySmall?.copyWith(
                                    color: ConstColors.textColorLight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        _getStatusChip(request.status),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
