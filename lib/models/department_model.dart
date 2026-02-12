class DepartmentModel {
  final String id;
  final String name;
  final List<String> roles;
  final DateTime? createdAt;

  DepartmentModel({
    required this.id,
    required this.name,
    required this.roles,
    this.createdAt,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      roles: List<String>.from(json['roles'] ?? []),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
                ? DateTime.parse(json['createdAt'])
                : null) // Firestore Timestamp handling would be in Provider
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roles': roles,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  DepartmentModel copyWith({
    String? id,
    String? name,
    List<String>? roles,
    DateTime? createdAt,
  }) {
    return DepartmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      roles: roles ?? this.roles,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'DepartmentModel(id: $id, name: $name, roles: $roles)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DepartmentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
