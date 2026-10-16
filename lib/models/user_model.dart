import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';

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
  final bool? isPrivilegeLeave;
  final bool? isCasualLeave;
  final String? totalExperience;
  final String? emergencyContactNumber;
  final bool isSubAdmin;
  // The actual job role picked from the department's roles (role itself is the
  // access role: admin / employee)
  final String? jobRole;
  final double? officeLatitude;
  final double? officeLongitude;
  final bool isFirstLogin; // false until the first login registers the device
  final List<String> subAdminPermissions; // what a sub admin may access

  // Personal and contact details (the employee fills these in their profile)
  final String? address;
  final String? mobileNumber;
  final String? alternateNumber;
  final String? bloodGroup;
  final DateTime? dateOfBirth;
  final String? gender; // Male / Female / Other

  // Documents (admin only)
  final String? aadharNumber;
  final String? panCardNumber;

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
    this.isPrivilegeLeave,
    this.isCasualLeave,
    this.totalExperience,
    this.emergencyContactNumber,
    this.isSubAdmin = false,
    this.jobRole,
    this.officeLatitude,
    this.officeLongitude,
    this.isFirstLogin = false,
    this.subAdminPermissions = const [],
    this.address,
    this.mobileNumber,
    this.alternateNumber,
    this.bloodGroup,
    this.dateOfBirth,
    this.gender,
    this.aadharNumber,
    this.panCardNumber,
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
      isPrivilegeLeave: json['isPrivilegeLeave'],
      isCasualLeave: json['isCasualLeave'],
      totalExperience: json['totalExperience']?.toString(),
      emergencyContactNumber: json['emergencyContactNumber']?.toString(),
      isSubAdmin: json['isSubAdmin'] ?? false,
      // Employees added before jobRole existed kept the job role in role
      jobRole:
          json['jobRole']?.toString() ??
          (json['role'] != null &&
                  json['role'] != AppConstants.adminRole &&
                  !AppConstants.assignableRoles.contains(json['role'])
              ? json['role'].toString()
              : null),
      officeLatitude: (json['officeLatitude'] as num?)?.toDouble(),
      officeLongitude: (json['officeLongitude'] as num?)?.toDouble(),
      isFirstLogin: json['isFirstLogin'] ?? false,
      subAdminPermissions: json['subAdminPermissions'] is List
          ? List<String>.from(json['subAdminPermissions'] as List)
          : const [],
      address: json['address']?.toString(),
      mobileNumber: json['mobileNumber']?.toString(),
      alternateNumber: json['alternateNumber']?.toString(),
      bloodGroup: json['bloodGroup']?.toString(),
      dateOfBirth: _parseDateTime(json['dateOfBirth']),
      gender: json['gender']?.toString(),
      aadharNumber: json['aadharNumber']?.toString(),
      panCardNumber: json['panCardNumber']?.toString(),
      userId: json['userId'],
    );
  }

  /// Admin, Sub Admin, Employee, Intern or Freelancer.
  String get roleLabel {
    if (isAdmin) return 'Admin';
    if (isSubAdmin) return 'Sub Admin';
    return AppConstants.roleLabel(role);
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
      'isPrivilegeLeave': isPrivilegeLeave,
      'isCasualLeave': isCasualLeave,
      'totalExperience': totalExperience,
      'emergencyContactNumber': emergencyContactNumber,
      'isSubAdmin': isSubAdmin,
      'jobRole': jobRole,
      'officeLatitude': officeLatitude,
      'officeLongitude': officeLongitude,
      'isFirstLogin': isFirstLogin,
      'subAdminPermissions': subAdminPermissions,
      'address': address,
      'mobileNumber': mobileNumber,
      'alternateNumber': alternateNumber,
      'bloodGroup': bloodGroup,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'aadharNumber': aadharNumber,
      'panCardNumber': panCardNumber,
      'userId': userId,
    };
  }
}
