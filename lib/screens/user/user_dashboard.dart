import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/leave_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/app_drawer.dart';
import 'apply_leave_screen.dart';
import 'leave_history_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({Key? key}) : super(key: key);

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  Stream<List<LeaveModel>>? _userLeavesStream;

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to defer the data loading after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStream();
    });
  }

  void _initializeStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);

    if (authProvider.userModel != null) {
      setState(() {
        _userLeavesStream =
            leaveProvider.getUserLeavesStream(authProvider.userModel!.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  authProvider.userModel!.name.isNotEmpty
                                      ? authProvider.userModel!.name[0]
                                          .toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, ${authProvider.userModel!.name}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      authProvider.userModel!.email,
                                      style: TextStyle(
                                        fontSize: 16,
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          'Apply Leave',
                          Icons.event_available,
                          Colors.blue,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ApplyLeaveScreen(),
                              ),
                            ).then((_) => _initializeStream());
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          'Leave History',
                          Icons.history,
                          Colors.purple,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const LeaveHistoryScreen(),
                              ),
                            ).then((_) => _initializeStream());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent Leave Requests
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Leave Requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LeaveHistoryScreen(),
                            ),
                          ).then((_) => _initializeStream());
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Leave requests list with StreamBuilder
                  Expanded(
                    child: _userLeavesStream == null
                        ? const Center(child: CircularProgressIndicator())
                        : StreamBuilder<List<LeaveModel>>(
                            stream: _userLeavesStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error loading leave requests: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red),
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
                                );
                              }

                              final leaves = snapshot.data!;

                              return ListView.builder(
                                itemCount:
                                    leaves.length > 3 ? 3 : leaves.length,
                                itemBuilder: (context, index) {
                                  final leave = leaves[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: leave.status == 'pending'
                                            ? Colors.orange.withOpacity(0.5)
                                            : leave.status == 'approved'
                                                ? Colors.green.withOpacity(0.5)
                                                : Colors.red.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                      title: Text(
                                        'From: ${_formatDate(leave.fromDate)} To: ${_formatDate(leave.toDate)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text('Reason: ${leave.reason}'),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              _buildStatusChip(leave.status),
                                              if (leave.adminRemark != null &&
                                                  leave.adminRemark!.isNotEmpty)
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8),
                                                    child: Text(
                                                      'Remark: ${leave.adminRemark}',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LeaveHistoryScreen(),
                                          ),
                                        ).then((_) => _initializeStream());
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

  Widget _buildActionCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
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
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
