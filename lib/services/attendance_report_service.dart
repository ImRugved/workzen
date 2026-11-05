import 'package:flutter/material.dart';
import '../models/monthly_attendance_summary.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';
import 'attendance_summary_service.dart';

/// Status key (a CalendarDayStatus name) -> label, in the order used by the
/// reports and their summaries.
const Map<String, String> attendanceStatusLabels = {
  'present': 'Present',
  'late': 'Late',
  'halfDay': 'Half Day',
  'leave': 'Leave',
  'compOff': 'Comp Off',
  'absent': 'Absent',
  'wfh': 'WFH',
  'holiday': 'Holiday',
  'weekend': 'Weekly Off',
};

/// One employee on one day of the report.
class AttendanceReportRow {
  final UserModel employee;
  final DateTime date;
  final DaySummary day;

  const AttendanceReportRow(this.employee, this.date, this.day);
}

/// The totals of one employee over the report's period.
class EmployeeAttendanceTotals {
  final UserModel employee;

  /// Days per status (present, late, leave, weekend ...).
  final Map<String, int> counts;

  /// Full leave days per leave code (pl, sl, cl); "other" when the type is not
  /// known.
  final Map<String, int> leaveTypes;
  final int totalDays;
  final Duration worked;
  final Duration extra;
  final Duration breaks;

  const EmployeeAttendanceTotals({
    required this.employee,
    required this.counts,
    required this.leaveTypes,
    required this.totalDays,
    required this.worked,
    required this.extra,
    required this.breaks,
  });

  int count(String status) => counts[status] ?? 0;
  int leaveOf(String code) => leaveTypes[code] ?? 0;

  /// Days the employee was expected to work: every day except holidays and the
  /// weekly off (Saturday and Sunday).
  int get workingDays => totalDays - count('holiday') - count('weekend');
}

/// Everything an exported attendance file holds: the filter that was used, one
/// row per employee per day, and the totals per employee and overall.
class AttendanceReport {
  final DateTime from;
  final DateTime to;
  final String employeeLabel;
  final List<AttendanceReportRow> rows;
  final List<EmployeeAttendanceTotals> totals;

  const AttendanceReport({
    required this.from,
    required this.to,
    required this.employeeLabel,
    required this.rows,
    required this.totals,
  });

  bool get isSingleEmployee => totals.length == 1;

  int overallCount(String status) =>
      totals.fold(0, (sum, t) => sum + t.count(status));

  int overallLeaveOf(String code) =>
      totals.fold(0, (sum, t) => sum + t.leaveOf(code));

  int get overallWorkingDays =>
      totals.fold(0, (sum, t) => sum + t.workingDays);

  Duration get overallWorked =>
      totals.fold(Duration.zero, (sum, t) => sum + t.worked);
  Duration get overallExtra =>
      totals.fold(Duration.zero, (sum, t) => sum + t.extra);
  Duration get overallBreaks =>
      totals.fold(Duration.zero, (sum, t) => sum + t.breaks);

  /// Total number of days counted (every status).
  int get totalDays => rows.length;
}

/// Builds an [AttendanceReport] from the stored monthly summaries of each
/// employee (rebuilt when stale), so absent days, leave, holidays and weekly
/// offs are all in the report, not only the days with a punch.
class AttendanceReportService {
  final AttendanceSummaryService _summaries = AttendanceSummaryService();

  // Employees are read a few at a time so a big team does not open dozens of
  // requests at once
  static const int _parallel = 5;

  Future<AttendanceReport> build({
    required List<UserModel> employees,
    required DateTimeRange range,
    required String employeeLabel,
  }) async {
    final from = DateTime(range.start.year, range.start.month, range.start.day);
    final to = DateTime(range.end.year, range.end.month, range.end.day);

    final months = <DateTime>[];
    var month = DateTime(from.year, from.month);
    final last = DateTime(to.year, to.month);
    while (!month.isAfter(last)) {
      months.add(month);
      month = DateTime(month.year, month.month + 1);
    }

    final sorted = [...employees]..sort((a, b) => a.name.compareTo(b.name));
    final rows = <AttendanceReportRow>[];
    final totals = <EmployeeAttendanceTotals>[];

    for (var i = 0; i < sorted.length; i += _parallel) {
      final batch = sorted.sublist(
        i,
        i + _parallel > sorted.length ? sorted.length : i + _parallel,
      );
      final results = await Future.wait(
        batch.map((employee) => _employeeRows(employee, months, from, to)),
      );
      for (var j = 0; j < batch.length; j++) {
        rows.addAll(results[j]);
        totals.add(_totalsOf(batch[j], results[j]));
      }
    }

    return AttendanceReport(
      from: from,
      to: to,
      employeeLabel: employeeLabel,
      rows: rows,
      totals: totals,
    );
  }

  // The days of one employee inside [from]..[to], oldest first
  Future<List<AttendanceReportRow>> _employeeRows(
    UserModel employee,
    List<DateTime> months,
    DateTime from,
    DateTime to,
  ) async {
    final rows = <AttendanceReportRow>[];
    try {
      // The months are independent of each other, so they load together
      final summaries = await Future.wait(
        months.map((month) => _summaries.ensureMonth(employee, month)),
      );
      for (final summary in summaries) {
        for (final day in summary.days.values) {
          // Days before joining, and days still to come, have no status
          if (day.status == 'none') continue;
          final date = DateTime(summary.year, summary.month, day.day);
          if (date.isBefore(from) || date.isAfter(to)) continue;
          rows.add(AttendanceReportRow(employee, date, day));
        }
      }
    } catch (e) {
      logDebug('Error building attendance report for ${employee.name}: $e');
    }
    rows.sort((a, b) => a.date.compareTo(b.date));
    return rows;
  }

  EmployeeAttendanceTotals _totalsOf(
    UserModel employee,
    List<AttendanceReportRow> rows,
  ) {
    final counts = <String, int>{};
    final leaveTypes = <String, int>{};
    var worked = Duration.zero;
    var extra = Duration.zero;
    var breaks = Duration.zero;

    for (final row in rows) {
      counts[row.day.status] = (counts[row.day.status] ?? 0) + 1;
      if (row.day.status == 'leave') {
        final code = row.day.leaveType ?? 'other';
        leaveTypes[code] = (leaveTypes[code] ?? 0) + 1;
      }
      worked += row.day.worked ?? Duration.zero;
      extra += row.day.shownExtra ?? Duration.zero;
      breaks += row.day.shownBreak ?? Duration.zero;
    }

    return EmployeeAttendanceTotals(
      employee: employee,
      counts: counts,
      leaveTypes: leaveTypes,
      totalDays: rows.length,
      worked: worked,
      extra: extra,
      breaks: breaks,
    );
  }
}
