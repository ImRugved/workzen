import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../app_constants.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../models/request_model.dart';
import 'request_decision.dart';
import 'request_type_style.dart';

/// Leave and comp off requests in a data table for the admin: employee, type,
/// dates, days, duration, applied on, reason, status and the approve / reject
/// buttons of a pending request.
class RequestsDataTable extends StatelessWidget {
  final List<RequestModel> requests;

  /// Whether the signed-in admin / sub admin may approve or reject.
  final bool canApproveReject;

  const RequestsDataTable({
    super.key,
    required this.requests,
    required this.canApproveReject,
  });

  static final DateFormat _date = DateFormat('dd MMM yyyy');

  String _dates(RequestModel request) {
    if (request.isCompOffRequest) {
      final worked = _date.format(request.date ?? request.appliedOn);
      final off = request.compOffDate;
      return off == null
          ? 'Worked $worked'
          : 'Worked $worked → off ${_date.format(off)}';
    }
    final from = request.fromDate;
    final to = request.toDate;
    if (from == null) return 'N/A';
    final sameDay =
        to == null ||
        (from.year == to.year && from.month == to.month && from.day == to.day);
    return sameDay
        ? _date.format(from)
        : '${_date.format(from)} → ${_date.format(to)}';
  }

  String _days(double days) =>
      '${days % 1 == 0 ? days.toInt() : days} ${days == 1 ? 'day' : 'days'}';

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'approved':
        color = ConstColors.successGreen;
        label = 'Approved';
      case 'rejected':
        color = ConstColors.errorRed;
        label = 'Rejected';
      default:
        color = ConstColors.warningAmber;
        label = 'Pending';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: getTextTheme().labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _typeBadge(RequestTypeStyle style) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: style.color),
      ),
      child: Text(
        '${style.code}  ${style.name}',
        style: getTextTheme().labelSmall?.copyWith(
          color: style.color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, RequestModel request) {
    final pending = request.status == AppConstants.statusPending;
    if (!pending || !canApproveReject) return const Text('-');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.check_circle, size: 22.r),
          color: Colors.green,
          tooltip: 'Approve',
          onPressed: () => RequestDecision.show(
            context,
            request,
            AppConstants.statusApproved,
          ),
        ),
        IconButton(
          icon: Icon(Icons.cancel, size: 22.r),
          color: Colors.red,
          tooltip: 'Reject',
          onPressed: () => RequestDecision.show(
            context,
            request,
            AppConstants.statusRejected,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20.w,
          headingRowColor: WidgetStatePropertyAll(
            ConstColors.primary.withValues(alpha: 0.08),
          ),
          dataRowMinHeight: 52.h,
          dataRowMaxHeight: 64.h,
          columns: const [
            DataColumn(label: Text('Employee')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Dates')),
            DataColumn(label: Text('Days')),
            DataColumn(label: Text('Duration')),
            DataColumn(label: Text('Applied On')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: requests.map((request) {
            final style = RequestTypeStyle.of(request);
            final remark = request.adminRemark;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    request.userName,
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(_typeBadge(style)),
                DataCell(Text(_dates(request))),
                DataCell(Text(_days(request.requestedDays))),
                DataCell(Text(request.shift ?? 'Full Day')),
                DataCell(Text(_date.format(request.appliedOn))),
                DataCell(
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 200.w),
                    child: Tooltip(
                      message: request.reason,
                      child: Text(
                        request.reason.isEmpty ? '-' : request.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Tooltip(
                    message: remark != null && remark.isNotEmpty
                        ? 'Admin: $remark'
                        : '',
                    child: _statusChip(request.status),
                  ),
                ),
                DataCell(_actions(context, request)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
