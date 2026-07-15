/// مديونية على الفندق لصالح مورد — تُنشأ تلقائياً وبشكل فريد (invoice_id
/// فريد في قاعدة البيانات) عند حفظ فاتورة "شراء آجل"، ولا يُسمح بوجود أكثر
/// من مديونية واحدة لنفس الفاتورة.
class SupplierDebt {
  final int? id;
  final int hotelId;
  final int supplierId;
  final int invoiceId;
  final double amount;
  final String createdAt;

  const SupplierDebt({
    this.id,
    required this.hotelId,
    required this.supplierId,
    required this.invoiceId,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'supplier_id': supplierId,
      'invoice_id': invoiceId,
      'amount': amount,
      'created_at': createdAt,
    };
  }

  factory SupplierDebt.fromMap(Map<String, dynamic> map) {
    return SupplierDebt(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      supplierId: map['supplier_id'] as int,
      invoiceId: map['invoice_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      createdAt: map['created_at'] as String,
    );
  }
}
