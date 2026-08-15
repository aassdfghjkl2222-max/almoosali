/// النماذج المطابقة لفواتير الشراء الضريبية — راجع
/// supabase/migrations/20260730000002_phase3_operational_money_flow.sql.
/// [funding_source_type] يطابق kInvoiceFundingSources الخمسة في التطبيق
/// المحلي بأكواد إنجليزية مستقرة (راجع تعليق الجدول في migration).
library;

class SupaInvoice {
  static const fundingHotelSafe = 'hotel_safe';
  static const fundingOwner = 'owner';
  static const fundingOtherHotel = 'other_hotel';
  static const fundingPersonalExpense = 'personal_expense';
  static const fundingDeferredSupplier = 'deferred_supplier';

  final String? id;
  final String hotelId;
  final String supplierId;
  final String invoiceNumber;
  final String invoiceDate;
  final double amountBeforeTax;
  final double vat;
  final double totalAmount;
  final String categoryId;
  final String fundingSourceType;
  final String? paymentMethod;
  final String? relatedHotelId;
  final String? createdAt;
  final String? updatedAt;

  const SupaInvoice({
    this.id,
    required this.hotelId,
    required this.supplierId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.amountBeforeTax,
    required this.vat,
    required this.totalAmount,
    required this.categoryId,
    required this.fundingSourceType,
    this.paymentMethod,
    this.relatedHotelId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDeferred => fundingSourceType == fundingDeferredSupplier;

  factory SupaInvoice.fromMap(Map<String, dynamic> map) {
    return SupaInvoice(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      supplierId: map['supplier_id'] as String,
      invoiceNumber: map['invoice_number'] as String,
      invoiceDate: map['invoice_date'] as String,
      amountBeforeTax: (map['amount_before_tax'] as num).toDouble(),
      vat: (map['vat'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      categoryId: map['category_id'] as String,
      fundingSourceType: map['funding_source_type'] as String,
      paymentMethod: map['payment_method'] as String?,
      relatedHotelId: map['related_hotel_id'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}

class SupaSupplierDebt {
  final String? id;
  final String hotelId;
  final String supplierId;
  final String invoiceId;
  final double amount;
  final String status; // 'unpaid' | 'partially_paid' | 'paid'

  const SupaSupplierDebt({
    this.id,
    required this.hotelId,
    required this.supplierId,
    required this.invoiceId,
    required this.amount,
    this.status = 'unpaid',
  });

  factory SupaSupplierDebt.fromMap(Map<String, dynamic> map) {
    return SupaSupplierDebt(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      supplierId: map['supplier_id'] as String,
      invoiceId: map['invoice_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String? ?? 'unpaid',
    );
  }
}

class SupaSupplierPayment {
  final String? id;
  final String hotelId;
  final String supplierId;
  final double amount;
  final String? method;
  final String paymentDate;
  final String? notes;

  const SupaSupplierPayment({
    this.id,
    required this.hotelId,
    required this.supplierId,
    required this.amount,
    this.method,
    required this.paymentDate,
    this.notes,
  });

  Map<String, dynamic> toInsertMap() => {
        'hotel_id': hotelId,
        'supplier_id': supplierId,
        'amount': amount,
        'method': method,
        'payment_date': paymentDate,
        'notes': notes,
      };

  factory SupaSupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupaSupplierPayment(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      supplierId: map['supplier_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      method: map['method'] as String?,
      paymentDate: map['payment_date'] as String,
      notes: map['notes'] as String?,
    );
  }
}
