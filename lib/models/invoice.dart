class Invoice {
  final int? id;
  final int hotelId;
  final String invoiceNumber;
  final String date;
  final String companyName;
  final String taxNumber;
  final double amountBeforeTax;
  final double vat;
  final double totalAmount;
  final String facilityName;
  final String amountSource;

  /// اسم التصنيف وقت حفظ الفاتورة — نسخة عرض فقط (Display Only)، لا تتغيّر
  /// أبداً لاحقاً حتى لو أُعيدت تسمية الفئة، حفاظاً على سلامة الفاتورة
  /// التاريخية كما حُفظت. قد تكون null للفواتير المضافة قبل توفر هذا الحقل
  /// أو التي لم تُصنَّف بعد.
  final String? expenseCategory;

  /// معرّف الفئة المالية الحقيقي (financial_categories.id) — المصدر الوحيد
  /// المعتمَد للفواتير المحفوظة منذ v49 (راجع تعليق جدول invoices في
  /// database_service.dart). null للفواتير الأقدم التي حُفظت باسم نصّي فقط
  /// قبل توحيد الفئات مع نظام الفواتير؛ تلك تبقى كما هي (لا تُعدَّل تاريخياً).
  final int? categoryId;

  /// طريقة الدفع الفعلية ('نقد'/'شبكة'/'دفع جزئي') — لا تنطبق على "شراء آجل"
  /// (المبلغ لم يُدفع بعد)، فتبقى null في تلك الحالة.
  final String? paymentMethod;

  /// الفندق الآخر المرتبط عندما يكون مصدر التمويل "منشأة أخرى" — يُستخدم
  /// مستقبلاً لبناء العلاقة المالية الفعلية بين المنشأتين؛ لا يُنشئ أي سجل
  /// علاقة/دين فعلي في هذه المرحلة (بنية بيانات أساسية فقط).
  final int? relatedHotelId;

  const Invoice({
    this.id,
    required this.hotelId,
    required this.invoiceNumber,
    required this.date,
    required this.companyName,
    required this.taxNumber,
    required this.amountBeforeTax,
    required this.vat,
    required this.totalAmount,
    required this.facilityName,
    this.amountSource = 'خارج النظام',
    this.expenseCategory,
    this.categoryId,
    this.paymentMethod,
    this.relatedHotelId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'invoice_number': invoiceNumber,
      'date': date,
      'company_name': companyName,
      'tax_number': taxNumber,
      'amount_before_tax': amountBeforeTax,
      'vat': vat,
      'total_amount': totalAmount,
      'facility_name': facilityName,
      'amount_source': amountSource,
      'expense_category': expenseCategory,
      'category_id': categoryId,
      'payment_method': paymentMethod,
      'related_hotel_id': relatedHotelId,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] ?? 0,
      invoiceNumber: map['invoice_number'] as String,
      date: map['date'] as String,
      companyName: map['company_name'] as String,
      taxNumber: map['tax_number'] as String,
      amountBeforeTax: (map['amount_before_tax'] as num).toDouble(),
      vat: (map['vat'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      facilityName: map['facility_name'] as String,
      amountSource: map['amount_source'] ?? 'خارج النظام',
      expenseCategory: map['expense_category'] as String?,
      categoryId: map['category_id'] as int?,
      paymentMethod: map['payment_method'] as String?,
      relatedHotelId: map['related_hotel_id'] as int?,
    );
  }
}
