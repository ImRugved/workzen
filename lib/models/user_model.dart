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
    String? userId,
  }) : userId = userId ?? id;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      fcmToken: json['fcmToken'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      profileImageUrl: json['profileImageUrl'],
      employeeId: json['employeeId']?.toString(), // Convert to string if it's an int
      department: json['department'],
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'].millisecondsSinceEpoch)
          : null,
      joiningDate: json['joiningDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['joiningDate'].millisecondsSinceEpoch)
          : null,
      role: json['role'],
      isCasualLeave: json['isCasualLeave'],
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
      'userId': userId,
    };
  }
}
