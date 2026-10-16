import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../app_constants.dart';
import '../../models/request_model.dart';
import '../../widgets/leave_balance_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/user_home_provider.dart';
import '../../services/notification_service.dart';
import '../../providers/calendar_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/birthday_banner.dart';
import '../../widgets/quick_action_tile.dart';
import '../../widgets/request_card.dart';
import '../../widgets/attendance_calendar_card.dart';
import '../../widgets/holiday_calendar_card.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../constants/app_theme.dart';
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

      logDebug(
        'User Location - Latitude: ${position.latitude}, Longitude: ${position.longitude}',
      );
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
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
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
                  padding: AppSpacing.screen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section
                      NeuCard(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22.r,
                              backgroundColor: ConstColors.lightShade,
                              child: Text(
                                authProvider.userModel!.name.isNotEmpty
                                    ? authProvider.userModel!.name[0]
                                          .toUpperCase()
                                    : '?',
                                style: getTextTheme().displayMedium?.copyWith(
                                  color: ConstColors.primaryDeep,
                                  fontWeight: FontWeight.bold,
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
                                    authProvider.userModel!.name,
                                    style: getTextTheme().titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
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
                          color: ConstColors.textColor,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              'Apply Leave',
                              Icons.event_available,
                              () async {
                                await Get.toNamed('/apply_leave_screen');
                                _initializeStream();
                              },
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _buildActionCard(
                              'Leave History',
                              Icons.history,
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
                              color: ConstColors.textColor,
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
                      // Grows to fit the list or the empty message, up to 300
                      // Full width, so the empty message is centred in it
                      SizedBox(
                        width: double.infinity,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 300.h),
                          child:
                              context
                                      .watch<UserHomeProvider>()
                                      .requestsStream ==
                                  null
                              ? const Center(
                                  child: AppLoadingIndicator(size: 30),
                                )
                              : StreamBuilder<List<RequestModel>>(
                                  stream: context
                                      .watch<UserHomeProvider>()
                                      .requestsStream,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Center(
                                        child: AppLoadingIndicator(size: 30),
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
                                              color:
                                                  ConstColors.inProgressOrange,
                                            ),
                                            SizedBox(height: 12.h),
                                            Text(
                                              errorMessage,
                                              style: getTextTheme().bodyMedium
                                                  ?.copyWith(
                                                    color: ConstColors
                                                        .textColorLight,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 12.h),
                                            ConstantButton(
                                              text: 'Try Again',
                                              onPressed: _initializeStream,
                                              icon: Icon(
                                                Icons.refresh,
                                                size: 20.r,
                                                color: ConstColors.textColor,
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
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                        child: Center(
                                          child: Column(
                                            // mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.pending_actions,
                                                size: 64.r,
                                                color: ConstColors.darkGrey,
                                              ),
                                              SizedBox(height: 16.h),
                                              Text(
                                                'No pending requests',
                                                style: getTextTheme()
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: ConstColors
                                                          .textColorLight,
                                                    ),
                                              ),
                                            ],
                                          ),
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
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: 64.r,
                                              color: ConstColors.successGreen,
                                            ),
                                            SizedBox(height: 16.h),
                                            Text(
                                              'No pending requests',
                                              style: getTextTheme().titleMedium
                                                  ?.copyWith(
                                                    color: ConstColors
                                                        .textColorLight,
                                                  ),
                                            ),
                                            SizedBox(height: 8.h),
                                            Text(
                                              'All requests have been processed',
                                              style: getTextTheme().bodySmall
                                                  ?.copyWith(
                                                    color: ConstColors
                                                        .textColorLight,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      shrinkWrap: true,
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
      return NeuCard(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 40.h),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLoadingIndicator(size: 40),
                SizedBox(height: 16.h),
                Text(
                  'Loading leave balances...',
                  style: getTextTheme().bodyMedium?.copyWith(
                    color: ConstColors.textColorLight,
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
      return NeuCard(
        color: ConstColors.inProgressOrange.withValues(alpha: 0.12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: ConstColors.inProgressOrange,
                size: 48.r,
              ),
              SizedBox(height: 12.h),
              Text(
                'No Leave Data Available',
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Contact admin to allocate leaves',
                style: getTextTheme().bodyMedium?.copyWith(
                  color: ConstColors.textColorLight,
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
            color: ConstColors.textColor,
          ),
        ),
        SizedBox(height: 16.h),
        LeaveBalanceCard(
          model: balances,
          animation: _animationController,
          requests: context.watch<RequestProvider>(),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return QuickActionTile(title: title, icon: icon, onTap: onTap);
  }
}
