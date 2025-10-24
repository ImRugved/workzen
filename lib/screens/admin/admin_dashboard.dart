import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:workzen/models/leave_model.dart';
import '../../models/request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Stream<List<RequestModel>>? _leavesStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStream();
      _initializeNotifications();
    });
  }

  void _initializeStream() {
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );
    setState(() {
      _leavesStream = requestProvider.getAllRequestsStream();
    });
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
        title: const Text('Admin Dashboard Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeStream,
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
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _initializeStream,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }

                final allRequests = snapshot.data ?? [];

                // Count pending requests
                final pendingCount = allRequests
                    .where((request) => request.status == 'pending')
                    .length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo,
                                radius: 24,
                                child: Text(
                                  authProvider.userModel?.name.isNotEmpty ==
                                          true
                                      ? authProvider.userModel!.name[0]
                                            .toUpperCase()
                                      : "A",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Welcome,',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      authProvider.userModel?.name ?? "Admin",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      authProvider.userModel?.email ?? "",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildStatCard(
                              'Pending',
                              pendingCount.toString(),
                              Icons.pending_actions,
                              Colors.orange,
                              'Requests',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildStatCard(
                              'Total',
                              allRequests.length.toString(),
                              Icons.list_alt,
                              Colors.blue,
                              'Requests',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Actions
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          await Get.toNamed('/leave_requests_screen');
                          // Refresh the stream when returning from LeaveRequestsScreen
                          if (mounted) {
                            _initializeStream();
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.indigo, Colors.indigoAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.approval,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Manage Leave Requests',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Approve or reject pending requests',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Recent Requests
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text(
                                'Recent Leave Requests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await Get.toNamed('/leave_requests_screen');
                                // Refresh the stream when returning from LeaveRequestsScreen
                                if (mounted) {
                                  _initializeStream();
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      allRequests.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No leave requests yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
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
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
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
                                    padding: const EdgeInsets.all(12.0),
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
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _getStatusChip(request.status),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'From: ${_formatDate(request.fromDate!)} To: ${_formatDate(request.toDate!)}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reason: ${request.reason}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () async {
                                              await Get.toNamed(
                                                '/leave_requests_screen',
                                              );
                                              // Refresh the stream when returning from LeaveRequestsScreen
                                              if (mounted) {
                                                _initializeStream();
                                              }
                                            },
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text('View Details'),
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, [
    String? subtitle,
  ]) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
