import 'package:cloud_firestore/cloud_firestore.dart';

/// One day inside a monthly summary.
class DaySummary {
  final int day;

  /// Name of CalendarDayStatus: present, absent, leave, compOff, halfDay, late,
  /// wfh, holiday, weekend or none.
  final String status;

  /// Short text such as "Present", "Holiday: Diwali", "Half day (late punch in)".
  final String label;
  final DateTime? punchIn;
  final DateTime? punchOut;

  /// onTime / late / halfDay as judged when the punch happened. Kept so that a
  /// later change of office hours does not rewrite past days.
  final String? punchStatus;

  const DaySummary({
    required this.day,
    required this.status,
    required this.label,
    this.punchIn,
    this.punchOut,
    this.punchStatus,
  });

  /// Time between punch in and punch out, or null.
  Duration? get worked => (punchIn != null && punchOut != null)
      ? punchOut!.difference(punchIn!)
      : null;

  factory DaySummary.fromJson(int day, Map<String, dynamic> json) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return DaySummary(
      day: day,
      status: json['status'] ?? 'none',
      label: json['label'] ?? '',
      punchIn: ts(json['punchIn']),
      punchOut: ts(json['punchOut']),
      punchStatus: json['punchStatus'],
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'label': label,
    'punchIn': punchIn == null ? null : Timestamp.fromDate(punchIn!),
    'punchOut': punchOut == null ? null : Timestamp.fromDate(punchOut!),
    'punchStatus': punchStatus,
  };
}

/// A user's attendance for one month, stored at
/// users/{uid}/attendance_summary/{yyyy-MM}. Holds the day lists the app and
/// reports need (present, absent, leave, half day, late, ...) plus the counts
/// and per-day detail used by the attendance history table.
class MonthlyAttendanceSummary {
  final int year;
  final int month;
  final Map<int, DaySummary> days;

  const MonthlyAttendanceSummary({
    required this.year,
    required this.month,
    required this.days,
  });

  List<int> daysWithStatus(String status) {
    final list = days.values.where((d) => d.status == status).map((d) => d.day);
    return list.toList()..sort();
  }

  int count(String status) =>
      days.values.where((d) => d.status == status).length;

  factory MonthlyAttendanceSummary.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['days'] as Map?) ?? const {};
    final days = <int, DaySummary>{};
    rawDays.forEach((key, value) {
      final day = int.tryParse(key.toString());
      if (day != null && value is Map) {
        days[day] = DaySummary.fromJson(day, Map<String, dynamic>.from(value));
      }
    });
    return MonthlyAttendanceSummary(
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      days: days,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      // Day lists
      'presentDays': daysWithStatus('present'),
      'absentDays': daysWithStatus('absent'),
      'leaveDays': daysWithStatus('leave'),
      'compOffDays': daysWithStatus('compOff'),
      'halfDays': daysWithStatus('halfDay'),
      'lateDays': daysWithStatus('late'),
      'wfhDays': daysWithStatus('wfh'),
      'holidayDays': daysWithStatus('holiday'),
      'weekendDays': daysWithStatus('weekend'),
      // Counts
      'counts': {
        'present': count('present'),
        'absent': count('absent'),
        'leave': count('leave'),
        'compOff': count('compOff'),
        'halfDay': count('halfDay'),
        'late': count('late'),
        'wfh': count('wfh'),
        'holiday': count('holiday'),
        'weekend': count('weekend'),
      },
      // Per-day detail, keyed by day number
      'days': {for (final d in days.values) '${d.day}': d.toJson()},
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
