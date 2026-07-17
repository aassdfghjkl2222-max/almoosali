class Supplier {
  final int? id;
  final int hotelId;
  final String officialName;
  final String shortName;
  final String taxNumber;

  /// ملاحظة اختيارية تُدخَل عند إضافة المورد — للاستخدام الداخلي فقط، لا
  /// تظهر في الفاتورة ولا PDF ولا Excel ولا التقارير.
  final String? notes;

  /// تصنيف المصروف الافتراضي لهذا المورد — نص حر بنفس اسم التصنيف (بلا ربط
  /// مباشر بجدول expense_categories، بنفس أسلوب Invoice.expenseCategory)،
  /// يُملأ تلقائياً عند مسح فاتورة QR لاحقة لنفس المورد (راجع
  /// QuickInvoiceReviewPage) بدل سؤال المستخدم عن التصنيف في كل مرة.
  final String? defaultExpenseCategory;

  Supplier({
    this.id,
    required this.hotelId,
    required this.officialName,
    required this.shortName,
    required this.taxNumber,
    this.notes,
    this.defaultExpenseCategory,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotel_id': hotelId,
      'official_name': officialName,
      'short_name': shortName,
      'tax_number': taxNumber,
      'notes': notes,
      'default_expense_category': defaultExpenseCategory,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      hotelId: map['hotel_id'] ?? 0,
      officialName: map['official_name'],
      shortName: map['short_name'],
      taxNumber: map['tax_number'],
      notes: map['notes'] as String?,
      defaultExpenseCategory: map['default_expense_category'] as String?,
    );
  }
}
