import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_constants.dart';
import '../models/request_model.dart';
import '../providers/request_provider.dart';
import '../constants/const_textstyle.dart';

class RequestCard extends StatefulWidget {
  final RequestModel request;
  final bool isAdmin;

  const RequestCard({
    Key? key,
    required this.request,
    this.isAdmin = false,
  }) : super(key: key);

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
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.request.userName,
                    style: getTextTheme().titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                _getStatusChip(widget.request.status),
              ],
            ),
            SizedBox(height: 8.h),
            
            // Request type
            _buildInfoRow(
              Icons.category,
              'Type',
              widget.request.typeDisplayName,
            ),
            
            // Date information based on request type
            if (widget.request.isLeaveRequest || widget.request.isWFHRequest) ...[
              _buildInfoRow(
                Icons.date_range,
                'From',
                dateFormat.format(widget.request.fromDate!),
              ),
              _buildInfoRow(
                Icons.date_range,
                'To',
                dateFormat.format(widget.request.toDate!),
              ),
            ] else if (widget.request.isBreakRequest) ...[
              _buildInfoRow(
                Icons.date_range,
                'Date',
                dateFormat.format(widget.request.date!),
              ),
            ],
            
            // Shift (only for leave requests)
            if (widget.request.isLeaveRequest && widget.request.shift != null)
              _buildInfoRow(Icons.access_time, 'Shift', widget.request.shift!),
            
            // Reason
            _buildInfoRow(Icons.subject, 'Reason', widget.request.reason),
            
            // Admin remark (if exists)
            if (widget.request.status != AppConstants.statusPending && 
                widget.request.adminRemark != null)
              _buildInfoRow(
                Icons.comment,
                'Admin Remark',
                widget.request.adminRemark!,
              ),
            
            SizedBox(height: 8.h),
            
            // Applied on date
            _buildInfoRow(
              Icons.calendar_today,
              'Applied On',
              dateFormat.format(widget.request.appliedOn),
            ),
            
            // Admin action buttons (only for pending requests)
            if (widget.isAdmin && widget.request.status == AppConstants.statusPending)
              Padding(
                padding: EdgeInsets.only(top: 16.0.h),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.check, color: Colors.white, size: 18.r),
                        label: Text('Approve', style: getTextTheme().labelLarge?.copyWith(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showRemarkDialog(AppConstants.statusApproved),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.close, color: Colors.white, size: 18.r),
                        label: Text('Reject', style: getTextTheme().labelLarge?.copyWith(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showRemarkDialog(AppConstants.statusRejected),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Delete button for user's pending requests
            if (!widget.isAdmin && widget.request.status == AppConstants.statusPending)
              Padding(
                padding: EdgeInsets.only(top: 16.0.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.delete, color: Colors.white, size: 18.r),
                    label: Text('Delete Request', style: getTextTheme().labelLarge?.copyWith(color: Colors.white)),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.r, color: Colors.grey[600]),
          SizedBox(width: 8.w),
          Text(
            '$label: ',
            style: getTextTheme().bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
          ),
          Expanded(
            child: Text(
              value,
              style: getTextTheme().bodyMedium?.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'approved':
        backgroundColor = Colors.green;
        textColor = Colors.white;
        displayText = 'Approved';
        break;
      case 'rejected':
        backgroundColor = Colors.red;
        textColor = Colors.white;
        displayText = 'Rejected';
        break;
      case 'pending':
      default:
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        displayText = 'Pending';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        displayText,
        style: getTextTheme().labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showRemarkDialog(String status) {
    _remarkController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${status == AppConstants.statusApproved ? 'Approve' : 'Reject'} Request', style: getTextTheme().titleMedium),
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
            child: Text('Cancel', style: getTextTheme().labelLarge),
          ),
          ElevatedButton(
            onPressed: () => _updateRequestStatus(status),
            child: Text(
              status == AppConstants.statusApproved ? 'Approve' : 'Reject',
              style: getTextTheme().labelLarge?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _updateRequestStatus(String status) async {
    Navigator.pop(context);
    
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    
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
            child: Text('Delete', style: getTextTheme().labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteRequest() async {
    Navigator.pop(context);
    
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    
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