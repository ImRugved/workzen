import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/leave_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/leave_card.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({Key? key}) : super(key: key);

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  Stream<List<LeaveModel>>? _userLeavesStream;
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
        final leaveProvider =
            Provider.of<LeaveProvider>(context, listen: false);
        setState(() {
          _userLeavesStream =
              leaveProvider.getUserLeavesStream(authProvider.userModel!.id);
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
          : StreamBuilder<List<LeaveModel>>(
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
                        Icon(
                          Icons.history,
                          size: 80,
                          color: Colors.grey[400],
                        ),
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
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final leaves = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: () async {
                    _initializeStream();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: leaves.length,
                    itemBuilder: (context, index) {
                      final leave = leaves[index];
                      return LeaveCard(leave: leave, isAdmin: false);
                    },
                  ),
                );
              },
            ),
    );
  }
}
