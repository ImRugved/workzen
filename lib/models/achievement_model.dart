import 'package:cloud_firestore/cloud_firestore.dart';

/// A recognition an employee earned, kept on their own record
/// (users/{uid}/achievements/{id}) so their screens can show it.
class AchievementModel {
  /// Kind of the first achievement: chosen as employee of the month.
  static const String employeeOfMonthType = 'employee_of_month';

  final String id;
  final String type;

  /// "2026-10": the month it was earned for.
  final String month;
  final String title;
  final String? note;
  final DateTime awardedAt;

  const AchievementModel({
    required this.id,
    required this.type,
    required this.month,
    required this.title,
    required this.awardedAt,
    this.note,
  });

  /// The document id of the employee of the month achievement of [month].
  static String employeeOfMonthId(String month) =>
      '${employeeOfMonthType}_$month';

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    final awarded = json['awardedAt'];
    final note = json['note']?.toString().trim();
    return AchievementModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? employeeOfMonthType,
      month: json['month']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Employee of the Month',
      note: note == null || note.isEmpty ? null : note,
      awardedAt: awarded is Timestamp ? awarded.toDate() : DateTime.now(),
    );
  }

  /// The saved fields. awardedAt is added by the writer as a server time.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'month': month,
    'title': title,
    'note': note,
  };
}
