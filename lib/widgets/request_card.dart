import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_constants.dart';
import '../models/request_model.dart';
import '../providers/request_provider.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
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

    final card = NeuCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NeuStyle.radiusMedium.r),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coloured edge shows the type at a glance
              Container(width: 4.w, color: style.color),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(style),
                      SizedBox(height: 6.h),
                      _buildDetails(style),
                      if (request.reason.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        _buildReason(),
                      ],
                      if (request.status != AppConstants.statusPending &&
                          request.adminRemark != null &&
                          request.adminRemark!.isNotEmpty)
                        _buildRemark(),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final pending = request.status == AppConstants.statusPending;
    // An employee cancels a pending request by swiping the card left; an
    // admin approves by swiping right and rejects by swiping left
    final adminSwipe = isAdmin && canApproveReject && pending;
    final employeeSwipe = !isAdmin && pending;

    // The list removes the card itself once the request changes, so a swipe
    // never completes on its own: it only opens the confirmation
    Widget swipeable(Widget child) {
      return Dismissible(
        key: ValueKey('swipe_${request.id}'),
        direction: adminSwipe
            ? DismissDirection.horizontal
            : DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          if (!adminSwipe) {
            await _showDeleteConfirmation(context);
          } else if (direction == DismissDirection.startToEnd) {
            RequestDecision.show(context, request, AppConstants.statusApproved);
          } else {
            RequestDecision.show(context, request, AppConstants.statusRejected);
          }
          return false;
        },
        background: adminSwipe
            ? _swipeHint(
                Icons.check_circle_outline,
                'Approve',
                ConstColors.successGreen,
                Alignment.centerLeft,
              )
            : const SizedBox.shrink(),
        secondaryBackground: _swipeHint(
          adminSwipe ? Icons.highlight_off : Icons.delete_outline,
          adminSwipe ? 'Reject' : 'Cancel',
          ConstColors.errorRed,
          Alignment.centerRight,
        ),
        child: child,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: adminSwipe || employeeSwipe ? swipeable(card) : card,
    );
  }

  // Shown behind the card while it is swiped: coloured icon and text only
  Widget _swipeHint(
    IconData icon,
    String label,
    Color color,
    Alignment alignment,
  ) {
    return Container(
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20.r),
          SizedBox(width: 6.w),
          Text(
            label,
            style: getTextTheme().labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(RequestTypeStyle style) {
    return Row(
      children: [
        Container(
          width: 32.r,
          height: 32.r,
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
                    color: ConstColors.textColorLight,
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
          // One day reads "On Date", a range reads "On Dates"
          label: isCompOff
              ? 'Worked on'
              : (from == null || sameDay || to == null)
              ? 'On Date'
              : 'On Dates',
          value: dateText,
        ),
        // The day off asked for in return for the day worked
        if (isCompOff && request.compOffDate != null) ...[
          SizedBox(height: 2.h),
          _InfoRow(
            icon: Icons.event_available,
            label: 'Comp off on',
            value: _date.format(request.compOffDate!),
          ),
        ],
        SizedBox(height: 6.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 4.h,
          children: [
            _pill(Icons.timelapse, _days(request.requestedDays), style.color),
            if (request.shift != null)
              _pill(
                Icons.access_time,
                request.shift!,
                ConstColors.textColorLight,
              ),
            if (isCompOff && request.fromTime != null && request.toTime != null)
              _pill(
                Icons.schedule,
                '${request.fromTime} - ${request.toTime}',
                ConstColors.textColorLight,
              ),
            _pill(
              Icons.calendar_today,
              'Applied on ${DateFormat('dd MMM').format(request.appliedOn)}',
              ConstColors.textColorLight,
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
    return Text(
      request.reason,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: getTextTheme().bodySmall?.copyWith(
        color: ConstColors.textColorLight,
      ),
    );
  }

  Widget _buildRemark() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.comment, size: 14.r, color: ConstColors.primaryDeep),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              'Admin: ${request.adminRemark!}',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.primaryDeep,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A hint under a pending card: there are no buttons, the card is swiped
  // (see build)
  Widget _buildActions() {
    if (request.status != AppConstants.statusPending) {
      return const SizedBox.shrink();
    }
    // An admin without the approve permission can only look
    if (isAdmin && !canApproveReject) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.swap_horiz : Icons.swipe_left,
            size: 14.r,
            color: ConstColors.textColorLight,
          ),
          SizedBox(width: 4.w),
          Text(
            isAdmin
                ? 'Swipe right to approve, left to reject'
                : 'Swipe left to cancel',
            style: getTextTheme().labelSmall?.copyWith(
              color: ConstColors.textColorLight,
            ),
          ),
        ],
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

  Future<void> _showDeleteConfirmation(BuildContext context) {
    return showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52.r,
                height: 52.r,
                decoration: BoxDecoration(
                  color: ConstColors.errorRed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 26.r,
                  color: ConstColors.errorRed,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                'Cancel Request?',
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'This ${request.typeDisplayName.toLowerCase()} request will be withdrawn. You can apply again any time.',
                textAlign: TextAlign.center,
                style: getTextTheme().bodyMedium?.copyWith(
                  color: ConstColors.textColor,
                ),
              ),
              SizedBox(height: 16.h),
              Divider(height: 1, color: ConstColors.borderColor),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'No',
                        style: getTextTheme().labelLarge?.copyWith(
                          color: ConstColors.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 24.h,
                    child: VerticalDivider(
                      width: 1,
                      color: ConstColors.borderColor,
                    ),
                  ),
                  Expanded(
                    child: TextButton(
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
                          ConstantSnackbar.showError(
                            title: 'Failed to cancel request',
                          );
                        }
                      },
                      child: Text(
                        'Yes, cancel',
                        style: getTextTheme().labelLarge?.copyWith(
                          color: ConstColors.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        Icon(icon, size: 14.r, color: ConstColors.textColorLight),
        SizedBox(width: 4.w),
        Text(
          '$label: ',
          style: getTextTheme().bodySmall?.copyWith(
            color: ConstColors.textColorLight,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: getTextTheme().bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
