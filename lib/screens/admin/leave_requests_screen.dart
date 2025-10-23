import 'package:flutter/material.dart';
import 'package:workzen/app_constants.dart';
import 'package:provider/provider.dart';
import '../../models/leave_model.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/leave_card.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({Key? key}) : super(key: key);

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Pending', 'Approved', 'Rejected', 'All'];
  Stream<List<LeaveModel>>? _leavesStream;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize the TabController here with the number of tabs
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize the stream if not already initialized
    if (!_isInitialized) {
      _initializeStream();
      _isInitialized = true;
    }
  }

  void _initializeStream() {
    if (mounted) {
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      setState(() {
        _leavesStream = leaveProvider.getAllLeavesStream();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        actions: [
          // Add refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeStream,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((String name) => Tab(text: name)).toList(),
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: _leavesStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<LeaveModel>>(
              stream: _leavesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No leave requests found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final allLeaves = snapshot.data!;

                // Filter leaves based on status
                final pendingLeaves = allLeaves
                    .where(
                      (leave) => leave.status == AppConstants.statusPending,
                    )
                    .toList();
                final approvedLeaves = allLeaves
                    .where(
                      (leave) => leave.status == AppConstants.statusApproved,
                    )
                    .toList();
                final rejectedLeaves = allLeaves
                    .where(
                      (leave) => leave.status == AppConstants.statusRejected,
                    )
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLeaveList(pendingLeaves, 'No pending leave requests'),
                    _buildLeaveList(
                      approvedLeaves,
                      'No approved leave requests',
                    ),
                    _buildLeaveList(
                      rejectedLeaves,
                      'No rejected leave requests',
                    ),
                    _buildLeaveList(allLeaves, 'No leave requests found'),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildLeaveList(List<LeaveModel> leaves, String emptyMessage) {
    return leaves.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaves.length,
            itemBuilder: (context, index) {
              return LeaveCard(leave: leaves[index], isAdmin: true);
            },
          );
  }
}
