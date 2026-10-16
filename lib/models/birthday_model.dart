import 'package:cloud_firestore/cloud_firestore.dart';

/// One employee's birthday, kept in organization_details/birthdays/items/{uid}
/// so every signed-in user can see who has a birthday today. Only the month
/// and day are stored, never the year of birth.
class BirthdayModel {
  final String userId;
  final String name;
  final int month;
  final int day;

  /// Male / Female / Other, or null; used only to word the greeting.
  final String? gender;

  const BirthdayModel({
    required this.userId,
    required this.name,
    required this.month,
    required this.day,
    this.gender,
  });

  /// The query key for a date: "10-30".
  static String keyFor(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// From a date of birth.
  factory BirthdayModel.fromDate({
    required String userId,
    required String name,
    required DateTime dateOfBirth,
    String? gender,
  }) => BirthdayModel(
    userId: userId,
    name: name,
    month: dateOfBirth.month,
    day: dateOfBirth.day,
    gender: gender,
  );

  factory BirthdayModel.fromJson(Map<String, dynamic> json) => BirthdayModel(
    userId: json['userId']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    month: (json['month'] as num?)?.toInt() ?? 1,
    day: (json['day'] as num?)?.toInt() ?? 1,
    gender: json['gender']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'month': month,
    'day': day,
    'gender': gender,
    'monthDay': '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}',
    'updatedAt': Timestamp.now(),
  };
}
