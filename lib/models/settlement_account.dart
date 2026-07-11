class SettlementAccount {
  final int? id;
  final int hotelId;
  final String name;
  final String type; // 'person', 'supplier'
  final DateTime createdAt;

  SettlementAccount({
    this.id,
    required this.hotelId,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'name': name,
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SettlementAccount.fromMap(Map<String, dynamic> map) {
    return SettlementAccount(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] ?? 0,
      name: map['name'] as String,
      type: map['type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
