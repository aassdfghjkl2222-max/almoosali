/// "المصروف المشترك": مصروف واحد تدفعه منشأة [fundingHotelId] بالكامل من
/// [paymentMethod]، ويُوزَّع أثره على عدة منشآت مشارِكة عبر [SharedExpenseShare].
/// هذا الجدول للتتبع/العرض فقط — القيود المحاسبية الفعلية تُنفَّذ فوراً عند
/// الحفظ عبر FinancialEngine.recordSharedExpense (راجع SharedExpenseRepository).
class SharedExpenseGroup {
  final int? id;
  final String description;
  final int categoryId;
  final double totalAmount;
  final String paymentMethod; // نقد / شبكة
  final int fundingHotelId;
  final String date;
  final String time;
  final String createdAt;

  const SharedExpenseGroup({
    this.id,
    required this.description,
    required this.categoryId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.fundingHotelId,
    required this.date,
    required this.time,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'description': description,
      'category_id': categoryId,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'funding_hotel_id': fundingHotelId,
      'date': date,
      'time': time,
      'created_at': createdAt,
    };
  }

  factory SharedExpenseGroup.fromMap(Map<String, dynamic> map) {
    return SharedExpenseGroup(
      id: map['id'] as int?,
      description: map['description'] as String,
      categoryId: map['category_id'] as int,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      fundingHotelId: map['funding_hotel_id'] as int,
      date: map['date'] as String,
      time: map['time'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
