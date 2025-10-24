class UserModel {
  final String id;
  final String name;
  final String email;
  final String fcmToken;
  final bool isAdmin;
  final String? profileImageUrl;
  final String? employeeId;
  final String? department;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.fcmToken,
    required this.isAdmin,
    this.profileImageUrl,
    this.employeeId,
    this.department,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      fcmToken: json['fcmToken'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      profileImageUrl: json['profileImageUrl'],
      employeeId: json['employeeId'],
      department: json['department'],
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
    };
  }
}
