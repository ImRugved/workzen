import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/leave_card.dart';
import '../../app_constants.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({Key? key}) : super(key: key);

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  Stream<List<RequestModel>>? _userLeavesStream;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userModel != null) {
        final requestProvider = Provider.of<RequestProvider>(
          context,
          listen: false,
        );
        setState(() {
          _userLeavesStream = requestProvider.getUserRequestsStream(
            authProvider.userModel!.id,
            type: AppConstants.requestTypeLeave,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeStream,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _userLeavesStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<RequestModel>>(
              stream: _userLeavesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading leave history: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No leave history found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your leave requests will appear here',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final requests = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: () async {
                    _initializeStream();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return LeaveCard(request: request, isAdmin: false);
                    },
                  ),
                );
              },
            ),
    );
  }
}
