class SettlementTransaction {
  final int? id;
  final int settlementId;
  final double amount;
  final DateTime date;
  final String? notes;
  final String amountSource;

  SettlementTransaction({
    this.id,
    required this.settlementId,
    required this.amount,
    required this.date,
    this.notes,
    this.amountSource = 'خارج النظام',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'settlement_id': settlementId,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'amount_source': amountSource,
    };
  }

  factory SettlementTransaction.fromMap(Map<String, dynamic> map) {
    return SettlementTransaction(
      id: map['id'] as int?,
      settlementId: map['settlement_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      amountSource: map['amount_source'] ?? 'خارج النظام',
    );
  }
}
