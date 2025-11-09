import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../app_constants.dart';
import '../../models/request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';
import '../../constants/const_textstyle.dart';

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  Stream<List<RequestModel>>? _userLeavesStream;

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to defer the data loading after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStream();
      _initializeNotifications();
    });
  }

  void _initializeStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    if (authProvider.userModel != null) {
      setState(() {
        _userLeavesStream = requestProvider.getUserRequestsStream(
          authProvider.userModel!.id,
          type: AppConstants.requestTypeLeave,
        );
      });
    }
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
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30.r,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  authProvider.userModel!.name.isNotEmpty
                                      ? authProvider.userModel!.name[0]
                                            .toUpperCase()
                                      : '?',
                                  style: getTextTheme().displayMedium?.copyWith(
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, ${authProvider.userModel!.name}',
                                      style: getTextTheme().titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      authProvider.userModel!.email,
                                      style: getTextTheme().bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

                  // Recent Leave Requests
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Leave Requests',
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

                  // Leave requests list with StreamBuilder
                  Expanded(
                    child: _userLeavesStream == null
                        ? const Center(child: CircularProgressIndicator())
                        : StreamBuilder<List<RequestModel>>(
                            stream: _userLeavesStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                // Handle different types of errors with user-friendly messages
                                String errorMessage =
                                    'Unable to load your leave requests at the moment.';

                                if (snapshot.error.toString().contains(
                                      'permission-denied',
                                    ) ||
                                    snapshot.error.toString().contains(
                                      'PERMISSION_DENIED',
                                    )) {
                                  errorMessage =
                                      'Access denied. Please check your account permissions.';
                                } else if (snapshot.error.toString().contains(
                                      'network',
                                    ) ||
                                    snapshot.error.toString().contains(
                                      'connection',
                                    )) {
                                  errorMessage =
                                      'Network error. Please check your internet connection.';
                                }

                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                      ElevatedButton.icon(
                                        onPressed: _initializeStream,
                                        icon: Icon(Icons.refresh, size: 20.r),
                                        label: Text(
                                          'Try Again',
                                          style: getTextTheme().labelLarge,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16.w,
                                            vertical: 8.h,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.event_busy,
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
                                );
                              }

                              final requests = snapshot.data!;

                              return ListView.builder(
                                itemCount:
                                    requests.length > 3 ? 3 : requests.length,
                                itemBuilder: (context, index) {
                                  final request = requests[index];
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
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 8.h,
                                      ),
                                      title: Text(
                                        'From: ${_formatDate(request.fromDate!)} To: ${_formatDate(request.toDate!)}',
                                        style: getTextTheme()
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 4.h),
                                          Text(
                                            'Reason: ${request.reason}',
                                            style: getTextTheme().bodyMedium,
                                          ),
                                          SizedBox(height: 4.h),
                                          Row(
                                            children: [
                                              _buildStatusChip(request.status),
                                              if (request.adminRemark != null &&
                                                  request.adminRemark!.isNotEmpty)
                                                Expanded(
                                                  child: Padding(
                                                    padding: EdgeInsets.only(
                                                      left: 8.w,
                                                    ),
                                                    child: Text(
                                                      'Remark: ${request.adminRemark}',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: getTextTheme()
                                                          .bodySmall,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing:
                                          Icon(Icons.arrow_forward_ios, size: 16.r),
                                      onTap: () async {
                                        await Get.toNamed(
                                          '/leave_history_screen',
                                        );
                                        _initializeStream();
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
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
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40.r, color: color),
            SizedBox(height: 12.h),
            Text(
              title,
              style: getTextTheme().titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String statusText;

    switch (status) {
      case 'pending':
        chipColor = Colors.orange;
        statusText = 'Pending';
        break;
      case 'approved':
        chipColor = Colors.green;
        statusText = 'Approved';
        break;
      case 'rejected':
        chipColor = Colors.red;
        statusText = 'Rejected';
        break;
      default:
        chipColor = Colors.grey;
        statusText = 'Unknown';
    }

    return Chip(
      label: Text(
        statusText,
        style: getTextTheme().labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
      backgroundColor: chipColor,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0.h),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
