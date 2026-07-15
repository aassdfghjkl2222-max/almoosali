/// نوع مستند مرجعي — مصدر الحقيقة الوحيد على مستوى التطبيق بالكامل. `scope`
/// يحدد الفنادق التي يُزوَّد بها تلقائياً: `'all'` (كل الفنادق) أو `'specific'`
/// (فنادق مختارة، مُخزَّنة في جدول document_type_hotels المنفصل، تُقرأ عبر
/// DocumentTypeRepository.getHotelsForType — ليست جزءاً من هذا النموذج).
/// `lifecycle` يصنّف "المجلد" الذي يظهر ضمنه في قسم المستندات:
/// [lifecyclePermanent] (مستندات رسمية دائمة كالسجل التجاري والتراخيص) أو
/// [lifecycleSeasonal] (مستندات موسمية/دورية) — مستقل تماماً عن
/// [requiresRenewal] (الذي يتحكم فقط بإلزامية تاريخ الانتهاء لكل نسخة).
/// categoryName/categoryColor حقلا عرض فقط من JOIN، غير مكتوبين في toMap().
class DocumentType {
  static const lifecyclePermanent = 'permanent';
  static const lifecycleSeasonal = 'seasonal';
  static const lifecycleEmployee = 'employee';

  final int? id;
  final String name;
  final String? description;
  final int categoryId;
  final bool isMandatory;
  final bool requiresRenewal;
  final String scope; // 'all' | 'specific'
  final bool isActive;
  final int sortOrder;
  final String createdAt;
  final String lifecycle; // 'permanent' | 'seasonal'

  final String? categoryName;
  final int? categoryColor;

  const DocumentType({
    this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.isMandatory = false,
    this.requiresRenewal = false,
    this.scope = 'all',
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    this.lifecycle = lifecyclePermanent,
    this.categoryName,
    this.categoryColor,
  });

  bool get isAllHotels => scope == 'all';
  bool get isPermanent => lifecycle == lifecyclePermanent;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'is_mandatory': isMandatory ? 1 : 0,
      'requires_renewal': requiresRenewal ? 1 : 0,
      'scope': scope,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'lifecycle': lifecycle,
    };
  }

  factory DocumentType.fromMap(Map<String, dynamic> map) {
    return DocumentType(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as int,
      isMandatory: (map['is_mandatory'] as int? ?? 0) == 1,
      requiresRenewal: (map['requires_renewal'] as int? ?? 0) == 1,
      scope: map['scope'] as String? ?? 'all',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      lifecycle: map['lifecycle'] as String? ?? lifecyclePermanent,
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as int?,
    );
  }

  DocumentType copyWith({
    int? id,
    String? name,
    String? description,
    int? categoryId,
    bool? isMandatory,
    bool? requiresRenewal,
    String? scope,
    bool? isActive,
    int? sortOrder,
    String? createdAt,
    String? lifecycle,
    String? categoryName,
    int? categoryColor,
  }) {
    return DocumentType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      isMandatory: isMandatory ?? this.isMandatory,
      requiresRenewal: requiresRenewal ?? this.requiresRenewal,
      scope: scope ?? this.scope,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      lifecycle: lifecycle ?? this.lifecycle,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
    );
  }
}
