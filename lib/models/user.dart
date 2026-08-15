class User {
  final int? id;
  final String username;
  final String fullName;
  final String? phone;

  /// نص صريح قديم قبل v52 — لم يعد يُستخدَم لتسجيل الدخول (راجع passwordHash/
  /// passwordSalt)، يبقى فارغاً للمستخدمين الجدد. لا يُعرَض في أي واجهة أبداً.
  final String password;
  final String? passwordHash;
  final String? passwordSalt;

  /// 'manager' يتجاوز كل فحوصات الصلاحيات الدقيقة تلقائياً (صلاحيات إدارية
  /// كاملة) — راجع PermissionService. 'employee' يخضع لصلاحياته المحدَّدة في
  /// user_permissions/user_hotel_access.
  final String role;

  /// تسمية عرض قديمة تشير لمعرّف permission_groups — لا علاقة لها بـ [role].
  final String? roleId;
  final bool isActive;
  final String? createdAt;

  const User({
    this.id,
    required this.username,
    required this.fullName,
    this.phone,
    this.password = '',
    this.passwordHash,
    this.passwordSalt,
    this.role = 'employee',
    this.roleId,
    this.isActive = true,
    this.createdAt,
  });

  bool get isManager => role == 'manager';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'full_name': fullName,
      'phone': phone,
      'password': password,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'role': role,
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
      phone: map['phone'] as String?,
      password: map['password'] as String? ?? '',
      passwordHash: map['password_hash'] as String?,
      passwordSalt: map['password_salt'] as String?,
      role: map['role'] as String? ?? 'employee',
      roleId: map['role_id'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
    );
  }

  User copyWith({
    int? id,
    String? username,
    String? fullName,
    String? phone,
    String? password,
    String? passwordHash,
    String? passwordSalt,
    String? role,
    String? roleId,
    bool? isActive,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      role: role ?? this.role,
      roleId: roleId ?? this.roleId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
