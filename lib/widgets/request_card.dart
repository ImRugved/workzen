import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_constants.dart';
import '../models/request_model.dart';
import '../providers/request_provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';

class RequestCard extends StatefulWidget {
  final RequestModel request;
  final bool isAdmin;
  final bool canApproveReject;

  const RequestCard({Key? key, required this.request, this.isAdmin = false, this.canApproveReject = true})
    : super(key: key);

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  final TextEditingController _remarkController = TextEditingController();
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Name of user with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.request.userName,
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                _getStatusChip(widget.request.status),
              ],
            ),
            SizedBox(height: 8.h),

            // Row 2: Leave type and shift in one row (only for leave requests)
            if (widget.request.isLeaveRequest) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Leave Type
                  if (widget.request.additionalData?['leaveType'] != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getLeaveTypeColor(
                          widget.request.additionalData!['leaveType'],
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: _getLeaveTypeColor(
                            widget.request.additionalData!['leaveType'],
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getLeaveTypeFullName(
                          widget.request.additionalData!['leaveType'],
                        ),
                        style: getTextTheme().labelMedium?.copyWith(
                          color: _getLeaveTypeColor(
                            widget.request.additionalData!['leaveType'],
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (widget.request.shift != null) ...[
                    SizedBox(width: 12.w),
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Type',
                      value: widget.request.shift!,
                    ),
                  ],
                ],
              ),
              SizedBox(height: 8.h),
            ],

            // Row 3: From to date in row
            if (widget.request.isLeaveRequest ||
                widget.request.isWFHRequest) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoRow(
                    icon: Icons.date_range,
                    label: 'From',
                    value: dateFormat.format(
                      widget.request.fromDate ?? DateTime.now(),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  _InfoRow(
                    icon: Icons.date_range,
                    label: 'To',
                    value: dateFormat.format(
                      widget.request.toDate ?? DateTime.now(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
            ] else if (widget.request.isBreakRequest) ...[
              _InfoRow(
                icon: Icons.date_range,
                label: 'Date',
                value: dateFormat.format(widget.request.date ?? DateTime.now()),
              ),
              SizedBox(height: 8.h),
            ],

            // Row 4: Applied on date
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Applied On',
              value: dateFormat.format(widget.request.appliedOn),
            ),
            SizedBox(height: 8.h),

            // Row 5: Reason
            _InfoRow(
              icon: Icons.subject,
              label: 'Reason',
              value: widget.request.reason,
              isExpanded: true,
            ),

            // Admin remark (if exists)
            if (widget.request.status != AppConstants.statusPending &&
                widget.request.adminRemark != null) ...[
              SizedBox(height: 8.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.comment, size: 16.r, color: Colors.blue[600]),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Admin: ${widget.request.adminRemark!}',
                      style: getTextTheme().bodySmall?.copyWith(
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Admin action buttons (only for pending requests, and only if user can approve/reject)
            if (widget.isAdmin &&
                widget.canApproveReject &&
                widget.request.status == AppConstants.statusPending)
              Padding(
                padding: EdgeInsets.only(top: 16.0.h),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18.r,
                        ),
                        label: Text(
                          'Approve',
                          style: getTextTheme().labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            _showRemarkDialog(AppConstants.statusApproved),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18.r,
                        ),
                        label: Text(
                          'Reject',
                          style: getTextTheme().labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            _showRemarkDialog(AppConstants.statusRejected),
                      ),
                    ),
                  ],
                ),
              ),

            // Delete button for user's pending requests
            if (!widget.isAdmin &&
                widget.request.status == AppConstants.statusPending)
              Padding(
                padding: EdgeInsets.only(top: 16.0.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.delete, color: Colors.white, size: 18.r),
                    label: Text(
                      'Delete Request',
                      style: getTextTheme().labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _showDeleteConfirmation,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getLeaveTypeFullName(String leaveType) {
    switch (leaveType.toLowerCase()) {
      case AppConstants.leaveTypePL:
        return 'Privilege Leave (PL)';
      case AppConstants.leaveTypeSL:
        return 'Sick Leave (SL)';
      case AppConstants.leaveTypeCL:
        return 'Casual Leave (CL)';
      default:
        return '${leaveType.toUpperCase()} (${leaveType.toUpperCase()})';
    }
  }

  Color _getLeaveTypeColor(String leaveType) {
    switch (leaveType.toLowerCase()) {
      case AppConstants.leaveTypePL:
        return ConstColors.infoBlue;
      case AppConstants.leaveTypeSL:
        return ConstColors.successGreen;
      case AppConstants.leaveTypeCL:
        return ConstColors.inProgressOrange;
      default:
        return Colors.grey;
    }
  }

  Widget _getStatusChip(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
        color = ConstColors.successGreen;
        label = 'Approved';
        break;
      case 'rejected':
        color = ConstColors.errorRed;
        label = 'Rejected';
        break;
      case 'pending':
      default:
        color = ConstColors.warningAmber;
        label = 'Pending';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: getTextTheme().labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10.sp,
        ),
      ),
    );
  }

  void _showRemarkDialog(String status) {
    _remarkController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${status == AppConstants.statusApproved ? 'Approve' : 'Reject'} Request',
          style: getTextTheme().titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to ${status == AppConstants.statusApproved ? 'approve' : 'reject'} this ${widget.request.typeDisplayName.toLowerCase()} request?',
              style: getTextTheme().bodyMedium,
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _remarkController,
              decoration: InputDecoration(
                labelText: 'Remark (Optional)',
                labelStyle: getTextTheme().bodyMedium,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _updateRequestStatus(status),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == AppConstants.statusApproved
                  ? Colors.green
                  : Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            ),
            child: Text(
              status == AppConstants.statusApproved ? 'Approve' : 'Reject',
            ),
          ),
        ],
      ),
    );
  }

  void _updateRequestStatus(String status) async {
    Navigator.pop(context);

    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    bool success = await requestProvider.updateRequestStatus(
      widget.request,
      status,
      _remarkController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Request ${status == AppConstants.statusApproved ? 'approved' : 'rejected'} successfully'
                : 'Failed to update request status',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Request', style: getTextTheme().titleMedium),
        content: Text(
          'Are you sure you want to delete this ${widget.request.typeDisplayName.toLowerCase()} request?',
          style: getTextTheme().bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: getTextTheme().labelLarge),
          ),
          ElevatedButton(
            onPressed: _deleteRequest,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Delete',
              style: getTextTheme().labelLarge?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteRequest() async {
    Navigator.pop(context);

    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    bool success = await requestProvider.deletePendingRequest(widget.request);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Request deleted successfully'
                : 'Failed to delete request',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isExpanded;

  const _InfoRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: isExpanded
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16.r, color: Colors.grey[600]),
        SizedBox(width: 3.w),
        Text(
          '$label: ',
          style: getTextTheme().bodyMedium?.copyWith(color: Colors.grey[700]),
        ),
        if (isExpanded)
          Expanded(child: Text(value, style: getTextTheme().bodyMedium))
        else
          Text(value, style: getTextTheme().bodyMedium),
      ],
    );
  }
}
