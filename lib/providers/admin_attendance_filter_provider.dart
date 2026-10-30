import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

/// The time span of the admin attendance filter.
enum AttendancePeriod {
  today('Today'),
  thisMonth('This month'),
  lastMonth('Last month'),
  lastTwoMonths('Last 2 months'),
  custom('Date range');

  final String label;
  const AttendancePeriod(this.label);
}

/// State of the admin's employee attendance screen: the live attendance
/// stream, the employee and period filters (set from the filter sheet), the
/// employee list and the busy flag. Scoped to the screen.
class AdminAttendanceFilterProvider with ChangeNotifier {
  Stream<List<AttendanceModel>>? _stream;
  bool _isLoading = false;
  String? _selectedEmployeeId;
  AttendancePeriod _period = AttendancePeriod.today;
  DateTimeRange? _customRange;
  List<UserModel> _employees = [];

  Stream<List<AttendanceModel>>? get stream => _stream;
  bool get isLoading => _isLoading;
  String? get selectedEmployeeId => _selectedEmployeeId;
  AttendancePeriod get period => _period;
  DateTimeRange? get customRange => _customRange;
  List<UserModel> get employees => _employees;

  /// The first and last day (date only) the filter covers.
  DateTimeRange get range => rangeFor(_period, _customRange);

  DateTime get from => range.start;
  DateTime get to => range.end;

  /// True when the filter covers one day only.
  bool get isSingleDay => from == to;

  /// The day shown when the filter is a single day (for "mark all absent").
  DateTime get selectedDate => from;

  /// True when anything other than "Today, all employees" is chosen.
  bool get isFiltered =>
      _selectedEmployeeId != null || _period != AttendancePeriod.today;

  /// The employee being shown, or null for all of them.
  UserModel? get selectedEmployee {
    for (final e in _employees) {
      if (e.id == _selectedEmployeeId) return e;
    }
    return null;
  }

  /// The dates a period covers, ending today (or the end of last month).
  static DateTimeRange rangeFor(AttendancePeriod period, DateTimeRange? custom) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case AttendancePeriod.today:
        return DateTimeRange(start: today, end: today);
      case AttendancePeriod.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        );
      case AttendancePeriod.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0),
        );
      case AttendancePeriod.lastTwoMonths:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: today,
        );
      case AttendancePeriod.custom:
        final range = custom ?? DateTimeRange(start: today, end: today);
        return DateTimeRange(
          start: DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          ),
          end: DateTime(range.end.year, range.end.month, range.end.day),
        );
    }
  }

  /// One line describing the filter: "Today • All employees".
  String get summaryText {
    final fmt = DateFormat('dd MMM yyyy');
    final when = _period == AttendancePeriod.custom
        ? '${fmt.format(from)} - ${fmt.format(to)}'
        : _period == AttendancePeriod.today
        ? 'Today'
        : '${_period.label} (${fmt.format(from)} - ${fmt.format(to)})';
    return '$when  •  ${selectedEmployee?.name ?? 'All employees'}';
  }

  void setStream(Stream<List<AttendanceModel>>? stream) {
    _stream = stream;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setEmployees(List<UserModel> employees) {
    _employees = employees;
    notifyListeners();
  }

  /// Applies the choices made in the filter sheet.
  void apply({
    String? employeeId,
    required AttendancePeriod period,
    DateTimeRange? customRange,
  }) {
    _selectedEmployeeId = employeeId;
    _period = period;
    _customRange = customRange;
    notifyListeners();
  }

  /// Back to today, all employees.
  void reset() => apply(period: AttendancePeriod.today);

  /// Attendance inside the chosen dates (and of the chosen employee), latest
  /// day first.
  List<AttendanceModel> filter(List<AttendanceModel> attendanceList) {
    final start = from;
    final end = to;

    final list = attendanceList.where((attendance) {
      final day = DateTime(
        attendance.date.year,
        attendance.date.month,
        attendance.date.day,
      );
      final inRange = !day.isBefore(start) && !day.isAfter(end);
      final isSelectedEmployee =
          _selectedEmployeeId == null ||
          attendance.userId == _selectedEmployeeId;
      return inRange && isSelectedEmployee;
    }).toList();

    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : a.userName.compareTo(b.userName);
    });
    return list;
  }
}
