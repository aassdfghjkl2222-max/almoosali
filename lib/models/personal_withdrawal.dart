class PersonalWithdrawal {
  final int? id;
  final int hotelId;
  final double amount;
  final String statement;
  final String method; // 'نقد' or 'شبكة'
  final String date;
  final String time;
  final String createdAt;

  PersonalWithdrawal({
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
      'id': id,
      'hotel_id': hotelId,
      'amount': amount,
      'statement': statement,
      'method': method,
      'date': date,
      'time': time,
      'created_at': createdAt,
    };
  }

  factory PersonalWithdrawal.fromMap(Map<String, dynamic> map) {
    return PersonalWithdrawal(
      id: map['id'],
      hotelId: map['hotel_id'] ?? 0,
      amount: (map['amount'] as num).toDouble(),
      statement: map['statement'],
      method: map['method'],
      date: map['date'],
      time: map['time'],
      createdAt: map['created_at'],
    );
  }
}
