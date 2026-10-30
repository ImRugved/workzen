import 'package:cloud_firestore/cloud_firestore.dart';

/// One break (tea, lunch...) inside a day's attendance record. A break that has
/// started and not ended has a null [end].
class AttendanceBreak {
  final DateTime start;
  final DateTime? end;

  const AttendanceBreak({required this.start, this.end});

  bool get isOpen => end == null;

  /// Length of the break; an open break counts up to [now].
  Duration duration([DateTime? now]) =>
      (end ?? now ?? DateTime.now()).difference(start);

  factory AttendanceBreak.fromJson(Map<String, dynamic> json) {
    return AttendanceBreak(
      start: (json['start'] as Timestamp).toDate(),
      end: json['end'] != null ? (json['end'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
}

class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final DateTime date;
  final DateTime? punchInTime;
  final DateTime? punchOutTime;
  final String status; // "present", "absent", "half-day", "on-leave"
  final String? leaveId; // Reference to leave if on leave
  final Map<String, double>? location; // {lat: ..., lng: ...}

  /// Breaks taken during the day, in order. At most the last one is open.
  final List<AttendanceBreak> breaks;

  /// "First Half" or "Second Half" when the employee had an approved half day
  /// leave on this day, else null. Saved at punch in, so the attendance lists
  /// can show the day as a half day instead of judging the punch times.
  final String? halfDayLeave;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    this.punchInTime,
    this.punchOutTime,
    required this.status,
    this.leaveId,
    this.location,
    this.breaks = const [],
    this.halfDayLeave,
  });

  /// True while a break has started and not ended.
  bool get isOnBreak => breaks.isNotEmpty && breaks.last.isOpen;

  /// Total break time so far (an open break counts up to now).
  Duration breakDuration([DateTime? now]) => breaks.fold(
    Duration.zero,
    (total, b) => total + b.duration(now),
  );

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      date: (json['date'] as Timestamp).toDate(),
      punchInTime: json['punchInTime'] != null
          ? (json['punchInTime'] as Timestamp).toDate()
          : null,
      punchOutTime: json['punchOutTime'] != null
          ? (json['punchOutTime'] as Timestamp).toDate()
          : null,
      status: json['status'] ?? 'absent',
      leaveId: json['leaveId'],
      location: json['location'] != null
          ? Map<String, double>.from(
              (json['location'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toDouble()),
              ),
            )
          : null,
      breaks: json['breaks'] is List
          ? (json['breaks'] as List)
                .whereType<Map>()
                .map(
                  (b) => AttendanceBreak.fromJson(Map<String, dynamic>.from(b)),
                )
                .toList()
          : const [],
      halfDayLeave: json['halfDayLeave'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'date': date,
      'punchInTime': punchInTime,
      'punchOutTime': punchOutTime,
      'status': status,
      'leaveId': leaveId,
      'location': location,
      'breaks': breaks.map((b) => b.toJson()).toList(),
      'halfDayLeave': halfDayLeave,
    };
  }

  // Create a copy of this attendance with updated fields
  AttendanceModel copyWith({
    String? id,
    String? userId,
    String? userName,
    DateTime? date,
    DateTime? punchInTime,
    DateTime? punchOutTime,
    String? status,
    String? leaveId,
    Map<String, double>? location,
    List<AttendanceBreak>? breaks,
    String? halfDayLeave,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      date: date ?? this.date,
      punchInTime: punchInTime ?? this.punchInTime,
      punchOutTime: punchOutTime ?? this.punchOutTime,
      status: status ?? this.status,
      leaveId: leaveId ?? this.leaveId,
      location: location ?? this.location,
      breaks: breaks ?? this.breaks,
      halfDayLeave: halfDayLeave ?? this.halfDayLeave,
    );
  }
}
