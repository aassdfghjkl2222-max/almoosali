class EntityLoan {
  final int? id;
  final int hotelId;
  final double amount;
  final String statement;
  final String source; // 'نقد' or 'حساب بنكي'
  final String date;
  final String time;
  final String createdAt;

  EntityLoan({
    this.id,
    required this.hotelId,
    required this.amount,
    required this.statement,
    required this.source,
    required this.date,
    required this.time,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotel_id': hotelId,
      'amount': amount,
      'statement': statement,
      'source': source,
      'date': date,
      'time': time,
      'created_at': createdAt,
    };
  }

  factory EntityLoan.fromMap(Map<String, dynamic> map) {
    return EntityLoan(
      id: map['id'],
      hotelId: map['hotel_id'] ?? 0,
      amount: (map['amount'] as num).toDouble(),
      statement: map['statement'],
      source: map['source'],
      date: map['date'],
      time: map['time'],
      createdAt: map['created_at'],
    );
  }
}
