class Document {
  final int? id;
  final int? hotelId;
  final String name;
  final String expiryDate;
  final String createdAt;
  
  const Document({
    this.id,
    this.hotelId,
    required this.name,
    required this.expiryDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'name': name,
      'expiry_date': expiryDate,
      'created_at': createdAt,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int?,
      name: map['name'] as String,
      expiryDate: map['expiry_date'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}