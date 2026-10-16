import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_constants.dart';
import '../models/request_model.dart';
import '../providers/request_provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_button.dart';
import '../constants/constant_snackbar.dart';
import 'request_decision.dart';
import 'request_type_style.dart';

/// Card for a leave (PL / SL / CL / Comp Off) or comp off credit request.
/// Used by the admin's leave requests, the employee's leave history and the
/// employee dashboard, so all three show the same data.
class RequestCard extends StatelessWidget {
  final RequestModel request;
  final bool isAdmin;
  final bool canApproveReject;

  const RequestCard({
    super.key,
    required this.request,
    this.isAdmin = false,
    this.canApproveReject = true,
  });

  static final DateFormat _date = DateFormat('dd MMM yyyy');

  // Badge code, name and colour of the request kind
  RequestTypeStyle get _style => RequestTypeStyle.of(request);

  String _days(double days) =>
      '${days % 1 == 0 ? days.toInt() : days} ${days == 1 ? 'day' : 'days'}';

  @override
  Widget build(BuildContext context) {
    final style = _style;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coloured edge shows the type at a glance
            Container(width: 5.w, color: style.color),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(style),
                    SizedBox(height: 10.h),
                    _buildDetails(style),
                    SizedBox(height: 10.h),
                    _buildReason(),
                    if (request.status != AppConstants.statusPending &&
                        request.adminRemark != null &&
                        request.adminRemark!.isNotEmpty)
                      _buildRemark(),
                    _buildActions(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(RequestTypeStyle style) {
    return Row(
      children: [
        Container(
          width: 40.r,
          height: 40.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: style.color),
          ),
          child: Text(
            style.code,
            style: getTextTheme().labelMedium?.copyWith(
              color: style.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                style.name,
                style: getTextTheme().bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: style.color,
                ),
              ),
              if (isAdmin)
                Text(
                  request.userName,
                  style: getTextTheme().bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        _statusChip(request.status),
      ],
    );
  }

  Widget _buildDetails(RequestTypeStyle style) {
    final isCompOff = request.isCompOffRequest;
    final from = request.fromDate;
    final to = request.toDate;
    final sameDay =
        from != null &&
        to != null &&
        from.year == to.year &&
        from.month == to.month &&
        from.day == to.day;

    final dateText = isCompOff
        ? _date.format(request.date ?? request.appliedOn)
        : from == null
        ? 'N/A'
        : sameDay || to == null
        ? _date.format(from)
        : '${_date.format(from)}  →  ${_date.format(to)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.event,
          label: isCompOff ? 'Worked on' : 'Dates',
          value: dateText,
        ),
        // The day off asked for in return for the day worked
        if (isCompOff && request.compOffDate != null) ...[
          SizedBox(height: 6.h),
          _InfoRow(
            icon: Icons.event_available,
            label: 'Comp off on',
            value: _date.format(request.compOffDate!),
          ),
        ],
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 6.h,
          children: [
            _pill(Icons.timelapse, _days(request.requestedDays), style.color),
            if (request.shift != null)
              _pill(Icons.access_time, request.shift!, Colors.grey[700]!),
            if (isCompOff && request.fromTime != null && request.toTime != null)
              _pill(
                Icons.schedule,
                '${request.fromTime} - ${request.toTime}',
                Colors.grey[700]!,
              ),
            _pill(
              Icons.calendar_today,
              'Applied ${_date.format(request.appliedOn)}',
              Colors.grey[700]!,
            ),
          ],
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.r, color: color),
          SizedBox(width: 4.w),
          Text(
            text,
            style: getTextTheme().labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReason() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        request.reason.isEmpty ? 'No reason given' : request.reason,
        style: getTextTheme().bodySmall,
      ),
    );
  }

  Widget _buildRemark() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Row(
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
    );
  }

  Widget _buildActions(BuildContext context) {
    if (request.status != AppConstants.statusPending) {
      return const SizedBox.shrink();
    }

    // Admin / allowed sub admin: approve or reject
    if (isAdmin) {
      if (!canApproveReject) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: 12.h),
        child: Row(
          children: [
            Expanded(
              child: ConstantButton(
                text: 'Approve',
                icon: Icon(Icons.check, color: ConstColors.white, size: 18.r),
                backgroundColor: ConstColors.successGreen,
                height: 40.h,
                onPressed: () => RequestDecision.show(
                  context,
                  request,
                  AppConstants.statusApproved,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ConstantButton(
                text: 'Reject',
                icon: Icon(Icons.close, color: ConstColors.white, size: 18.r),
                backgroundColor: ConstColors.errorRed,
                height: 40.h,
                onPressed: () => RequestDecision.show(
                  context,
                  request,
                  AppConstants.statusRejected,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Employee: withdraw a pending request
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: SizedBox(
        width: double.infinity,
        child: ConstantButton(
          text: 'Cancel Request',
          icon: Icon(
            Icons.delete_outline,
            color: ConstColors.errorRed,
            size: 18.r,
          ),
          isOutlined: true,
          backgroundColor: ConstColors.errorRed,
          height: 40.h,
          onPressed: () => _showDeleteConfirmation(context),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
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
        color: color.withValues(alpha: 0.2),
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

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel Request', style: getTextTheme().titleMedium),
        content: Text(
          'Are you sure you want to cancel this ${request.typeDisplayName.toLowerCase()} request?',
          style: getTextTheme().bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('No', style: getTextTheme().labelLarge),
          ),
          ConstantButton(
            text: 'Yes, cancel',
            isFullWidth: false,
            height: 40.h,
            backgroundColor: ConstColors.errorRed,
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await context
                  .read<RequestProvider>()
                  .deletePendingRequest(request);
              if (success) {
                ConstantSnackbar.showSuccess(
                  title: 'Request cancelled successfully',
                );
              } else {
                ConstantSnackbar.showError(title: 'Failed to cancel request');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16.r, color: Colors.grey[600]),
        SizedBox(width: 4.w),
        Text(
          '$label: ',
          style: getTextTheme().bodyMedium?.copyWith(color: Colors.grey[700]),
        ),
        Expanded(
          child: Text(
            value,
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
