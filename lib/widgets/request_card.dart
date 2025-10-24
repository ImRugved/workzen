import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_constants.dart';
import '../models/request_model.dart';
import '../providers/request_provider.dart';

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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.request.userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _getStatusChip(widget.request.status),
              ],
            ),
            const SizedBox(height: 8),
            
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
            
            const SizedBox(height: 8),
            
            // Applied on date
            _buildInfoRow(
              Icons.calendar_today,
              'Applied On',
              dateFormat.format(widget.request.appliedOn),
            ),
            
            // Admin action buttons (only for pending requests)
            if (widget.isAdmin && widget.request.status == AppConstants.statusPending)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showRemarkDialog(AppConstants.statusApproved),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text('Reject'),
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
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Delete Request'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
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
        title: Text('${status == AppConstants.statusApproved ? 'Approve' : 'Reject'} Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to ${status == AppConstants.statusApproved ? 'approve' : 'reject'} this ${widget.request.typeDisplayName.toLowerCase()} request?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _remarkController,
              decoration: const InputDecoration(
                labelText: 'Remark (Optional)',
                border: OutlineInputBorder(),
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
            child: Text(status == AppConstants.statusApproved ? 'Approve' : 'Reject'),
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
        title: const Text('Delete Request'),
        content: Text(
          'Are you sure you want to delete this ${widget.request.typeDisplayName.toLowerCase()} request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _deleteRequest,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
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