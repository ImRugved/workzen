import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_theme.dart';
import '../constants/constant_colors.dart';
import '../constants/const_textstyle.dart';
import '../models/holiday_model.dart';
import '../providers/organization_provider.dart';

/// "Today", "Tomorrow" or "In 12 days" for a holiday on [date].
String holidayCountdown(DateTime date, DateTime today) {
  final days = date.difference(today).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}

/// Holidays grouped by month, in date order: {"October 2026": [...], ...}.
Map<String, List<HolidayModel>> groupHolidaysByMonth(
  Iterable<HolidayModel> holidays,
) {
  final sorted = holidays.toList()..sort((a, b) => a.date.compareTo(b.date));
  final grouped = <String, List<HolidayModel>>{};
  for (final holiday in sorted) {
    grouped
        .putIfAbsent(DateFormat('MMMM yyyy').format(holiday.date), () => [])
        .add(holiday);
  }
  return grouped;
}

/// Holiday calendar shown on the admin and user dashboards: the next holiday
/// in full, the ones after it as a swipe row of small cards, and a "View all"
/// sheet with every holiday by month. Data comes from
/// organization_details/holidays/items and is live.
class HolidayCalendarCard extends StatefulWidget {
  const HolidayCalendarCard({super.key});

  @override
  State<HolidayCalendarCard> createState() => _HolidayCalendarCardState();
}

class _HolidayCalendarCardState extends State<HolidayCalendarCard> {
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
    return Consumer<OrganizationProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcoming =
            provider.holidays.where((h) => !h.date.isBefore(today)).toList()
              ..sort((a, b) => a.date.compareTo(b.date));

        return NeuCard(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 22.r,
                    color: ConstColors.primaryDeep,
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
                  if (provider.holidays.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          HolidayListSheet.show(context, provider.holidays),
                      child: Text(
                        'View all',
                        style: getTextTheme().labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.primaryDeep,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6.h),
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
              else ...[
                _NextHoliday(holiday: upcoming.first, today: today),
                if (upcoming.length > 1) ...[
                  SizedBox(height: 10.h),
                  SizedBox(
                    height: 64.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: upcoming.length - 1,
                      separatorBuilder: (_, _) => SizedBox(width: 8.w),
                      itemBuilder: (context, index) => _HolidayMiniCard(
                        holiday: upcoming[index + 1],
                        today: today,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: ConstColors.borderColor,
      highlightColor: ConstColors.backgroundColor,
      child: Container(
        height: 76.h,
        decoration: BoxDecoration(
          color: ConstColors.cardBackground,
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
    );
  }
}

/// The next holiday, large: a date block, the name and a countdown.
class _NextHoliday extends StatelessWidget {
  final HolidayModel holiday;
  final DateTime today;

  const _NextHoliday({required this.holiday, required this.today});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: ConstColors.successGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: ConstColors.successGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label on the left, how soon on the right
          Row(
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 16.r,
                color: ConstColors.successGreen,
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  'NEXT HOLIDAY',
                  style: getTextTheme().labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: ConstColors.cardBackground,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14.r,
                      color: ConstColors.successGreen,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      holidayCountdown(holiday.date, today),
                      style: getTextTheme().labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              // Solid green date block, the day number large
              Container(
                width: 60.w,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: ConstColors.successGreen,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd').format(holiday.date),
                      style: getTextTheme().headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.white,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(holiday.date).toUpperCase(),
                      style: getTextTheme().labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.white,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13.r,
                          color: ConstColors.textColorLight,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            [
                              DateFormat('EEEE').format(holiday.date),
                              if (holiday.description != null)
                                holiday.description!,
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: getTextTheme().bodySmall?.copyWith(
                              color: ConstColors.textColorLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small card for a later holiday in the swipe row.
class _HolidayMiniCard extends StatelessWidget {
  final HolidayModel holiday;
  final DateTime today;

  const _HolidayMiniCard({required this.holiday, required this.today});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176.w,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: ConstColors.successGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: ConstColors.successGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          // Small date block: day over month
          Container(
            width: 42.r,
            padding: EdgeInsets.symmetric(vertical: 4.h),
            decoration: BoxDecoration(
              color: ConstColors.cardBackground,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd').format(holiday.date),
                  style: getTextTheme().titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.successGreen,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(holiday.date).toUpperCase(),
                  style: getTextTheme().labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: getTextTheme().bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                Text(
                  '${DateFormat('EEE').format(holiday.date)} • '
                  '${holidayCountdown(holiday.date, today)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A white date block: the day number over the month.
class _DateBlock extends StatelessWidget {
  final DateTime date;
  final Color color;

  const _DateBlock({required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52.w,
      padding: EdgeInsets.symmetric(vertical: 6.h),
      decoration: BoxDecoration(
        color: ConstColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            DateFormat('dd').format(date),
            style: getTextTheme().titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: getTextTheme().labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: ConstColors.textColorLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// One holiday as a row: date block, name, weekday and note, and either a
/// countdown or the [trailing] widget (the admin's delete button). Past
/// holidays are dimmed.
class HolidayTile extends StatelessWidget {
  final HolidayModel holiday;
  final DateTime today;
  final Widget? trailing;

  const HolidayTile({
    super.key,
    required this.holiday,
    required this.today,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = holiday.date.isBefore(today);
    final dim = isPast ? ConstColors.textColorLight : ConstColors.textColor;
    // Upcoming holidays are green, past ones grey
    final accent = isPast ? ConstColors.textColorLight : ConstColors.successGreen;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isPast ? 0.08 : 0.1),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isPast
                ? ConstColors.borderColor
                : accent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            _DateBlock(date: holiday.date, color: accent),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: dim,
                    ),
                  ),
                  Text(
                    [
                      DateFormat('EEEE').format(holiday.date),
                      if (holiday.description != null) holiday.description!,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (!isPast)
              Text(
                holidayCountdown(holiday.date, today),
                style: getTextTheme().labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Three small figures for a year of holidays: how many there are, how many
/// are still to come, and the date of the next one.
class HolidayStatsRow extends StatelessWidget {
  final List<HolidayModel> holidays;
  final int year;

  const HolidayStatsRow({super.key, required this.holidays, required this.year});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final inYear = holidays.where((h) => h.date.year == year).toList();
    final upcoming = inYear.where((h) => !h.date.isBefore(today)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Row(
      children: [
        Expanded(
          child: _stat('${inYear.length}', 'In $year', ConstColors.primary),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _stat(
            '${upcoming.length}',
            'Upcoming',
            ConstColors.successGreen,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _stat(
            upcoming.isEmpty
                ? '-'
                : DateFormat('dd MMM').format(upcoming.first.date),
            'Next date',
            ConstColors.inProgressOrange,
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: getTextTheme().titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: ConstColors.textColor,
            ),
          ),
          Text(
            label,
            style: getTextTheme().labelSmall?.copyWith(
              color: ConstColors.textColorLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing every holiday, grouped by month.
class HolidayListSheet {
  HolidayListSheet._();

  static void show(BuildContext context, List<HolidayModel> holidays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final grouped = groupHolidaysByMonth(holidays);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: ConstColors.borderColor,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'All Holidays',
                  style: getTextTheme().titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: EdgeInsets.only(top: 8.h, bottom: 2.h),
                          child: Text(
                            entry.key,
                            style: getTextTheme().labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: ConstColors.primaryDeep,
                            ),
                          ),
                        ),
                        for (final holiday in entry.value)
                          HolidayTile(holiday: holiday, today: today),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
