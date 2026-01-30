import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

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
                (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
              ),
            )
          : null,
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
    );
  }
}
