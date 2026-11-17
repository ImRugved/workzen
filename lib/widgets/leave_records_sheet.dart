import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/apploading_indicator.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import '../models/request_model.dart';
import '../providers/leave_records_provider.dart';
import '../providers/request_provider.dart';
import '../utils/leave_month_utils.dart';
import 'app_dialog_card.dart';
import 'request_type_style.dart';

/// Bottom sheet of Manage Employee Leaves: the approved leave, comp off and WFH
/// records of one employee, month by month, each with a delete button. Deleting
/// a record takes its days back out of the balance.
class LeaveRecordsSheet extends StatelessWidget {
  final String employeeId;
  final String employeeName;

  /// Called after a record was deleted, so the balances behind the sheet reload.
  final VoidCallback onChanged;

  const LeaveRecordsSheet({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String employeeId,
    required String employeeName,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LeaveRecordsSheet(
        employeeId: employeeId,
        employeeName: employeeName,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LeaveRecordsProvider(employeeId),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 4.h),
              child: Text(
                'Leave records: $employeeName',
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                'Delete a record added by mistake. Its days go back to the balance.',
                style: getTextTheme().bodySmall?.copyWith(
                  color: ConstColors.textColorLight,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: Consumer<LeaveRecordsProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: AppLoadingIndicator());
                  }
                  if (provider.error != null) {
                    return Center(child: Text(provider.error!));
                  }
                  if (provider.records.isEmpty) {
                    return Center(
                      child: Text(
                        'No leave records',
                        style: getTextTheme().bodyMedium,
                      ),
                    );
                  }
                  final groups = groupRequestsByMonth(provider.records);
                  return ListView(
                    controller: controller,
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                    children: [
                      for (final group in groups) ...[
                        _MonthHeader(group: group),
                        for (final record in group.requests)
                          _RecordTile(record: record, onChanged: onChanged),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final LeaveMonthGroup group;

  const _MonthHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            group.title,
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Flexible(
            child: Text(
              group.summary,
              style: getTextTheme().labelSmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final RequestModel record;
  final VoidCallback onChanged;

  const _RecordTile({required this.record, required this.onChanged});

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<LeaveRecordsProvider>();
    final requests = context.read<RequestProvider>();
    final style = record.isWFHRequest ? null : RequestTypeStyle.of(record);
    final name = style?.name ?? 'Work From Home';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialogCard(
        icon: Icons.delete_outline,
        iconColor: ConstColors.errorRed,
        title: 'Delete this record?',
        message:
            '$name, ${record.displayDate}. The days go back to the balance '
            'and the attendance history is updated.',
        confirmLabel: 'Delete',
        confirmColor: ConstColors.errorRed,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirm != true) return;

    final done = await provider.delete(record, requests);
    if (done) {
      onChanged();
      ConstantSnackbar.showSuccess(title: 'Record deleted');
    } else {
      ConstantSnackbar.showError(title: 'Could not delete the record');
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = record.isWFHRequest
        ? const RequestTypeStyle('WFH', 'Work From Home', ConstColors.infoBlue)
        : RequestTypeStyle.of(record);
    final deleting = context.select<LeaveRecordsProvider, bool>(
      (p) => p.deletingId == record.id,
    );
    final days = record.requestedDays;
    final half = (record.shift ?? '').toLowerCase().contains('half');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              style.code,
              style: getTextTheme().labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.displayDate, style: getTextTheme().bodyMedium),
                Text(
                  '${days % 1 == 0 ? days.toInt() : days} '
                  '${days == 1 ? 'day' : 'days'}${half ? ' (${record.shift})' : ''}',
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          ),
          if (deleting)
            const AppLoadingIndicator(size: 20)
          else
            IconButton(
              tooltip: 'Delete',
              icon: Icon(
                Icons.delete_outline,
                size: 22.r,
                color: ConstColors.errorRed,
              ),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
    );
  }
}
