/// رأس "المصروف المشترك" — مصروف واحد يُوزَّع تلقائياً كمصروفات معلَّقة
/// مستقلة على عدة منشآت (راجع SharedExpenseDistributionRepository وتعليق
/// جدول shared_expenses في database_service.dart، ترحيل v47). [reference]
/// معرّف بشري ثابت مبني من [id] مباشرة (SE-000001) — بلا عداد منفصل، فلا
/// يمكن أن يتكرر أو تظهر فيه فجوة غير متوقعة.
class SharedExpense {
  final int? id;
  final int categoryId;
  final String? categoryName; // عرض فقط من JOIN
  final String? description;
  final double totalAmount;
  final String fundingSource; // نقد / الخزنة / شبكة / شخصي (راجع PendingExpense)
  final String date;
  final String? notes;
  final String? createdBy;
  final String createdAt;
  final String? updatedAt;

  const SharedExpense({
    this.id,
    required this.categoryId,
    this.categoryName,
    this.description,
    required this.totalAmount,
    required this.fundingSource,
    required this.date,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  static const fundingCash = 'نقد';
  static const fundingTreasury = 'الخزنة';
  static const fundingNetwork = 'شبكة';
  static const fundingOwner = 'شخصي';

  static const List<String> fundingSources = [fundingCash, fundingTreasury, fundingNetwork, fundingOwner];

  String get reference => 'SE-${(id ?? 0).toString().padLeft(6, '0')}';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'description': description,
      'total_amount': totalAmount,
      'funding_source': fundingSource,
      'date': date,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory SharedExpense.fromMap(Map<String, dynamic> map) {
    return SharedExpense(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String?,
      description: map['description'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      fundingSource: map['funding_source'] as String,
      date: map['date'] as String,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }

  SharedExpense copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    String? description,
    double? totalAmount,
    String? fundingSource,
    String? date,
    String? notes,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
  }) {
    return SharedExpense(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      fundingSource: fundingSource ?? this.fundingSource,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
