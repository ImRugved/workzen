import 'package:flutter/material.dart';

enum PunchInStatus { onTime, late, halfDay }

/// Office timing rules stored in organization_details/office_hours.
///
/// Example: start 10:00, lateAfterMinutes 25, halfDayAfterMinutes 40 means
/// punching in up to 10:25 is on time, 10:26 to 10:40 is late, and anything
/// after 10:40 is a half day.
///
/// [lateAfterMinutes] and [halfDayAfterMinutes] are both optional. When one is
/// null that rule is simply not applied.
class OfficeHoursModel {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int? lateAfterMinutes;
  final int? halfDayAfterMinutes;

  const OfficeHoursModel({
    required this.startTime,
    required this.endTime,
    this.lateAfterMinutes,
    this.halfDayAfterMinutes,
  });

  static String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static TimeOfDay? _parseTime(dynamic value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Returns null when the document is missing or incomplete.
  static OfficeHoursModel? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final start = _parseTime(json['startTime']);
    final end = _parseTime(json['endTime']);
    if (start == null || end == null) return null;

    final lateAfter = json['lateAfterMinutes'];
    final halfDayAfter = json['halfDayAfterMinutes'];
    return OfficeHoursModel(
      startTime: start,
      endTime: end,
      lateAfterMinutes: lateAfter is num ? lateAfter.toInt() : null,
      halfDayAfterMinutes: halfDayAfter is num ? halfDayAfter.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': formatTime(startTime),
    'endTime': formatTime(endTime),
    'lateAfterMinutes': lateAfterMinutes,
    'halfDayAfterMinutes': halfDayAfterMinutes,
  };

  /// Classifies a punch-in time against these rules.
  PunchInStatus punchInStatus(DateTime punchIn) {
    final minutesAfterStart =
        (punchIn.hour * 60 + punchIn.minute) -
        (startTime.hour * 60 + startTime.minute);

    final halfDayAfter = halfDayAfterMinutes;
    final lateAfter = lateAfterMinutes;

    if (halfDayAfter != null && minutesAfterStart > halfDayAfter) {
      return PunchInStatus.halfDay;
    }
    if (lateAfter != null && minutesAfterStart > lateAfter) {
      return PunchInStatus.late;
    }
    return PunchInStatus.onTime;
  }

  /// Wall clock time of [start] plus [minutes], e.g. 10:00 + 25 -> 10:25.
  TimeOfDay startPlus(int minutes) {
    final total = startTime.hour * 60 + startTime.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }
}
