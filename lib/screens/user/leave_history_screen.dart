import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/leave_card.dart';
import '../../app_constants.dart';
import '../../constants/const_textstyle.dart';

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
        title: Text(
          'Leave History',
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
                      style: getTextTheme().bodyMedium?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 80.r, color: Colors.grey[400]),
                        SizedBox(height: 16.h),
                        Text(
                          'No leave history found',
                          style: getTextTheme().titleLarge?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Your leave requests will appear here',
                          style: getTextTheme().bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
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
                    padding: EdgeInsets.all(16.w),
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
