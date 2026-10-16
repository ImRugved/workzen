import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:workzen/app_constants.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../providers/request_filter_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/requests_data_table.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/permissions.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/apploading_indicator.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({Key? key}) : super(key: key);

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  bool _isInitialized = false;

  // Stream, search and status filter live in this scoped provider; the State
  // only owns it and the search text controller.
  final RequestFilterProvider _filter = RequestFilterProvider();
  final TextEditingController _searchController = TextEditingController();
  // CO covers leave taken from comp off and requests to earn it
  final List<String> _leaveTypeFilters = AppConstants.leaveFilterLabels.keys
      .toList();
  final List<String> _statusFilters = [
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
      final requestProvider = Provider.of<RequestProvider>(
        context,
        listen: false,
      );
      // Leave and comp off requests, newest first
      _filter.setStream(
        requestProvider.getAllRequestsStream().map(
          (requests) => requests
              .where((r) => r.isLeaveRequest || r.isCompOffRequest)
              .toList(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filter.dispose();
    super.dispose();
  }

  // Filter requests based on search query and status
  List<RequestModel> _filterRequests(
    RequestFilterProvider filter,
    List<RequestModel> requests,
  ) {
    var filteredRequests = requests;

    // Filter by leave type
    filteredRequests = filteredRequests
        .where(
          (request) => request.matchesLeaveTypeFilter(filter.selectedLeaveType),
        )
        .toList();

    // Filter by status
    if (filter.selectedStatus != 'All') {
      String statusConstant;
      if (filter.selectedStatus == 'Pending') {
        statusConstant = AppConstants.statusPending;
      } else if (filter.selectedStatus == 'Approved') {
        statusConstant = AppConstants.statusApproved;
      } else {
        statusConstant = AppConstants.statusRejected;
      }

      filteredRequests = filteredRequests
          .where((request) => request.status == statusConstant)
          .toList();
    }

    // Filter by search query (employee name)
    if (filter.searchQuery.isNotEmpty) {
      filteredRequests = filteredRequests
          .where(
            (request) =>
                request.userName.toLowerCase().contains(filter.searchQuery),
          )
          .toList();
    }

    return filteredRequests;
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    Map<String, String> labels = const {},
  }) {
    return ConstantDropdown<String>(
      value: value,
      label: label,
      isDense: true,
      items: options,
      itemLabel: (o) => labels[o] ?? o,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
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
          'Leave Requests',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        actions: [
          // Add refresh button
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
                // Search bar
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by employee name...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: filter.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),

                // Status and leave type filters
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: _filterDropdown(
                          label: 'Status',
                          value: filter.selectedStatus,
                          options: _statusFilters,
                          onChanged: filter.setStatus,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _filterDropdown(
                          label: 'Type',
                          value: filter.selectedLeaveType,
                          options: _leaveTypeFilters,
                          labels: AppConstants.leaveFilterLabels,
                          onChanged: filter.setLeaveType,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8.h),

                // Requests list
                Expanded(
                  child: StreamBuilder<List<RequestModel>>(
                    stream: filter.stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: AppLoadingIndicator(size: 40),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading leave requests: ${snapshot.error}',
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
                                Icons.event_busy,
                                size: 80.r,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No leave requests found',
                                style: getTextTheme().titleMedium?.copyWith(
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
                                Icons.search_off,
                                size: 80.r,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No requests match your filters',
                                style: getTextTheme().titleMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Admins and sub admins with the "approve leave
                      // requests" permission can approve or reject
                      return RequestsDataTable(
                        requests: filteredRequests,
                        canApproveReject: context.read<AuthProvider>().can(
                          Permissions.leaveRequests,
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
