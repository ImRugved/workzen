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
  final TextEditingController _searchController = TextEditingController();
  String _selectedLeaveType = 'All';
  String _selectedStatus = 'All';

  final List<String> _leaveTypeOptions = ['All', 'PL', 'SL', 'CL'];
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<RequestModel> _filterRequests(List<RequestModel> requests) {
    return requests.where((request) {
      // Filter by leave type
      bool matchesLeaveType = true;
      if (_selectedLeaveType != 'All') {
        final leaveType = request.additionalData?['leaveType'] as String?;
        if (leaveType == null) {
          matchesLeaveType = false;
        } else {
          final normalizedSelected = _selectedLeaveType.toLowerCase();
          final normalizedLeaveType = leaveType.toLowerCase();
          matchesLeaveType = normalizedLeaveType == normalizedSelected;
        }
      }

      // Filter by status
      bool matchesStatus = true;
      if (_selectedStatus != 'All') {
        final normalizedSelectedStatus = _selectedStatus.toLowerCase();
        final normalizedRequestStatus = request.status.toLowerCase();
        matchesStatus = normalizedRequestStatus == normalizedSelectedStatus;
      }

      // Filter by search query
      bool matchesSearch = true;
      final searchQuery = _searchController.text.toLowerCase().trim();
      if (searchQuery.isNotEmpty) {
        matchesSearch =
            request.reason.toLowerCase().contains(searchQuery) ||
            (request.additionalData?['leaveType'] as String? ?? '')
                .toLowerCase()
                .contains(searchQuery) ||
            request.status.toLowerCase().contains(searchQuery);
      }

      return matchesLeaveType && matchesStatus && matchesSearch;
    }).toList();
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
          : Column(
              children: [
                // Search and Filter Section
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search by reason, leave type, or status...',
                          prefixIcon: Icon(Icons.search, size: 20.r),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 20.r),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Filter Dropdowns
                      Row(
                        children: [
                          // Leave Type Filter
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedLeaveType,
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey[700],
                                  ),
                                  items: _leaveTypeOptions.map((String type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: getTextTheme().bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedLeaveType = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          // Status Filter
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedStatus,
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey[700],
                                  ),
                                  items: _statusOptions.map((String status) {
                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(
                                        status,
                                        style: getTextTheme().bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedStatus = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Leave List
                Expanded(
                  child: StreamBuilder<List<RequestModel>>(
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
                              Icon(
                                Icons.history,
                                size: 80.r,
                                color: Colors.grey[400],
                              ),
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

                      final allRequests = snapshot.data!;
                      final filteredRequests = _filterRequests(allRequests);

                      if (filteredRequests.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_alt_off,
                                size: 80.r,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No leaves match your filters',
                                style: getTextTheme().titleLarge?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Try adjusting your search or filters',
                                style: getTextTheme().bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          _initializeStream();
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.all(16.w),
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = filteredRequests[index];
                            return LeaveCard(request: request, isAdmin: false);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
