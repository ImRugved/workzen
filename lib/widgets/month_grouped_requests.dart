import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../models/request_model.dart';
import '../utils/leave_month_utils.dart';
import 'request_card.dart';

/// A list of request cards under month headers ("January 2026"), newest month
/// first. Each header shows the days taken that month per leave type (approved
/// requests only), so the leave of every month reads at a glance.
class MonthGroupedRequestList extends StatelessWidget {
  final List<RequestModel> requests;
  final EdgeInsetsGeometry padding;

  /// Admin view of the card (with its approve / reject swipe).
  final bool isAdmin;
  final bool canApproveReject;

  const MonthGroupedRequestList({
    super.key,
    required this.requests,
    required this.padding,
    this.isAdmin = false,
    this.canApproveReject = false,
  });

  @override
  Widget build(BuildContext context) {
    // One list of headers and cards, so the list builds only what is on screen
    final items = <Object>[];
    for (final group in groupRequestsByMonth(requests)) {
      items.add(group);
      items.addAll(group.requests);
    }

    return ListView.builder(
      padding: padding,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is LeaveMonthGroup) return _MonthHeader(group: item);
        return RequestCard(
          request: item as RequestModel,
          isAdmin: isAdmin,
          canApproveReject: canApproveReject,
        );
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final LeaveMonthGroup group;

  const _MonthHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final summary = group.summary;
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 12.h, 4.w, 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            group.title,
            style: getTextTheme().titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: ConstColors.textColor,
            ),
          ),
          if (summary.isNotEmpty)
            Flexible(
              child: Text(
                summary,
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
