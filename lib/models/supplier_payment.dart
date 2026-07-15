/// عملية سداد لمورد. لا تُنشئ أي شاشة في هذا التطبيق سجلاً هنا بعد — البنية
/// جاهزة فقط ليتم السداد مستقبلاً من قسم الموردين أو المركز المالي، وتُحدَّث
/// كشوف الحسابات تلقائياً فور توفر تلك الشاشة.
class SupplierPayment {
  final int? id;
  final int hotelId;
  final int supplierId;
  final double amount;
  final String? method;
  final String date;
  final String? notes;
  final String createdAt;

  const SupplierPayment({
    this.id,
    required this.hotelId,
    required this.supplierId,
    required this.amount,
    this.method,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'supplier_id': supplierId,
      'amount': amount,
      'method': method,
      'date': date,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupplierPayment(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      supplierId: map['supplier_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      method: map['method'] as String?,
      date: map['date'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
