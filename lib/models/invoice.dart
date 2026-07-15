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

  /// تصنيف المصروف المرتبط بالفاتورة — نصّ حر بنفس اسم التصنيف (بلا ربط
  /// مباشر بجدول expense_categories)، بنفس أسلوب amountSource. قد يكون
  /// null للفواتير المضافة قبل توفر هذا الحقل أو التي لم تُصنَّف بعد.
  final String? expenseCategory;

  /// طريقة الدفع الفعلية ('نقد'/'بنك'/'دفع جزئي') — لا تنطبق على "شراء آجل"
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
      paymentMethod: map['payment_method'] as String?,
      relatedHotelId: map['related_hotel_id'] as int?,
    );
  }
}
