import 'dart:convert';

class Settlement {
  final int? id;
  final String type; // 'inter_entity', 'person', 'supplier'
  final int? accountId;
  final int? creditorHotelId;
  final int? debtorHotelId;
  final double amount;
  final DateTime date;
  final String description;
  final List<String> attachments;
  final String status; // 'open', 'paid'
  final double totalPaid;
  final String? direction; // 'to_me', 'from_me'
  final DateTime createdAt;

  Settlement({
    this.id,
    required this.type,
    this.accountId,
    this.creditorHotelId,
    this.debtorHotelId,
    required this.amount,
    required this.date,
    required this.description,
    this.attachments = const [],
    this.status = 'open',
    this.totalPaid = 0,
    this.direction,
    required this.createdAt,
  });

  double get remainingAmount => amount - totalPaid;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'account_id': accountId,
      'creditor_hotel_id': creditorHotelId,
      'debtor_hotel_id': debtorHotelId,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'attachments_json': jsonEncode(attachments),
      'status': status,
      'total_paid': totalPaid,
      'direction': direction,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    List<String> attachments = [];
    if (map['attachments_json'] != null) {
      try {
        attachments = List<String>.from(jsonDecode(map['attachments_json']));
      } catch (_) {}
    }

    return Settlement(
      id: map['id'] as int?,
      type: map['type'] as String,
      accountId: map['account_id'] as int?,
      creditorHotelId: map['creditor_hotel_id'] as int?,
      debtorHotelId: map['debtor_hotel_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String,
      attachments: attachments,
      status: map['status'] as String,
      totalPaid: (map['total_paid'] as num).toDouble(),
      direction: map['direction'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
