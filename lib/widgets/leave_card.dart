import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/request_model.dart';
import '../providers/request_provider.dart';

class LeaveCard extends StatelessWidget {
  final RequestModel request;
  final bool isAdmin;

  const LeaveCard({Key? key, required this.request, required this.isAdmin})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Wrap the text in Expanded to allow it to shrink if needed
                Expanded(
                  child: isAdmin
                      ? Text(
                          request.userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          // Allow text to overflow with ellipsis if too long
                          overflow: TextOverflow.ellipsis,
                        )
                      : const Text(
                          'Leave Request',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                // Add some space between the text and status chip
                const SizedBox(width: 8),
                // The status chip doesn't need to be wrapped in Expanded
                _getStatusChip(request.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.date_range,
              'From',
              dateFormat.format(request.fromDate ?? DateTime.now()),
            ),
            _buildInfoRow(
              Icons.date_range,
              'To',
              dateFormat.format(request.toDate ?? DateTime.now()),
            ),
            _buildInfoRow(Icons.access_time, 'Shift', request.shift ?? 'N/A'),
            _buildInfoRow(Icons.subject, 'Reason', request.reason),
            if (request.status != 'pending' && request.adminRemark != null)
              _buildInfoRow(
                Icons.comment,
                'Admin Remark',
                request.adminRemark!,
              ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Applied On',
              dateFormat.format(request.appliedOn),
            ),
            if (isAdmin && request.status == 'pending')
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Cancel Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: remarkController,
                decoration: const InputDecoration(
                  labelText: 'Add Remark (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text(action == 'approved' ? 'Approve' : 'Reject'),
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
          title: const Text('Confirm Deletion'),
          content: const Text(
            'Are you sure you want to cancel this leave request?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
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
                final success = await requestProvider.deletePendingRequest(request);

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
}
