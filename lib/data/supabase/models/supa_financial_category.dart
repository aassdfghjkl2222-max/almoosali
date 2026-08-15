/// النموذج المطابق لجدول `financial_categories` في Supabase (Postgres) —
/// راجع supabase/migrations/20260728000002_phase2_financial_core.sql. مستقل
/// تماماً عن lib/models/financial_category.dart (نموذج SQLite المحلي، يستخدم
/// id صحيحاً لا uuid) — طبقتا بيانات منفصلتان بحكم اختلاف قاعدتي البيانات
/// الفعليتين، وليس تكراراً غير مقصود.
class SupaFinancialCategory {
  static const typeExpense = 'expense';
  static const typeRevenue = 'revenue';

  final String? id;
  final String name;
  final String? code;
  final String type;
  final String? parentId;
  final int iconCode;
  final int colorValue;
  final String? description;
  final int sortOrder;
  final bool isPinned;
  final bool isDefault;
  final int usageCount;
  final String? lastUsedAt;
  final String? archivedAt;
  final String? archivedBy;
  final String? createdAt;
  final String? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const SupaFinancialCategory({
    this.id,
    required this.name,
    this.code,
    required this.type,
    this.parentId,
    required this.iconCode,
    required this.colorValue,
    this.description,
    this.sortOrder = 0,
    this.isPinned = false,
    this.isDefault = false,
    this.usageCount = 0,
    this.lastUsedAt,
    this.archivedAt,
    this.archivedBy,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  bool get isArchived => archivedAt != null;
  bool get isExpense => type == typeExpense;
  bool get isRevenue => type == typeRevenue;

  /// حقول قابلة للإدراج/التعديل فقط — لا يُرسَل id/created_at/updated_at
  /// (تُديرها قاعدة البيانات نفسها: default gen_random_uuid()، والمُشغِّل
  /// set_updated_at). أرسل archived_at/archived_by صراحة فقط عبر toArchiveMap.
  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'code': code,
      'type': type,
      'parent_id': parentId,
      'icon_code': iconCode,
      'color_value': colorValue,
      'description': description,
      'sort_order': sortOrder,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'code': code,
      'parent_id': parentId,
      'icon_code': iconCode,
      'color_value': colorValue,
      'description': description,
      'sort_order': sortOrder,
      // type متعمَّد غير قابل للتعديل هنا — التبويب في الواجهة يُثبِّته أصلاً،
      // ونفس المبدأ المعتمد في النسخة المحلية (SQLite).
    };
  }

  factory SupaFinancialCategory.fromMap(Map<String, dynamic> map) {
    return SupaFinancialCategory(
      id: map['id'] as String?,
      name: map['name'] as String,
      code: map['code'] as String?,
      type: map['type'] as String? ?? typeExpense,
      parentId: map['parent_id'] as String?,
      iconCode: map['icon_code'] as int,
      colorValue: map['color_value'] as int,
      description: map['description'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isPinned: map['is_pinned'] as bool? ?? false,
      isDefault: map['is_default'] as bool? ?? false,
      usageCount: map['usage_count'] as int? ?? 0,
      lastUsedAt: map['last_used_at'] as String?,
      archivedAt: map['archived_at'] as String?,
      archivedBy: map['archived_by'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      createdBy: map['created_by'] as String?,
      updatedBy: map['updated_by'] as String?,
    );
  }

  SupaFinancialCategory copyWith({
    String? id,
    String? name,
    String? code,
    String? type,
    String? parentId,
    bool clearParentId = false,
    int? iconCode,
    int? colorValue,
    String? description,
    int? sortOrder,
    bool? isPinned,
    bool? isDefault,
    int? usageCount,
    String? lastUsedAt,
    String? archivedAt,
    String? archivedBy,
  }) {
    return SupaFinancialCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isPinned: isPinned ?? this.isPinned,
      isDefault: isDefault ?? this.isDefault,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }
}
