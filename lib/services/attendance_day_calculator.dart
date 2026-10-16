import '../app_constants.dart';
import '../models/attendance_model.dart';
import '../models/holiday_model.dart';
import '../models/office_hours_model.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';

enum CalendarDayStatus {
  holiday,
  leave,
  compOff, // leave taken from earned comp off credit
  halfDay,
  late,
  present,
  wfh,
  weekend,
  absent,
  none,
}

class DayResult {
  final CalendarDayStatus status;
  final String label;

  /// How the punch in was judged (null when there was no punch in).
  final PunchInStatus? punchStatus;

  const DayResult(this.status, this.label, [this.punchStatus]);
}

/// Decides the status of every day of a month from the user's attendance,
/// approved leave / WFH requests, the holiday list and the office hours. Used
/// by both the dashboard calendar and the stored monthly summary, so they
/// always agree.
class AttendanceDayCalculator {
  AttendanceDayCalculator._();

  /// Days treated as the weekly off. Change here if the office works Saturdays.
  static const Set<int> weekendDays = {DateTime.saturday, DateTime.sunday};

  // Shift values stored on a leave request that count as a half day
  static const Set<String> _halfDayShifts = {
    'Half Day',
    'First Half',
    'Second Half',
  };

  /// [frozenPunchStatus] holds a punch-in judgement made earlier for a day, so
  /// that changing the office hours later does not rewrite past days.
  static Map<int, DayResult> computeMonth({
    required DateTime month,
    required UserModel user,
    required Map<int, AttendanceModel> attendance,
    required List<RequestModel> requests,
    required Map<int, HolidayModel> holidays,
    OfficeHoursModel? officeHours,
    Map<int, PunchInStatus> frozenPunchStatus = const {},
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final joined = user.joiningDate ?? user.createdAt;
    final joinedDay = joined == null
        ? null
        : DateTime(joined.year, joined.month, joined.day);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final results = <int, DayResult>{};

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);

      // Approved leave / WFH requests covering this day
      RequestModel? leave;
      RequestModel? wfh;
      RequestModel? compOffDay;
      for (final request in requests) {
        // An approved comp off request marks the day off it asked for (not
        // the day worked)
        if (request.type == AppConstants.requestTypeCompOff) {
          final off = request.compOffDate;
          if (off != null &&
              off.year == date.year &&
              off.month == date.month &&
              off.day == date.day) {
            compOffDay = request;
          }
          continue;
        }
        if (request.fromDate == null || request.toDate == null) continue;
        final from = DateTime(
          request.fromDate!.year,
          request.fromDate!.month,
          request.fromDate!.day,
        );
        final to = DateTime(
          request.toDate!.year,
          request.toDate!.month,
          request.toDate!.day,
        );
        if (date.isBefore(from) || date.isAfter(to)) continue;

        if (request.type == AppConstants.requestTypeLeave) {
          leave = request;
        } else if (request.type == AppConstants.requestTypeWFH) {
          wfh = request;
        }
      }

      final holiday = holidays[day];
      final record = attendance[day];
      final isWeekend = weekendDays.contains(date.weekday);

      // Nothing is shown for days before the employee joined (unless they
      // somehow have a record on that day)
      if (joinedDay != null && date.isBefore(joinedDay) && record == null) {
        results[day] = const DayResult(CalendarDayStatus.none, '');
        continue;
      }

      if (compOffDay != null) {
        final half = compOffDay.compOffDays < 1;
        results[day] = DayResult(
          CalendarDayStatus.compOff,
          half ? 'Comp off (half day)' : 'Comp off',
        );
      } else if (holiday != null) {
        results[day] = DayResult(
          CalendarDayStatus.holiday,
          'Holiday: ${holiday.name}',
        );
      } else if (leave != null && !_halfDayShifts.contains(leave.shift)) {
        final isCompOff =
            leave.additionalData?['leaveType'] == AppConstants.leaveTypeCO;
        results[day] = isCompOff
            ? const DayResult(CalendarDayStatus.compOff, 'Comp off')
            : const DayResult(CalendarDayStatus.leave, 'On leave');
      } else if (leave != null ||
          record?.status == AppConstants.statusHalfDay) {
        results[day] = const DayResult(CalendarDayStatus.halfDay, 'Half day');
      } else if (record != null &&
          (record.punchInTime != null ||
              record.status == AppConstants.statusPresent)) {
        // Late / half day by punch-in time, only once office hours are set
        final punchIn = record.punchInTime;
        PunchInStatus? punchStatus;
        if (punchIn != null) {
          punchStatus =
              frozenPunchStatus[day] ??
              (officeHours != null
                  ? officeHours.punchInStatus(punchIn)
                  : PunchInStatus.onTime);
        }

        if (punchStatus == PunchInStatus.halfDay) {
          results[day] = DayResult(
            CalendarDayStatus.halfDay,
            'Half day (late punch in)',
            punchStatus,
          );
        } else if (punchStatus == PunchInStatus.late) {
          results[day] = DayResult(CalendarDayStatus.late, 'Late', punchStatus);
        } else {
          results[day] = DayResult(
            CalendarDayStatus.present,
            'Present',
            punchStatus,
          );
        }
      } else if (wfh != null) {
        results[day] = const DayResult(CalendarDayStatus.wfh, 'Work from home');
      } else if (isWeekend) {
        results[day] = const DayResult(CalendarDayStatus.weekend, 'Weekly off');
      } else if (record?.status == AppConstants.statusAbsent ||
          (record == null &&
              date.isBefore(today) &&
              (joinedDay == null || !date.isBefore(joinedDay)))) {
        // Past working day with no punch is shown as absent
        results[day] = const DayResult(CalendarDayStatus.absent, 'Absent');
      } else {
        results[day] = const DayResult(CalendarDayStatus.none, '');
      }
    }

    return results;
  }
}
