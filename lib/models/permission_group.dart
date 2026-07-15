import 'dart:convert';

/// مجموعة صلاحيات بسيطة — قائمة أسماء صلاحيات نصية حرة (مثل "عرض التقارير"،
/// "تعديل الفنادق") بدل نظام صلاحيات معقّد، تماشياً مع طلب إبقاء تصميم
/// الصلاحيات بسيطاً وسهل الفهم.
class PermissionGroup {
  final int? id;
  final String name;
  final List<String> permissions;
  final String? createdAt;

  const PermissionGroup({
    this.id,
    required this.name,
    this.permissions = const [],
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'permissions_json': jsonEncode(permissions),
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory PermissionGroup.fromMap(Map<String, dynamic> map) {
    List<String> perms = [];
    try {
      perms = List<String>.from(jsonDecode(map['permissions_json'] as String? ?? '[]'));
    } catch (_) {}
    return PermissionGroup(
      id: map['id'] as int?,
      name: map['name'] as String,
      permissions: perms,
      createdAt: map['created_at'] as String?,
    );
  }

  PermissionGroup copyWith({int? id, String? name, List<String>? permissions, String? createdAt}) {
    return PermissionGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
