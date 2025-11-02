import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeModel {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String? employeeId;
  final String? department;
  final String? role;
  final DateTime? joiningDate;
  final bool isOnboarded;
  final DateTime? createdAt;
  final String? fcmToken;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.employeeId,
    this.department,
    this.role,
    this.joiningDate,
    required this.isOnboarded,
    this.createdAt,
    this.fcmToken,
  });

  // Factory constructor to create EmployeeModel from JSON
  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      employeeId: json['employeeId'],
      department: json['department'],
      role: json['role'],
      joiningDate: _parseDateTime(json['joiningDate']),
      isOnboarded: json['isOnboarded'] ?? false,
      createdAt: _parseDateTime(json['createdAt']),
      fcmToken: json['fcmToken'],
    );
  }

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

  // Method to convert EmployeeModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'employeeId': employeeId,
      'department': department,
      'role': role,
      'joiningDate': joiningDate?.toIso8601String(),
      'isOnboarded': isOnboarded,
      'createdAt': createdAt?.toIso8601String(),
      'fcmToken': fcmToken,
    };
  }

  // Method to create a copy of EmployeeModel with updated fields
  EmployeeModel copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImageUrl,
    String? employeeId,
    String? department,
    String? role,
    DateTime? joiningDate,
    bool? isOnboarded,
    DateTime? createdAt,
    String? fcmToken,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      role: role ?? this.role,
      joiningDate: joiningDate ?? this.joiningDate,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  @override
  String toString() {
    return 'EmployeeModel(id: $id, name: $name, email: $email, employeeId: $employeeId, role: $role, isOnboarded: $isOnboarded)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}