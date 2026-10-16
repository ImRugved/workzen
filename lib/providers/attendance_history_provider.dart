import 'package:flutter/material.dart';
import '../models/monthly_attendance_summary.dart';
import '../models/user_model.dart';
import '../services/attendance_summary_service.dart';
import '../utils/logger.dart';

/// One line of the attendance history table.
class AttendanceHistoryRow {
  final DateTime date;
  final DaySummary day;

  const AttendanceHistoryRow(this.date, this.day);
}

/// State of the attendance history screen: the date range, filters, search,
/// sort order and the rows loaded from the stored monthly summaries. Scoped to
/// the screen.
class AttendanceHistoryProvider with ChangeNotifier {
  final AttendanceSummaryService _service = AttendanceSummaryService();

  late DateTime _from;
  late DateTime _to;
  String _statusFilter = 'all';
  String _search = '';
  bool _sortAscending = false; // latest first

  List<AttendanceHistoryRow> _rows = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isExporting = false;

  AttendanceHistoryProvider() {
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
  }

  /// The day the employee joined (date only), or null when unknown.
  static DateTime? joiningDateOf(UserModel user) {
    final joined = user.joiningDate ?? user.createdAt;
    return joined == null
        ? null
        : DateTime(joined.year, joined.month, joined.day);
  }

  DateTime get from => _from;
  DateTime get to => _to;
  String get statusFilter => _statusFilter;
  String get search => _search;
  bool get sortAscending => _sortAscending;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isExporting => _isExporting;

  /// Every row in the date range, before the status filter and search.
  List<AttendanceHistoryRow> get allRows => _rows;

  int count(String status) => _rows.where((r) => r.day.status == status).length;

  // Search text matches the date, weekday, status label and the remark
  bool _matchesSearch(AttendanceHistoryRow row, Map<String, String> labels) {
    if (_search.isEmpty) return true;
    final haystack = [
      '${row.date.day.toString().padLeft(2, '0')} ${_monthName(row.date.month)} ${row.date.year}',
      _weekdayName(row.date.weekday),
      labels[row.day.status] ?? row.day.status,
      row.day.label,
    ].join(' ').toLowerCase();
    return haystack.contains(_search.toLowerCase());
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  String _monthName(int m) => _months[m - 1];
  String _weekdayName(int d) => _weekdays[d - 1];

  /// Rows after the status filter and search, in the chosen sort order.
  List<AttendanceHistoryRow> visibleRows(Map<String, String> statusLabels) {
    final rows = _rows
        .where((r) => _statusFilter == 'all' || r.day.status == _statusFilter)
        .where((r) => _matchesSearch(r, statusLabels))
        .toList();
    rows.sort(
      (a, b) =>
          _sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
    );
    return rows;
  }

  // --- Filters ---

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void toggleStatusFilter(String status) {
    _statusFilter = _statusFilter == status ? 'all' : status;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value.trim();
    notifyListeners();
  }

  void setSortAscending(bool ascending) {
    _sortAscending = ascending;
    notifyListeners();
  }

  void setExporting(bool value) {
    _isExporting = value;
    notifyListeners();
  }

  Future<void> setRange(UserModel user, DateTime from, DateTime to) {
    _from = DateTime(from.year, from.month, from.day);
    _to = DateTime(to.year, to.month, to.day);
    return load(user);
  }

  /// Loads each month of the range from its stored summary (rebuilt when the
  /// month is missing or out of date) and flattens it into table rows.
  Future<void> load(UserModel user, {bool force = false}) async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    // History starts on the joining date
    final joining = joiningDateOf(user);
    if (joining != null && _from.isBefore(joining)) _from = joining;
    if (joining != null && _to.isBefore(_from)) _to = _from;

    try {
      final months = <DateTime>[];
      var month = DateTime(_from.year, _from.month);
      final last = DateTime(_to.year, _to.month);
      while (!month.isAfter(last)) {
        months.add(month);
        month = DateTime(month.year, month.month + 1);
      }

      final summaries = await Future.wait(
        months.map((m) => _service.ensureMonth(user, m, force: force)),
      );

      final rows = <AttendanceHistoryRow>[];
      for (final summary in summaries) {
        for (final day in summary.days.values) {
          if (day.status == 'none') continue;
          final date = DateTime(summary.year, summary.month, day.day);
          if (date.isBefore(_from) || date.isAfter(_to)) continue;
          rows.add(AttendanceHistoryRow(date, day));
        }
      }
      _rows = rows;
    } catch (e) {
      logDebug('Error loading attendance history: $e');
      _hasError = true;
    }

    _isLoading = false;
    notifyListeners();
  }
}
