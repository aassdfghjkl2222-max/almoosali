/// تصنيف مصروف موحّد على مستوى التطبيق بالكامل (hotelId يبقى دوماً null بعد
/// التوحيد — أُبقي عليه في النموذج فقط لتوافق قراءة صفوف قديمة إن وُجدت).
class ExpenseCategory {
  final int? id;
  final int? hotelId;
  final String name;
  final String? shortCode;
  final int usageCount;
  final bool isPinned;
  final bool isBasic;
  final bool isVisible;
  final bool isDefault;
  final int iconCode;
  final int colorValue;
  final int sortOrder;
  final String createdAt;

  ExpenseCategory({
    this.id,
    this.hotelId,
    required this.name,
    this.shortCode,
    this.usageCount = 0,
    this.isPinned = false,
    this.isBasic = false,
    this.isVisible = true,
    this.isDefault = false,
    required this.iconCode,
    required this.colorValue,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (hotelId != null) 'hotel_id': hotelId,
      'name': name,
      'short_code': shortCode,
      'usage_count': usageCount,
      'is_pinned': isPinned ? 1 : 0,
      'is_basic': isBasic ? 1 : 0,
      'is_visible': isVisible ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'icon_code': iconCode,
      'color_value': colorValue,
      'sort_order': sortOrder,
      'created_at': createdAt,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'],
      hotelId: map['hotel_id'],
      name: map['name'],
      shortCode: map['short_code'],
      usageCount: map['usage_count'] ?? 0,
      isPinned: (map['is_pinned'] ?? 0) == 1,
      isBasic: (map['is_basic'] ?? 0) == 1,
      isVisible: (map['is_visible'] ?? 1) == 1,
      isDefault: (map['is_default'] ?? 0) == 1,
      iconCode: map['icon_code'] ?? 0xe5d3,
      colorValue: map['color_value'] ?? 0xFF9E9E9E,
      sortOrder: map['sort_order'] ?? 0,
      createdAt: map['created_at'],
    );
  }

  ExpenseCategory copyWith({
    int? id,
    int? hotelId,
    String? name,
    String? shortCode,
    int? usageCount,
    bool? isPinned,
    bool? isBasic,
    bool? isVisible,
    bool? isDefault,
    int? iconCode,
    int? colorValue,
    int? sortOrder,
    String? createdAt,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      hotelId: hotelId ?? this.hotelId,
      name: name ?? this.name,
      shortCode: shortCode ?? this.shortCode,
      usageCount: usageCount ?? this.usageCount,
      isPinned: isPinned ?? this.isPinned,
      isBasic: isBasic ?? this.isBasic,
      isVisible: isVisible ?? this.isVisible,
      isDefault: isDefault ?? this.isDefault,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
