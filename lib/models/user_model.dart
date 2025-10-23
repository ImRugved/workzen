class UserModel {
  final String id;
  final String name;
  final String email;
  final String fcmToken;
  final bool isAdmin;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.fcmToken,
    required this.isAdmin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      fcmToken: json['fcmToken'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'fcmToken': fcmToken,
      'isAdmin': isAdmin,
    };
  }
}
