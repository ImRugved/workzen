import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/constant_colors.dart';
import '../constants/const_textstyle.dart';
import '../models/holiday_model.dart';
import '../providers/organization_provider.dart';
import '../providers/toggle_provider.dart';

/// Read-only holiday calendar shown on the admin and user dashboards.
/// Data comes from organization_details/holidays/items.
class HolidayCalendarCard extends StatefulWidget {
  const HolidayCalendarCard({super.key});

  @override
  State<HolidayCalendarCard> createState() => _HolidayCalendarCardState();
}

class _HolidayCalendarCardState extends State<HolidayCalendarCard> {
  static const int _collapsedCount = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Live list: updates as soon as the admin adds or removes a holiday
      Provider.of<OrganizationProvider>(context, listen: false).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // The "view all" flag is scoped to this card
    return ChangeNotifierProvider(
      create: (_) => ToggleProvider(),
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    return Consumer<OrganizationProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcoming = provider.holidays
            .where((h) => !h.date.isBefore(today))
            .toList();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 22.r,
                      color: ConstColors.primary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Holiday Calendar',
                        style: getTextTheme().titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.textColor,
                        ),
                      ),
                    ),
                    if (upcoming.isNotEmpty)
                      Text(
                        '${upcoming.length} upcoming',
                        style: getTextTheme().labelSmall?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8.h),
                if (!provider.holidaysLoaded)
                  _buildShimmer()
                else if (upcoming.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Center(
                      child: Text(
                        'No upcoming holidays',
                        style: getTextTheme().bodySmall?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                    ),
                  )
                else
                  Consumer<ToggleProvider>(
                    builder: (context, showAll, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...(showAll.value
                                ? upcoming
                                : upcoming.take(_collapsedCount))
                            .map((h) => _buildHolidayRow(h, today)),
                        if (upcoming.length > _collapsedCount)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: showAll.toggle,
                              child: Text(
                                showAll.value
                                    ? 'Show less'
                                    : 'View all (${upcoming.length})',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHolidayRow(HolidayModel holiday, DateTime today) {
    final days = holiday.date.difference(today).inDays;
    final countdown = days == 0
        ? 'Today'
        : days == 1
        ? 'Tomorrow'
        : 'In $days days';

    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Row(
        children: [
          Container(
            width: 48.w,
            padding: EdgeInsets.symmetric(vertical: 6.h),
            decoration: BoxDecoration(
              color: ConstColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(holiday.date),
                  style: getTextTheme().titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.primary,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(holiday.date),
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  style: getTextTheme().bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [
                    DateFormat('EEEE').format(holiday.date),
                    if (holiday.description != null) holiday.description!,
                  ].join(' • '),
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: days <= 1
                  ? ConstColors.successGreen.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              countdown,
              style: getTextTheme().labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: days <= 1 ? ConstColors.successGreen : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          2,
          (_) => Container(
            margin: EdgeInsets.only(top: 8.h),
            height: 48.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      ),
    );
  }
}
