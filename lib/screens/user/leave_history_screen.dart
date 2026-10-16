import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_filter_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/request_card.dart';
import '../../app_constants.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_dropdown.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({Key? key}) : super(key: key);

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  bool _isInitialized = false;

  // Stream, search and filters live in this scoped provider; the State only
  // owns it and the search text controller.
  final RequestFilterProvider _filter = RequestFilterProvider();
  final TextEditingController _searchController = TextEditingController();

  // CO covers leave taken from comp off and requests to earn it
  final List<String> _leaveTypeOptions = AppConstants.leaveFilterLabels.keys
      .toList();
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => _filter.setSearch(_searchController.text),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filter.dispose();
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
        // Leave and comp off requests together
        _filter.setStream(
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
  }

  List<RequestModel> _filterRequests(
    RequestFilterProvider filter,
    List<RequestModel> requests,
  ) {
    return requests.where((request) {
      // Filter by leave type
      final matchesLeaveType = request.matchesLeaveTypeFilter(
        filter.selectedLeaveType,
      );

      // Filter by status
      bool matchesStatus = true;
      if (filter.selectedStatus != 'All') {
        final normalizedSelectedStatus = filter.selectedStatus.toLowerCase();
        final normalizedRequestStatus = request.status.toLowerCase();
        matchesStatus = normalizedRequestStatus == normalizedSelectedStatus;
      }

      // Filter by search query
      bool matchesSearch = true;
      final searchQuery = filter.searchQuery;
      if (searchQuery.isNotEmpty) {
        matchesSearch =
            request.reason.toLowerCase().contains(searchQuery) ||
            (request.leaveType ?? '')
                .toLowerCase()
                .contains(searchQuery) ||
            request.status.toLowerCase().contains(searchQuery);
      }

      return matchesLeaveType && matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _filter,
      child: Consumer<RequestFilterProvider>(
        builder: (context, filter, _) => _buildScreen(context, filter),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, RequestFilterProvider filter) {
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
      body: filter.stream == null
          ? const Center(child: AppLoadingIndicator(size: 40))
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
                          suffixIcon: filter.searchQuery.isNotEmpty
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
                            child: ConstantDropdown<String>(
                              value: filter.selectedLeaveType,
                              items: _leaveTypeOptions,
                              itemLabel: (type) =>
                                  AppConstants.leaveFilterLabels[type] ?? type,
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  filter.setLeaveType(newValue);
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 12.w),
                          // Status Filter
                          Expanded(
                            child: ConstantDropdown<String>(
                              value: filter.selectedStatus,
                              items: _statusOptions,
                              itemLabel: (status) => status,
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  filter.setStatus(newValue);
                                }
                              },
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
                    stream: filter.stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: AppLoadingIndicator(size: 40));
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
                      final filteredRequests = _filterRequests(
                        filter,
                        allRequests,
                      );

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
                            // Same card as the admin sees, for leave and comp off
                            return RequestCard(
                              request: filteredRequests[index],
                            );
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
