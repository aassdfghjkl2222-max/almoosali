class FinancialAccount {
  final int? id;
  final int hotelId;
  final String name;
  final String type; // 'asset', 'liability'
  final String category; // 'cash', 'bank', 'personal', 'entity'
  final double balance;

  FinancialAccount({
    this.id,
    required this.hotelId,
    required this.name,
    required this.type,
    required this.category,
    this.balance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'name': name,
      'type': type,
      'category': category,
      'balance': balance,
    };
  }

  factory FinancialAccount.fromMap(Map<String, dynamic> map) {
    return FinancialAccount(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      name: map['name'] as String,
      type: map['type'] as String,
      category: map['category'] as String,
      balance: (map['balance'] as num).toDouble(),
    );
  }
}
