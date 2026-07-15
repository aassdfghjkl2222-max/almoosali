/// فئة نوع مستند مرجعي — موحّدة على مستوى التطبيق بالكامل، قابلة للإدارة
/// (إضافة/تعديل/حذف إن لم تكن مستخدمة) من شاشة إدارة الفئات.
class DocumentCategory {
  final int? id;
  final String name;
  final int colorValue;
  final String createdAt;

  const DocumentCategory({
    this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color_value': colorValue,
      'created_at': createdAt,
    };
  }

  factory DocumentCategory.fromMap(Map<String, dynamic> map) {
    return DocumentCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorValue: map['color_value'] as int,
      createdAt: map['created_at'] as String,
    );
  }

  DocumentCategory copyWith({int? id, String? name, int? colorValue, String? createdAt}) {
    return DocumentCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
