import 'package:flutter/material.dart';
import 'package:workzen/app_constants.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../providers/request_provider.dart';
import '../../widgets/request_card.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({Key? key}) : super(key: key);

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Pending', 'Approved', 'Rejected', 'All'];
  Stream<List<RequestModel>>? _requestsStream;
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
      final requestProvider = Provider.of<RequestProvider>(context, listen: false);
      setState(() {
        _requestsStream = requestProvider.getAllRequestsStream(type: AppConstants.requestTypeLeave);
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
      body: _requestsStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<RequestModel>>(
              stream: _requestsStream,
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

                final allRequests = snapshot.data!;

                // Filter requests based on status
                final pendingRequests = allRequests
                    .where(
                      (request) => request.status == AppConstants.statusPending,
                    )
                    .toList();
                final approvedRequests = allRequests
                    .where(
                      (request) => request.status == AppConstants.statusApproved,
                    )
                    .toList();
                final rejectedRequests = allRequests
                    .where(
                      (request) => request.status == AppConstants.statusRejected,
                    )
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestList(pendingRequests, 'No pending leave requests'),
                    _buildRequestList(
                      approvedRequests,
                      'No approved leave requests',
                    ),
                    _buildRequestList(
                      rejectedRequests,
                      'No rejected leave requests',
                    ),
                    _buildRequestList(allRequests, 'No leave requests found'),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildRequestList(List<RequestModel> requests, String emptyMessage) {
    return requests.isEmpty
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
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return RequestCard(request: requests[index], isAdmin: true);
            },
          );
  }
}
