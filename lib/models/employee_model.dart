import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';

class EmployeeModel {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String? employeeId;
  final String? department;
  final String? role; // access role: admin / employee
  final String? jobRole; // actual job role from the department's roles
  final DateTime? joiningDate;
  final bool isOnboarded;
  final DateTime? createdAt;
  final String? fcmToken;
  final String? totalExperience;
  final String? emergencyContactNumber;
  final bool isSubAdmin;
  final String? mobileNumber;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.employeeId,
    this.department,
    this.role,
    this.jobRole,
    this.joiningDate,
    required this.isOnboarded,
    this.createdAt,
    this.fcmToken,
    this.totalExperience,
    this.emergencyContactNumber,
    this.isSubAdmin = false,
    this.mobileNumber,
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
      // Employees added before jobRole existed kept the job role in role
      jobRole:
          json['jobRole']?.toString() ??
          (json['role'] != null &&
                  json['role'] != AppConstants.adminRole &&
                  !AppConstants.assignableRoles.contains(json['role'])
              ? json['role'].toString()
              : null),
      joiningDate: _parseDateTime(json['joiningDate']),
      isOnboarded: json['isOnboarded'] ?? false,
      createdAt: _parseDateTime(json['createdAt']),
      fcmToken: json['fcmToken'],
      totalExperience: json['totalExperience']?.toString(),
      emergencyContactNumber: json['emergencyContactNumber']?.toString(),
      isSubAdmin: json['isSubAdmin'] ?? false,
      mobileNumber: json['mobileNumber']?.toString(),
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

  /// Sub Admin, Employee, Intern or Freelancer.
  String get roleLabel =>
      isSubAdmin ? 'Sub Admin' : AppConstants.roleLabel(role);

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
      'jobRole': jobRole,
      'joiningDate': joiningDate?.toIso8601String(),
      'isOnboarded': isOnboarded,
      'createdAt': createdAt?.toIso8601String(),
      'fcmToken': fcmToken,
      'totalExperience': totalExperience,
      'emergencyContactNumber': emergencyContactNumber,
      'isSubAdmin': isSubAdmin,
      'mobileNumber': mobileNumber,
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
    String? jobRole,
    DateTime? joiningDate,
    bool? isOnboarded,
    DateTime? createdAt,
    String? fcmToken,
    String? totalExperience,
    String? emergencyContactNumber,
    bool? isSubAdmin,
    String? mobileNumber,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      role: role ?? this.role,
      jobRole: jobRole ?? this.jobRole,
      joiningDate: joiningDate ?? this.joiningDate,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
      totalExperience: totalExperience ?? this.totalExperience,
      emergencyContactNumber: emergencyContactNumber ?? this.emergencyContactNumber,
      isSubAdmin: isSubAdmin ?? this.isSubAdmin,
      mobileNumber: mobileNumber ?? this.mobileNumber,
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