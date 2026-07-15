/// مستند واحد داخل محرك المستندات الموحّد — يُحفظ مرة واحدة فقط ولا تُنشأ له
/// نسخة ثانية أبداً. [ownerType]/[ownerId] مرجع متعدد الأشكال (Polymorphic)
/// لأي جهة مالكة داخل التطبيق: `'hotel'` (owner_id = hotel_id نفسه — مستند
/// خاص بالفندق مباشرة، غالباً مرتبط بنوع مرجعي عبر [documentTypeId])،
/// `'employee'` (owner_id = رقم الموظف، اسم حر بلا نوع مرجعي)، `'supplier'`
/// (owner_id = رقم المورد، مرتبط دوماً بنوع مرجعي يختاره المستخدم عند
/// الإضافة)، ومستقبلاً `'contract'`/أي كيان جديد — بلا أي تعديل معماري، فقط
/// قيمة [ownerType] جديدة.
///
/// [hotelScope] يحدد أي الفنادق يظهر المستند لها عند التصفح داخل مجلد:
/// [hotelScopeSingle] (فندق [hotelId] وحده — الاصطلاح الافتراضي لكل مستندات
/// الفندق التلقائية)، [hotelScopeAll] (كل الفنادق، تُحسَب ديناميكياً)،
/// [hotelScopeSpecific] (مجموعة فنادق مُخزَّنة في جدول document_hotels
/// المنفصل، تُقرأ عبر DocumentRepository.getHotelIdsForDocument).
///
/// المستند نفسه قد يظهر داخل أكثر من مجلد (نوع مرجعي) عبر جدول المراجع
/// document_folder_links — دون أي نسخ للملف أو للسجل (مبدأ References).
///
/// إن كان [documentTypeId] فارغاً فالمستند "غير مرتبط بنوع مرجعي" (بيانات
/// سابقة على النظام المرجعي، أو مستند حر مثل مستندات الموظفين حالياً) —
/// راجع [isLinkedToType]. حقول العرض (typeName, typeDescription, isMandatory,
/// requiresRenewal, categoryName, categoryColor, hotelName) تُملأ فقط عبر
/// JOIN حي، وليست أعمدة حقيقية، فلا تُكتب عبر toMap().
class Document {
  static const ownerTypeHotel = 'hotel';
  static const ownerTypeEmployee = 'employee';
  static const ownerTypeSupplier = 'supplier';

  static const hotelScopeSingle = 'single';
  static const hotelScopeAll = 'all';
  static const hotelScopeSpecific = 'specific';

  final int? id;
  final int? hotelId;
  final String name;
  final String expiryDate;
  final String createdAt;
  final int? documentTypeId;
  final String? documentNumber;
  final String? issueDate;
  final String? issuingAuthority;
  final String? notes;
  final String ownerType;
  final int? ownerId;
  final String hotelScope;

  final String? typeName;
  final String? typeDescription;
  final bool isMandatory;
  final bool requiresRenewal;
  final String? categoryName;
  final int? categoryColor;
  final String? hotelName;

  const Document({
    this.id,
    this.hotelId,
    required this.name,
    required this.expiryDate,
    required this.createdAt,
    this.documentTypeId,
    this.documentNumber,
    this.issueDate,
    this.issuingAuthority,
    this.notes,
    this.ownerType = ownerTypeHotel,
    this.ownerId,
    this.hotelScope = hotelScopeSingle,
    this.typeName,
    this.typeDescription,
    this.isMandatory = false,
    this.requiresRenewal = false,
    this.categoryName,
    this.categoryColor,
    this.hotelName,
  });

  bool get isLinkedToType => documentTypeId != null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'name': name,
      'expiry_date': expiryDate,
      'created_at': createdAt,
      'document_type_id': documentTypeId,
      'document_number': documentNumber,
      'issue_date': issueDate,
      'issuing_authority': issuingAuthority,
      'notes': notes,
      'owner_type': ownerType,
      'owner_id': ownerId,
      'hotel_scope': hotelScope,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int?,
      name: map['name'] as String,
      expiryDate: map['expiry_date'] as String,
      createdAt: map['created_at'] as String,
      documentTypeId: map['document_type_id'] as int?,
      documentNumber: map['document_number'] as String?,
      issueDate: map['issue_date'] as String?,
      issuingAuthority: map['issuing_authority'] as String?,
      notes: map['notes'] as String?,
      ownerType: map['owner_type'] as String? ?? ownerTypeHotel,
      ownerId: map['owner_id'] as int?,
      hotelScope: map['hotel_scope'] as String? ?? hotelScopeSingle,
      typeName: map['type_name'] as String?,
      typeDescription: map['type_description'] as String?,
      isMandatory: (map['is_mandatory'] as int? ?? 0) == 1,
      requiresRenewal: (map['requires_renewal'] as int? ?? 0) == 1,
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as int?,
      hotelName: map['hotel_name'] as String?,
    );
  }

  Document copyWith({
    int? id,
    int? hotelId,
    String? name,
    String? expiryDate,
    String? createdAt,
    int? documentTypeId,
    String? documentNumber,
    String? issueDate,
    String? issuingAuthority,
    String? notes,
    String? ownerType,
    int? ownerId,
    String? hotelScope,
    String? typeName,
    String? typeDescription,
    bool? isMandatory,
    bool? requiresRenewal,
    String? categoryName,
    int? categoryColor,
    String? hotelName,
  }) {
    return Document(
      id: id ?? this.id,
      hotelId: hotelId ?? this.hotelId,
      name: name ?? this.name,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      documentTypeId: documentTypeId ?? this.documentTypeId,
      documentNumber: documentNumber ?? this.documentNumber,
      issueDate: issueDate ?? this.issueDate,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      notes: notes ?? this.notes,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      hotelScope: hotelScope ?? this.hotelScope,
      typeName: typeName ?? this.typeName,
      typeDescription: typeDescription ?? this.typeDescription,
      isMandatory: isMandatory ?? this.isMandatory,
      requiresRenewal: requiresRenewal ?? this.requiresRenewal,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      hotelName: hotelName ?? this.hotelName,
    );
  }
}
