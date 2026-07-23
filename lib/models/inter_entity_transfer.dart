/// "التحويل بين المنشآت": تحويل مباشر لمبلغ من [fromHotelId] إلى [toHotelId]
/// بلا مصروف مرتبط — ليس مصروفاً ولا يظهر في إجمالي مصروفات أي تقرير. القيد
/// المحاسبي (ذمة فورية: المستقبِل مدين للمرسِل) يُنفَّذ عبر
/// FinancialEngine.recordTransaction بآلية entity_/receivable_entity عند
/// الحفظ مباشرة (راجع InterEntityTransferRepository)؛ هذا النموذج للتتبع/العرض فقط.
class InterEntityTransfer {
  final int? id;
  final int fromHotelId;
  final int toHotelId;
  final double amount;
  final String statement;
  final String date;
  final String time;
  final String createdAt;

  const InterEntityTransfer({
    this.id,
    required this.fromHotelId,
    required this.toHotelId,
    required this.amount,
    required this.statement,
    required this.date,
    required this.time,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'from_hotel_id': fromHotelId,
      'to_hotel_id': toHotelId,
      'amount': amount,
      'statement': statement,
      'date': date,
      'time': time,
      'created_at': createdAt,
    };
  }

  factory InterEntityTransfer.fromMap(Map<String, dynamic> map) {
    return InterEntityTransfer(
      id: map['id'] as int?,
      fromHotelId: map['from_hotel_id'] as int,
      toHotelId: map['to_hotel_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      statement: map['statement'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
