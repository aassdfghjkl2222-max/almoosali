class FinancialTransaction {
  final int? id;
  final int hotelId;
  final int accountId;
  final String date;
  final String time;
  final String type; // 'debit' (+), 'credit' (-)
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String description;
  final int? referenceId;
  final String? referenceType;

  FinancialTransaction({
    this.id,
    required this.hotelId,
    required this.accountId,
    required this.date,
    required this.time,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.description,
    this.referenceId,
    this.referenceType,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'account_id': accountId,
      'date': date,
      'time': time,
      'type': type,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'description': description,
      'reference_id': referenceId,
      'reference_type': referenceType,
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      accountId: map['account_id'] as int,
      date: map['date'] as String,
      time: map['time'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      balanceBefore: (map['balance_before'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      description: map['description'] as String,
      referenceId: map['reference_id'] as int?,
      referenceType: map['reference_type'] as String?,
    );
  }
}
