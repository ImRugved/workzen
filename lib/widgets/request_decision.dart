import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../app_constants.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_snackbar.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../models/request_model.dart';
import '../providers/request_provider.dart';

/// The approve / reject flow of a leave or comp off request: a dialog with an
/// optional remark, then the status update. Used by the request card and the
/// admin's leave requests table.
class RequestDecision {
  RequestDecision._();

  static void show(
    BuildContext context,
    RequestModel request,
    String status,
  ) {
    final approving = status == AppConstants.statusApproved;
    final requests = context.read<RequestProvider>();

    showDialog(
      context: context,
      builder: (_) => _RemarkDialog(
        title: '${approving ? 'Approve' : 'Reject'} Request',
        message:
            'Are you sure you want to ${approving ? 'approve' : 'reject'} this ${request.typeDisplayName.toLowerCase()} request?',
        actionLabel: approving ? 'Approve' : 'Reject',
        actionColor: approving
            ? ConstColors.successGreen
            : ConstColors.errorRed,
        onConfirm: (remark) async {
          final success = await requests.updateRequestStatus(
            request,
            status,
            remark,
          );
          if (success) {
            ConstantSnackbar.showSuccess(
              title:
                  'Request ${approving ? 'approved' : 'rejected'} successfully',
            );
          } else {
            ConstantSnackbar.showError(
              title: 'Failed to update request status',
            );
          }
        },
      ),
    );
  }
}

/// Approve / reject dialog; owns the remark controller so it is disposed
/// after the dialog's close animation.
class _RemarkDialog extends StatefulWidget {
  final String title;
  final String message;
  final String actionLabel;
  final Color actionColor;
  final Future<void> Function(String remark) onConfirm;

  const _RemarkDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionColor,
    required this.onConfirm,
  });

  @override
  State<_RemarkDialog> createState() => _RemarkDialogState();
}

class _RemarkDialogState extends State<_RemarkDialog> {
  final TextEditingController _remark = TextEditingController();

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: getTextTheme().titleMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message, style: getTextTheme().bodyMedium),
          SizedBox(height: 16.h),
          TextField(
            controller: _remark,
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
        ConstantButton(
          text: widget.actionLabel,
          isFullWidth: false,
          height: 40.h,
          backgroundColor: widget.actionColor,
          onPressed: () {
            final remark = _remark.text.trim();
            Navigator.pop(context);
            widget.onConfirm(remark);
          },
        ),
      ],
    );
  }
}
