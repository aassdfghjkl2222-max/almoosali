/// فئة مالية موحَّدة (مصروف أو إيراد) — المصدر الوحيد لتصنيفات أي عملية مالية
/// في التطبيق بالكامل (راجع تعليق جدول financial_categories في
/// database_service.dart، ترحيل v48، لسبب توحيد expense_categories/
/// financial_report_items القديمين هنا). [parentId] تسلسل هرمي ذاتي الإشارة
/// جاهز للمستقبل (غير مُستخدَم في واجهات الاختيار الحالية بعد).
class FinancialCategory {
  static const typeExpense = 'expense';
  static const typeRevenue = 'revenue';

  final int? id;
  final String? code;
  final String name;
  final String type;
  final int? parentId;
  final int usageCount;
  final bool isPinned;
  final bool isBasic;
  final bool isVisible;
  final bool isDefault;
  final int iconCode;
  final int colorValue;
  final String? defaultFundingSource;
  final String? description;
  final int sortOrder;
  final String? createdBy;
  final String? lastUsedAt;
  final String createdAt;
  final String? updatedAt;

  const FinancialCategory({
    this.id,
    this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.usageCount = 0,
    this.isPinned = false,
    this.isBasic = false,
    this.isVisible = true,
    this.isDefault = false,
    required this.iconCode,
    required this.colorValue,
    this.defaultFundingSource,
    this.description,
    this.sortOrder = 0,
    this.createdBy,
    this.lastUsedAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isArchived => !isVisible;
  bool get isExpense => type == typeExpense;
  bool get isRevenue => type == typeRevenue;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'name': name,
      'type': type,
      'parent_id': parentId,
      'usage_count': usageCount,
      'is_pinned': isPinned ? 1 : 0,
      'is_basic': isBasic ? 1 : 0,
      'is_visible': isVisible ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'icon_code': iconCode,
      'color_value': colorValue,
      'default_funding_source': defaultFundingSource,
      'description': description,
      'sort_order': sortOrder,
      'created_by': createdBy,
      'last_used_at': lastUsedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory FinancialCategory.fromMap(Map<String, dynamic> map) {
    return FinancialCategory(
      id: map['id'] as int?,
      code: map['code'] as String?,
      name: map['name'] as String,
      type: map['type'] as String? ?? typeExpense,
      parentId: map['parent_id'] as int?,
      usageCount: map['usage_count'] as int? ?? 0,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isBasic: (map['is_basic'] as int? ?? 0) == 1,
      isVisible: (map['is_visible'] as int? ?? 1) == 1,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      iconCode: map['icon_code'] as int? ?? 0xe5d3,
      colorValue: map['color_value'] as int? ?? 0xFF9E9E9E,
      defaultFundingSource: map['default_funding_source'] as String?,
      description: map['description'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdBy: map['created_by'] as String?,
      lastUsedAt: map['last_used_at'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }

  FinancialCategory copyWith({
    int? id,
    String? code,
    String? name,
    String? type,
    int? parentId,
    bool clearParentId = false,
    int? usageCount,
    bool? isPinned,
    bool? isBasic,
    bool? isVisible,
    bool? isDefault,
    int? iconCode,
    int? colorValue,
    String? defaultFundingSource,
    String? description,
    int? sortOrder,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
  }) {
    return FinancialCategory(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      usageCount: usageCount ?? this.usageCount,
      isPinned: isPinned ?? this.isPinned,
      isBasic: isBasic ?? this.isBasic,
      isVisible: isVisible ?? this.isVisible,
      isDefault: isDefault ?? this.isDefault,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      defaultFundingSource: defaultFundingSource ?? this.defaultFundingSource,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
