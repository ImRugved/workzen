import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String fcmToken;
  final bool isAdmin;
  final String? profileImageUrl;
  final String? employeeId;
  final String? department;
  final DateTime? createdAt;
  final DateTime? joiningDate;
  final String? role;
  final String userId;
  final bool? isCasualLeave;
  final String? totalExperience;
  final String? emergencyContactNumber;
  final bool isSubAdmin;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.fcmToken,
    required this.isAdmin,
    this.profileImageUrl,
    this.employeeId,
    this.department,
    this.createdAt,
    this.joiningDate,
    this.role,
    this.isCasualLeave,
    this.totalExperience,
    this.emergencyContactNumber,
    this.isSubAdmin = false,
    String? userId,
  }) : userId = userId ?? id;

  // Helper method to parse DateTime from various formats
  static DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return null;
      }
    } else if (dateValue is Timestamp) {
      // Handle Firestore Timestamp
      return dateValue.toDate();
    }

    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle profileImageUrl - convert empty strings to null
    final profileImageUrlValue = json['profileImageUrl'];
    final profileImageUrl =
        profileImageUrlValue != null &&
            profileImageUrlValue.toString().trim().isNotEmpty
        ? profileImageUrlValue.toString()
        : null;

    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      fcmToken: json['fcmToken'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      profileImageUrl: profileImageUrl,
      employeeId: json['employeeId']
          ?.toString(), // Convert to string if it's an int
      department: json['department'],
      createdAt: _parseDateTime(json['createdAt']),
      joiningDate: _parseDateTime(json['joiningDate']),
      role: json['role'],
      isCasualLeave: json['isCasualLeave'],
      totalExperience: json['totalExperience']?.toString(),
      emergencyContactNumber: json['emergencyContactNumber']?.toString(),
      isSubAdmin: json['isSubAdmin'] ?? false,
      userId: json['userId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'fcmToken': fcmToken,
      'isAdmin': isAdmin,
      'profileImageUrl': profileImageUrl,
      'employeeId': employeeId,
      'department': department,
      'createdAt': createdAt,
      'joiningDate': joiningDate,
      'role': role,
      'isCasualLeave': isCasualLeave,
      'totalExperience': totalExperience,
      'emergencyContactNumber': emergencyContactNumber,
      'isSubAdmin': isSubAdmin,
      'userId': userId,
    };
  }
}
