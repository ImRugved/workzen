import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:workzen/app_constants.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/request_card.dart';
import '../../constants/const_textstyle.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({Key? key}) : super(key: key);

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  Stream<List<RequestModel>>? _requestsStream;
  bool _isInitialized = false;

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All'; // Default filter
  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
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
      setState(() {
        _requestsStream = requestProvider.getAllRequestsStream(
          type: AppConstants.requestTypeLeave,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter requests based on search query and status
  List<RequestModel> _filterRequests(List<RequestModel> requests) {
    var filteredRequests = requests;

    // Filter by status
    if (_selectedStatus != 'All') {
      String statusConstant;
      if (_selectedStatus == 'Pending') {
        statusConstant = AppConstants.statusPending;
      } else if (_selectedStatus == 'Approved') {
        statusConstant = AppConstants.statusApproved;
      } else {
        statusConstant = AppConstants.statusRejected;
      }

      filteredRequests = filteredRequests
          .where((request) => request.status == statusConstant)
          .toList();
    }

    // Filter by search query (employee name)
    if (_searchQuery.isNotEmpty) {
      filteredRequests = filteredRequests
          .where(
            (request) => request.userName.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }

    return filteredRequests;
  }

  @override
  Widget build(BuildContext context) {
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
      body: _requestsStream == null
          ? const Center(child: CircularProgressIndicator())
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
                      suffixIcon: _searchQuery.isNotEmpty
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

                // Status filter chips
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: SizedBox(
                    height: 50.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _statusFilters.length,
                      itemBuilder: (context, index) {
                        final status = _statusFilters[index];
                        final isSelected = _selectedStatus == status;

                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: FilterChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatus = status;
                              });
                            },
                            selectedColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.2),
                            checkmarkColor: Theme.of(context).primaryColor,
                            labelStyle: getTextTheme().bodyMedium?.copyWith(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                SizedBox(height: 8.h),

                // Requests list
                Expanded(
                  child: StreamBuilder<List<RequestModel>>(
                    stream: _requestsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
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
                      final filteredRequests = _filterRequests(allRequests);

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

                      return ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final isSubAdmin = authProvider.userModel?.isSubAdmin == true;
                          return RequestCard(
                            request: filteredRequests[index],
                            isAdmin: true,
                            canApproveReject: !isSubAdmin,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
