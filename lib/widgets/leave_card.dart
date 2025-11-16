import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/request_model.dart';
import '../providers/request_provider.dart';
import '../constants/const_textstyle.dart';
import '../app_constants.dart';

class LeaveCard extends StatelessWidget {
  final RequestModel request;
  final bool isAdmin;

  const LeaveCard({Key? key, required this.request, required this.isAdmin})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: (Username if admin) | Leave Type | Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Username (for admin view)
                if (isAdmin)
                  Expanded(
                    child: Text(
                      request.userName,
                      style: getTextTheme().bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (isAdmin) SizedBox(width: 8.w),
                // Leave Type
                if (request.additionalData?['leaveType'] != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getLeaveTypeColor(
                        request.additionalData!['leaveType'],
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: _getLeaveTypeColor(
                          request.additionalData!['leaveType'],
                        ),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getLeaveTypeFullName(
                        request.additionalData!['leaveType'],
                      ),
                      style: getTextTheme().labelMedium?.copyWith(
                        color: _getLeaveTypeColor(
                          request.additionalData!['leaveType'],
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Status Chip
                _getStatusChip(request.status),
              ],
            ),
            SizedBox(height: 8.h),
            // Row 2: From - To Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoRow(
                  icon: Icons.date_range,
                  label: 'From',
                  value: dateFormat.format(request.fromDate ?? DateTime.now()),
                ),
                SizedBox(width: 12.w),
                _InfoRow(
                  icon: Icons.date_range,
                  label: 'To',
                  value: dateFormat.format(request.toDate ?? DateTime.now()),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Row 3: Applied On | Type (Full Day/Half Day)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Apply On',
                  value: dateFormat.format(request.appliedOn),
                ),
                if (request.shift != null) ...[
                  //SizedBox(width: 1.w),
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Type',
                    value: request.shift!,
                  ),
                ],
              ],
            ),

            SizedBox(height: 8.h),
            // Row 5: Reason
            _InfoRow(
              icon: Icons.subject,
              label: 'Reason',
              value: request.reason,
              isExpanded: true,
            ),
            // Admin Remark
            if (request.status != 'pending' && request.adminRemark != null) ...[
              SizedBox(height: 8.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.comment, size: 16.r, color: Colors.blue[600]),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Admin: ${request.adminRemark!}',
                      style: getTextTheme().bodySmall?.copyWith(
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (isAdmin && request.status == 'pending')
              Padding(
                padding: EdgeInsets.only(top: 12.0.h),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16.r,
                        ),
                        label: Text(
                          'Approve',
                          style: getTextTheme().labelMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                        ),
                        onPressed: () => _showActionDialog(
                          context,
                          'Approve Leave',
                          'Are you sure you want to approve this leave request?',
                          'approved',
                          requestProvider,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16.r,
                        ),
                        label: Text(
                          'Reject',
                          style: getTextTheme().labelMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                        ),
                        onPressed: () => _showActionDialog(
                          context,
                          'Reject Leave',
                          'Are you sure you want to reject this leave request?',
                          'rejected',
                          requestProvider,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Add delete button for employees with pending leave requests
            if (!isAdmin && request.status == 'pending')
              Padding(
                padding: EdgeInsets.only(top: 12.0.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.delete, color: Colors.white, size: 16.r),
                    label: Text(
                      'Cancel Request',
                      style: getTextTheme().labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                    ),
                    onPressed: () =>
                        _showDeleteConfirmationDialog(context, requestProvider),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
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

  void _showActionDialog(
    BuildContext context,
    String title,
    String message,
    String action,
    RequestProvider requestProvider,
  ) {
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title, style: getTextTheme().titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: getTextTheme().bodyMedium),
              SizedBox(height: 16.h),
              TextField(
                controller: remarkController,
                decoration: InputDecoration(
                  labelText: 'Add Remark (Optional)',
                  labelStyle: getTextTheme().bodyMedium,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: getTextTheme().labelLarge),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text(
                action == 'approved' ? 'Approve' : 'Reject',
                style: getTextTheme().labelLarge?.copyWith(color: Colors.white),
              ),
              onPressed: () async {
                // Store the scaffold messenger before popping the dialog
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Close the dialog
                Navigator.of(dialogContext).pop();

                // Update the leave status
                final success = await requestProvider.updateRequestStatus(
                  request,
                  action,
                  remarkController.text.trim(),
                );

                // Show success or error message
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Leave request ${action == 'approved' ? 'approved' : 'rejected'} successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update leave request'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'approved'
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    RequestProvider requestProvider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm Deletion', style: getTextTheme().titleMedium),
          content: Text(
            'Are you sure you want to cancel this leave request?',
            style: getTextTheme().bodyMedium,
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: getTextTheme().labelLarge),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              onPressed: () async {
                // Store the scaffold messenger before popping the dialog
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Close the dialog
                Navigator.of(dialogContext).pop();

                // Perform the delete operation
                final success = await requestProvider.deletePendingRequest(
                  request,
                );

                // Show success or error message using the stored scaffold messenger
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Leave request cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to cancel leave request'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
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
        return Colors.blue;
      case AppConstants.leaveTypeSL:
        return Colors.green;
      case AppConstants.leaveTypeCL:
        return Colors.orange;
      default:
        return Colors.grey;
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
