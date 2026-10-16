import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animated_number/animated_number.dart';
import '../../app_constants.dart';
import '../../models/request_model.dart';
import '../../models/leave_balance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/user_home_provider.dart';
import '../../services/notification_service.dart';
import '../../providers/calendar_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/request_card.dart';
import '../../widgets/attendance_calendar_card.dart';
import '../../widgets/holiday_calendar_card.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../utils/logger.dart';

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with TickerProviderStateMixin {
  // Requests stream and leave balances live in this scoped provider
  final UserHomeProvider _home = UserHomeProvider();
  late AnimationController _animationController;
  // Reloads the leave balances when an admin decides a request
  StreamSubscription<void>? _balanceSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Use WidgetsBinding to defer the data loading after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStream();
      _initializeNotifications();
      _loadLeaveBalances();
      _listenForBalanceChanges();
      _requestLocationAndStore();
      // Animation will start after leave balances are loaded
    });
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _animationController.dispose();
    _home.dispose();
    super.dispose();
  }

  void _initializeStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    if (authProvider.userModel != null) {
      // Leave and comp off requests together
      _home.setRequestsStream(
        requestProvider
            .getUserRequestsStream(authProvider.userModel!.id)
            .map(
              (requests) => requests
                  .where((r) => r.isLeaveRequest || r.isCompOffRequest)
                  .toList(),
            ),
      );
    }
  }

  void _listenForBalanceChanges() {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;

    _balanceSubscription?.cancel();
    _balanceSubscription = context
        .read<RequestProvider>()
        .leaveBalanceChanges(user.id)
        .listen((_) {
          if (mounted) _loadLeaveBalances();
        });
  }

  Future<void> _loadLeaveBalances() async {
    // Only shows loading if data hasn't been loaded before
    _home.startLoadingBalances();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    if (authProvider.userModel != null) {
      final balances = await requestProvider.getUserLeaveBalances(
        authProvider.userModel!.id,
      );

      // Marked as loaded even when there is no data
      _home.setBalances(balances);
      // Start animation after data is loaded (only first time)
      if (balances != null &&
          _animationController.status != AnimationStatus.completed) {
        _animationController.forward();
      }
    }
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
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logDebug('Location services are disabled.');
        return;
      }

      // Check and request permission
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

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Store in GetStorage
      final storage = GetStorage();
      await storage.write('latitude', position.latitude);
      await storage.write('longitude', position.longitude);

      logDebug('User Location - Latitude: ${position.latitude}, Longitude: ${position.longitude}');
    } catch (e) {
      logDebug('Error getting location: $e');
    }
  }

  Future<void> _onRefresh() async {
    // Refresh stream, leave balances and the attendance calendar
    _initializeStream();
    await Future.wait([
      _loadLeaveBalances(),
      Provider.of<CalendarProvider>(context, listen: false).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _home,
      child: Builder(builder: _buildScreen),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'User Dashboard',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r),
            onPressed: _initializeStream,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: authProvider.userModel == null
          ? const Center(child: AppLoadingIndicator(size: 40))
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.indigo.shade600,
                              Colors.indigo.shade400,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.w),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 35.r,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    authProvider.userModel!.name.isNotEmpty
                                        ? authProvider.userModel!.name[0]
                                              .toUpperCase()
                                        : '?',
                                    style: getTextTheme().displayMedium
                                        ?.copyWith(
                                          color: Colors.indigo.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome Back! 👋',
                                      style: getTextTheme().bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                          ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      authProvider.userModel!.name,
                                      style: getTextTheme().titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.email_outlined,
                                          size: 14.r,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                        SizedBox(width: 4.w),
                                        Expanded(
                                          child: Text(
                                            authProvider.userModel!.email,
                                            style: getTextTheme().bodySmall
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Today's punch times and the month attendance calendar
                      const AttendanceCalendarCard(),
                      SizedBox(height: 24.h),

                      // Leave Balance Section
                      Consumer<UserHomeProvider>(
                        builder: (context, home, _) =>
                            _buildLeaveBalanceSection(home),
                      ),
                      SizedBox(height: 24.h),

                      // Quick Actions
                      Text(
                        'Quick Actions',
                        style: getTextTheme().titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              context,
                              'Apply Leave',
                              Icons.event_available,
                              Colors.blue,
                              () async {
                                await Get.toNamed('/apply_leave_screen');
                                _initializeStream();
                              },
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: _buildActionCard(
                              context,
                              'Leave History',
                              Icons.history,
                              Colors.purple,
                              () async {
                                await Get.toNamed('/leave_history_screen');
                                _initializeStream();
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
                          Text(
                            'Recent Requests',
                            style: getTextTheme().titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Get.toNamed('/leave_history_screen');
                              _initializeStream();
                            },
                            child: Text(
                              'View All',
                              style: getTextTheme().labelMedium,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),

                      // Requests list with StreamBuilder (Pending only)
                      SizedBox(
                        height: 300.h,
                        child: context
                                    .watch<UserHomeProvider>()
                                    .requestsStream ==
                                null
                            ? const Center(child: AppLoadingIndicator(size: 40))
                            : StreamBuilder<List<RequestModel>>(
                                stream: context
                                    .watch<UserHomeProvider>()
                                    .requestsStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: AppLoadingIndicator(size: 40),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    // Handle different types of errors with user-friendly messages
                                    String errorMessage =
                                        'Unable to load your requests at the moment.';

                                    if (snapshot.error.toString().contains(
                                          'permission-denied',
                                        ) ||
                                        snapshot.error.toString().contains(
                                          'PERMISSION_DENIED',
                                        )) {
                                      errorMessage =
                                          'Access denied. Please check your account permissions.';
                                    } else if (snapshot.error
                                            .toString()
                                            .contains('network') ||
                                        snapshot.error.toString().contains(
                                          'connection',
                                        )) {
                                      errorMessage =
                                          'Network error. Please check your internet connection.';
                                    }

                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 48.r,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(height: 12.h),
                                          Text(
                                            errorMessage,
                                            style: getTextTheme().bodyMedium
                                                ?.copyWith(color: Colors.grey),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: 12.h),
                                          ConstantButton(
                                            text: 'Try Again',
                                            onPressed: _initializeStream,
                                            icon: Icon(
                                              Icons.refresh,
                                              size: 20.r,
                                              color: ConstColors.white,
                                            ),
                                            isFullWidth: false,
                                            height: 40.h,
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.pending_actions,
                                            size: 64.r,
                                            color: Colors.grey[400],
                                          ),
                                          SizedBox(height: 16.h),
                                          Text(
                                            'No pending requests',
                                            style: getTextTheme().titleMedium
                                                ?.copyWith(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // Filter only pending requests
                                  final allRequests = snapshot.data!;
                                  final requests = allRequests
                                      .where(
                                        (request) =>
                                            request.status == 'pending',
                                      )
                                      .toList();

                                  // If no pending requests
                                  if (requests.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 64.r,
                                            color: Colors.green[400],
                                          ),
                                          SizedBox(height: 16.h),
                                          Text(
                                            'No pending requests',
                                            style: getTextTheme().titleMedium
                                                ?.copyWith(color: Colors.grey),
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            'All requests have been processed',
                                            style: getTextTheme().bodySmall
                                                ?.copyWith(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    itemCount: requests.length > 3
                                        ? 3
                                        : requests.length,
                                    // Same card as leave history and the admin
                                    itemBuilder: (context, index) =>
                                        RequestCard(request: requests[index]),
                                  );
                                },
                              ),
                      ),
                      SizedBox(height: 16.h),
                      const HolidayCalendarCard(),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLeaveBalanceSection(UserHomeProvider home) {
    // Only show loading indicator on first load
    if (home.showBalanceLoading) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(40.w),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLoadingIndicator(size: 40),
                SizedBox(height: 16.h),
                Text(
                  'Loading leave balances...',
                  style: getTextTheme().bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If still loading but has loaded before, show previous data or empty state
    final balances = home.balances;
    if (balances == null || !balances.hasAnyLeaves) {
      return Card(
        elevation: 3,
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 48.r),
              SizedBox(height: 12.h),
              Text(
                'No Leave Data Available',
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Contact admin to allocate leaves',
                style: getTextTheme().bodyMedium?.copyWith(
                  color: Colors.orange.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave Balance',
          style: getTextTheme().titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16.h),
        _buildLeaveBalanceCard(balances),
      ],
    );
  }

  Widget _buildLeaveBalanceCard(LeaveBalanceModel model) {
    final plTotal = model.plTotal;
    final plUsed = model.plUsed;
    final plBalance = model.plBalance;

    final slTotal = model.slTotal;
    final slUsed = model.slUsed;
    final slBalance = model.slBalance;

    final clTotal = model.clTotal;
    final clUsed = model.clUsed;
    final clBalance = model.clBalance;

    final totalAssigned = model.totalAllocated;
    final totalUsed = model.totalUsed;
    final totalBalance = model.totalBalance;

    // Comp off credit earned from approved comp off requests (not yearly)
    final requests = context.watch<RequestProvider>();
    final coEarned = requests.compOffEarned;
    final coUsed = requests.compOffUsed;
    final coBalance = requests.compOffBalance;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
        child: Column(
          children: [
            // Total Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnimatedStatBox(
                  'Total',
                  totalAssigned,
                  Colors.indigo,
                  Icons.event_note,
                ),
                _buildAnimatedStatBox(
                  'Used',
                  totalUsed,
                  Colors.orange,
                  Icons.event_busy,
                ),
                _buildAnimatedStatBox(
                  'Balance',
                  totalBalance,
                  Colors.green,
                  Icons.event_available,
                ),
              ],
            ),
            SizedBox(height: 5.h),

            // Pie Chart with Legend Side by Side
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pie Chart
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 140.h,
                    child: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 30.r,
                              sections: [
                                if (plBalance > 0)
                                  PieChartSectionData(
                                    value:
                                        plBalance.toDouble() *
                                        _animationController.value,
                                    title: 'PL\n$plBalance',
                                    color: Colors.blue,
                                    radius: 50.r,
                                    titleStyle: getTextTheme().labelSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                if (slBalance > 0)
                                  PieChartSectionData(
                                    value:
                                        slBalance.toDouble() *
                                        _animationController.value,
                                    title: 'SL\n$slBalance',
                                    color: Colors.green,
                                    radius: 50.r,
                                    titleStyle: getTextTheme().labelSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                if (clBalance > 0)
                                  PieChartSectionData(
                                    value:
                                        clBalance.toDouble() *
                                        _animationController.value,
                                    title: 'CL\n$clBalance',
                                    color: Colors.orange,
                                    radius: 50.r,
                                    titleStyle: getTextTheme().labelSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                if (coBalance > 0)
                                  PieChartSectionData(
                                    value:
                                        coBalance * _animationController.value,
                                    title: 'CO\n${_count(coBalance)}',
                                    color: Colors.teal,
                                    radius: 50.r,
                                    titleStyle: getTextTheme().labelSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 20.w), // Legend
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (plTotal > 0)
                        _buildCompactLegendItem(
                          'Privilege Leave',
                          plTotal,
                          plUsed,
                          plBalance,
                          Colors.blue,
                        ),
                      if (plTotal > 0) SizedBox(height: 14.h),
                      if (slTotal > 0)
                        _buildCompactLegendItem(
                          'Sick Leave',
                          slTotal,
                          slUsed,
                          slBalance,
                          Colors.green,
                        ),
                      if (slTotal > 0) SizedBox(height: 14.h),
                      if (clTotal > 0)
                        _buildCompactLegendItem(
                          'Casual Leave',
                          clTotal,
                          clUsed,
                          clBalance,
                          Colors.orange,
                        ),
                      if (coEarned > 0) ...[
                        SizedBox(height: 14.h),
                        _buildCompactLegendItem(
                          'Comp Off',
                          coEarned,
                          coUsed,
                          coBalance,
                          Colors.teal,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedStatBox(
    String label,
    int value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28.r),
        SizedBox(height: 8.h),
        AnimatedNumber(
          startValue: 0,
          endValue: value.toDouble(),
          duration: const Duration(milliseconds: 1500),
          isFloatingPoint: false,
          style: getTextTheme().headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: getTextTheme().labelMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // 2 for whole days, 1.5 for a half day
  String _count(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

  Widget _buildCompactLegendItem(
    String type,
    num total,
    num used,
    num balance,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
        SizedBox(width: 6.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type,
              style: getTextTheme().labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              'Used: ${_count(used)} | Bal: ${_count(balance)}',
              style: getTextTheme().labelSmall?.copyWith(
                // fontSize: 9.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 100.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decorative circle
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 70.w,
                height: 70.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(icon, size: 22.r, color: Colors.white),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    title,
                    style: getTextTheme().titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Tap to access',
                          style: getTextTheme().bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 9.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.arrow_forward,
                        size: 10.r,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
