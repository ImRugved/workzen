import 'package:cloud_firestore/cloud_firestore.dart';

class HolidayModel {
  final String id;
  final String name;
  final DateTime date;
  final String? description;

  HolidayModel({
    required this.id,
    required this.name,
    required this.date,
    this.description,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final parsed = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is String
        ? DateTime.tryParse(rawDate) ?? DateTime.now()
        : DateTime.now();

    final description = json['description']?.toString().trim();

    return HolidayModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      date: DateTime(parsed.year, parsed.month, parsed.day),
      description: description == null || description.isEmpty
          ? null
          : description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'description': description,
    };
  }
}
