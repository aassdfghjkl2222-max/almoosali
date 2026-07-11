class Supplier {
  final int? id;
  final int hotelId;
  final String officialName;
  final String shortName;
  final String taxNumber;

  Supplier({
    this.id,
    required this.hotelId,
    required this.officialName,
    required this.shortName,
    required this.taxNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotel_id': hotelId,
      'official_name': officialName,
      'short_name': shortName,
      'tax_number': taxNumber,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      hotelId: map['hotel_id'] ?? 0,
      officialName: map['official_name'],
      shortName: map['short_name'],
      taxNumber: map['tax_number'],
    );
  }
}
