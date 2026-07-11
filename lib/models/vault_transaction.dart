class VaultTransaction {
  final int? id;
  final int hotelId;
  final String date;
  final String time;
  final String type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? reference;
  final String? notes;
  final String source;

  VaultTransaction({
    this.id,
    required this.hotelId,
    required this.date,
    required this.time,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.reference,
    this.notes,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotel_id': hotelId,
      'date': date,
      'time': time,
      'type': type,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'reference': reference,
      'notes': notes,
      'source': source,
    };
  }

  factory VaultTransaction.fromMap(Map<String, dynamic> map) {
    return VaultTransaction(
      id: map['id'],
      hotelId: map['hotel_id'] ?? 0,
      date: map['date'],
      time: map['time'],
      type: map['type'],
      amount: (map['amount'] as num).toDouble(),
      balanceBefore: (map['balance_before'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      reference: map['reference'],
      notes: map['notes'],
      source: map['source'],
    );
  }
}
