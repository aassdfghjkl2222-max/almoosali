/// "السلفة": سحب فوري من نقد/شبكة الفندق لصالح المالك — ليست مصروفاً ولا
/// تظهر في إجمالي مصروفات أي تقرير، القيد المحاسبي (خصم فوري + ذمة owner_debt
/// على المالك) يُنفَّذ عبر FinancialEngine.recordOwnerDrawing عند الحفظ مباشرة
/// (راجع VaultRepository.addAdvanceWithdrawal)؛ هذا النموذج للتتبع/العرض فقط.
class AdvanceWithdrawal {
  final int? id;
  final int hotelId;
  final double amount;
  final String statement;
  final String method; // 'نقد' أو 'شبكة'
  final String date;
  final String time;
  final String createdAt;

  const AdvanceWithdrawal({
    this.id,
    required this.hotelId,
    required this.amount,
    required this.statement,
    required this.method,
    required this.date,
    required this.time,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'amount': amount,
      'statement': statement,
      'method': method,
      'date': date,
      'time': time,
      'created_at': createdAt,
    };
  }

  factory AdvanceWithdrawal.fromMap(Map<String, dynamic> map) {
    return AdvanceWithdrawal(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      statement: map['statement'] as String,
      method: map['method'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
