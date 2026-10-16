import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import '../models/attendance_model.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/organization_provider.dart';

/// Dashboard card with today's punch in / out time and a month calendar that
/// colours each day by attendance status (present, absent, leave, half day,
/// holiday, work from home, weekly off).
class AttendanceCalendarCard extends StatefulWidget {
  const AttendanceCalendarCard({Key? key}) : super(key: key);

  @override
  State<AttendanceCalendarCard> createState() => _AttendanceCalendarCardState();
}

class _AttendanceCalendarCardState extends State<AttendanceCalendarCard> {
  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Live office hours and holidays set by the admin
      Provider.of<OrganizationProvider>(context, listen: false).start();

      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (user != null) {
        Provider.of<CalendarProvider>(
          context,
          listen: false,
        ).loadMonth(user, DateTime.now());
      }
    });
  }

  Color _colorFor(CalendarDayStatus status) {
    switch (status) {
      case CalendarDayStatus.present:
        return ConstColors.calendarPresent;
      case CalendarDayStatus.absent:
        return ConstColors.calendarAbsent;
      case CalendarDayStatus.leave:
        return ConstColors.calendarLeave;
      case CalendarDayStatus.compOff:
        return ConstColors.calendarCompOff;
      case CalendarDayStatus.halfDay:
        return ConstColors.calendarHalfDay;
      case CalendarDayStatus.late:
        return ConstColors.calendarLate;
      case CalendarDayStatus.holiday:
        return ConstColors.calendarHoliday;
      case CalendarDayStatus.wfh:
        return ConstColors.calendarWfh;
      case CalendarDayStatus.weekend:
        return ConstColors.calendarWeekend;
      case CalendarDayStatus.none:
        return ConstColors.grey;
    }
  }

  // Text on the saturated colours needs to be white to stay readable
  Color _textColorFor(CalendarDayStatus status) {
    switch (status) {
      case CalendarDayStatus.absent:
      case CalendarDayStatus.leave:
      case CalendarDayStatus.compOff:
      case CalendarDayStatus.wfh:
        return Colors.white;
      default:
        return ConstColors.textColor;
    }
  }

  void _onDayTap(CalendarProvider provider, int day) {
    final label = provider.labelFor(day);
    final date = DateTime(provider.month.year, provider.month.month, day);
    final record = provider.attendanceFor(day);

    final parts = <String>[
      DateFormat('dd MMM').format(date),
      label ?? 'No record',
    ];
    if (record?.punchInTime != null) {
      parts.add('In ${DateFormat('hh:mm a').format(record!.punchInTime!)}');
    }
    if (record?.punchOutTime != null) {
      parts.add('Out ${DateFormat('hh:mm a').format(record!.punchOutTime!)}');
    }

    ConstantSnackbar.show(title: parts.join(' • '));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPunchRow(provider.todayAttendance),
            SizedBox(height: 12.h),
            NeuCard(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              child: Column(
                children: [
                  _buildHeader(provider),
                  SizedBox(height: 2.h),
                  SizedBox(
                    height: 2.h,
                    child: provider.isLoading
                        ? const LinearProgressIndicator()
                        : null,
                  ),
                  SizedBox(height: 2.h),
                  // SizedBox(height: 6.h),
                  // _buildOfficeHoursNote(provider),
                  _buildWeekDayRow(),
                  SizedBox(height: 4.h),
                  _buildGrid(provider),
                  SizedBox(height: 8.h),
                  _buildLegend(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPunchRow(AttendanceModel? today) {
    return Row(
      children: [
        Expanded(
          child: _buildPunchTile(
            label: 'In Time',
            time: today?.punchInTime,
            color: ConstColors.successGreen,
            icon: Icons.login,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildPunchTile(
            label: 'Out Time',
            time: today?.punchOutTime,
            color: ConstColors.errorRed,
            icon: Icons.logout,
          ),
        ),
      ],
    );
  }

  Widget _buildPunchTile({
    required String label,
    required DateTime? time,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
      decoration: NeuStyle.raised(),
      child: Row(
        children: [
          Container(
            height: 36.h,
            width: 3.w,
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            color: color,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time == null
                      ? '--:-- --'
                      : DateFormat('hh:mm a').format(time),
                  style: getTextTheme().titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: getTextTheme().bodySmall),
              ],
            ),
          ),
          Icon(icon, color: color, size: 24.r),
        ],
      ),
    );
  }

  Widget _buildHeader(CalendarProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: provider.isLoading ? null : provider.previousMonth,
          tooltip: 'Previous month',
        ),
        Text(
          DateFormat('MMMM yyyy').format(provider.month),
          style: getTextTheme().titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: provider.isLoading ? null : provider.nextMonth,
          tooltip: 'Next month',
        ),
      ],
    );
  }

  // "Office 10:00 AM - 07:00 PM • Late after 10:25 AM", once admin has set it
  Widget _buildOfficeHoursNote(CalendarProvider provider) {
    final hours = provider.officeHours;
    if (hours == null) return const SizedBox.shrink();

    final lateAfter = hours.lateAfterMinutes;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Text(
        'Office ${hours.startTime.format(context)} - ${hours.endTime.format(context)}'
        '${lateAfter != null ? ' • Late after ${hours.startPlus(lateAfter).format(context)}' : ''}',
        textAlign: TextAlign.center,
        style: getTextTheme().labelSmall?.copyWith(
          color: ConstColors.textColorLight,
        ),
      ),
    );
  }

  Widget _buildWeekDayRow() {
    return Row(
      children: _weekDays
          .map(
            (d) => Expanded(
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: getTextTheme().bodyMedium?.copyWith(
                  color: ConstColors.primaryDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildGrid(CalendarProvider provider) {
    final month = provider.month;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final now = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: leadingBlanks + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();

        final day = index - leadingBlanks + 1;
        final status = provider.statusFor(day);
        final isToday = provider.isCurrentMonth && day == now.day;
        return GestureDetector(
          onTap: () => _onDayTap(provider, day),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 3.r, vertical: 3.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status == CalendarDayStatus.none
                  ? Colors.transparent
                  : _colorFor(status),
              border: isToday
                  ? Border.all(color: ConstColors.primaryDeep, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: getTextTheme().bodyMedium?.copyWith(
                  color: _textColorFor(status),
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    final items = <(String, Color)>[
      ('Present', ConstColors.calendarPresent),
      ('Absent', ConstColors.calendarAbsent),
      ('Leave', ConstColors.calendarLeave),
      ('Comp Off', ConstColors.calendarCompOff),
      ('Late', ConstColors.calendarLate),
      ('Half Day', ConstColors.calendarHalfDay),
      ('Holiday', ConstColors.calendarHoliday),
      ('WFH', ConstColors.calendarWfh),
      ('Weekly Off', ConstColors.calendarWeekend),
    ];

    return Wrap(
      spacing: 12.w,
      runSpacing: 6.h,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10.r,
                  height: 10.r,
                  decoration: BoxDecoration(
                    color: item.$2,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  item.$1,
                  style: getTextTheme().labelMedium?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}
