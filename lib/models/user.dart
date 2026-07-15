class User {
  final int? id;
  final String username;
  final String fullName;
  final String password;
  final String? roleId;
  final bool isActive;
  final String? createdAt;

  const User({
    this.id,
    required this.username,
    required this.fullName,
    required this.password,
    this.roleId,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'full_name': fullName,
      'password': password,
      'role_id': roleId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      password: map['password'] as String,
      roleId: map['role_id'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
    );
  }

  User copyWith({
    int? id,
    String? username,
    String? fullName,
    String? password,
    String? roleId,
    bool? isActive,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      password: password ?? this.password,
      roleId: roleId ?? this.roleId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
