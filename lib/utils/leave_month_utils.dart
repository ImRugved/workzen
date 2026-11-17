import 'package:intl/intl.dart';
import '../models/monthly_attendance_summary.dart';
import '../models/request_model.dart';
import '../widgets/request_type_style.dart';

/// The requests that start in one month, with the days per leave type of that
/// month ("PL 1 • SL 2.5 • UL 1").
class LeaveMonthGroup {
  final DateTime month;
  final List<RequestModel> requests;

  const LeaveMonthGroup(this.month, this.requests);

  /// "January 2026"
  String get title => DateFormat('MMMM yyyy').format(month);

  /// Days taken per type, e.g. "PL 1 • SL 2.5": approved requests only; empty
  /// when there is nothing to count.
  String get summary => leaveDaysSummary(requests.where((r) => r.isApproved));
}

/// The day a request is counted in: its first day (the day worked for a comp
/// off credit request).
DateTime requestStartDay(RequestModel r) =>
    (r.isCompOffRequest ? (r.compOffDate ?? r.date) : r.fromDate) ??
    r.appliedOn;

/// Groups requests by the month they start in, newest month first. The order of
/// the requests inside a month is kept as given.
List<LeaveMonthGroup> groupRequestsByMonth(List<RequestModel> requests) {
  final byMonth = <DateTime, List<RequestModel>>{};
  for (final r in requests) {
    final day = requestStartDay(r);
    byMonth.putIfAbsent(DateTime(day.year, day.month), () => []).add(r);
  }
  final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final m in months) LeaveMonthGroup(m, byMonth[m]!)];
}

String _days(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString();

/// "PL 1 • SL 2.5 • WFH 3": days per type of the given requests, leave types
/// in a fixed order.
String leaveDaysSummary(Iterable<RequestModel> requests) {
  final totals = <String, double>{};
  for (final r in requests) {
    final code = r.isWFHRequest ? 'WFH' : RequestTypeStyle.of(r).code;
    totals[code] = (totals[code] ?? 0) + r.requestedDays;
  }
  const order = ['PL', 'SL', 'CL', 'UL', 'CO', '+CO', 'WFH'];
  final codes = [
    ...order.where(totals.containsKey),
    ...totals.keys.where((c) => !order.contains(c)),
  ];
  return codes.map((c) => '$c ${_days(totals[c]!)}').join(' • ');
}

/// The leave codes of the month-wise leave table, in column order.
const List<String> monthLeaveCodes = ['pl', 'sl', 'cl', 'ul', 'co'];

/// Leave days of one employee in one month, per leave code (a half day counts
/// 0.5). Built from the days of the attendance summaries, so it follows the
/// same data as the attendance history and the exports.
class MonthLeaveTotals {
  final String employee;
  final DateTime month;
  final Map<String, double> days;

  const MonthLeaveTotals(this.employee, this.month, this.days);

  double of(String code) => days[code] ?? 0;
  double get total => days.values.fold(0, (sum, d) => sum + d);

  /// "January 2026"
  String get monthTitle => DateFormat('MMMM yyyy').format(month);

  /// A day count as shown in a table cell: "2", "1.5", or "-" for none.
  static String cell(double value) => value == 0 ? '-' : _days(value);
}

/// Leave days per employee and month, oldest month first and by employee name
/// inside a month. Only months with leave are returned. [items] are the days of
/// the report or history: (employee name, date, day).
List<MonthLeaveTotals> monthlyLeaveTotals(
  Iterable<(String, DateTime, DaySummary)> items,
) {
  final byKey = <(String, DateTime), Map<String, double>>{};
  for (final (employee, date, day) in items) {
    // A full leave day counts 1, a half day taken as leave 0.5; a day taken
    // from comp off has the status compOff (a half one says so in its label)
    final double count = day.status == 'leave'
        ? 1
        : day.status == 'compOff'
        ? (day.label.toLowerCase().contains('half') ? 0.5 : 1)
        : (day.status == 'halfDay' && day.leaveType != null ? 0.5 : 0);
    if (count == 0) continue;
    final code = (day.leaveType ?? 'other').toLowerCase();
    final totals = byKey.putIfAbsent((
      employee,
      DateTime(date.year, date.month),
    ), () => {});
    totals[code] = (totals[code] ?? 0) + count;
  }
  final keys = byKey.keys.toList()
    ..sort((a, b) {
      final byMonth = a.$2.compareTo(b.$2);
      return byMonth != 0 ? byMonth : a.$1.compareTo(b.$1);
    });
  return [for (final k in keys) MonthLeaveTotals(k.$1, k.$2, byKey[k]!)];
}
