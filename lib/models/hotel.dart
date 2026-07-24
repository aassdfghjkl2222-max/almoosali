class Hotel {
  final int? id;
  final String arabicName;
  final String englishName;
  final String city;

  /// false = مؤرشَف (في سلة المحذوفات) — راجع HotelRepository.archiveHotel/restoreHotel.
  final bool active;
  final bool hasParking;
  final int? identityColorValue;
  final String? archivedAt;
  final String? archivedBy;

  const Hotel({
    this.id,
    required this.arabicName,
    required this.englishName,
    required this.city,
    this.active = true,
    this.hasParking = false,
    this.identityColorValue,
    this.archivedAt,
    this.archivedBy,
  });

  bool get isArchived => !active;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'arabic_name': arabicName,
      'english_name': englishName,
      'city': city,
      'active': active ? 1 : 0,
      'has_parking': hasParking ? 1 : 0,
      'identity_color_value': identityColorValue,
      'archived_at': archivedAt,
      'archived_by': archivedBy,
    };
  }

  factory Hotel.fromMap(Map<String, dynamic> map) {
    return Hotel(
      id: map['id'] as int?,
      arabicName: map['arabic_name'] as String,
      englishName: map['english_name'] as String,
      city: map['city'] as String,
      active: (map['active'] as int) == 1,
      hasParking: (map['has_parking'] ?? 0) == 1,
      identityColorValue: map['identity_color_value'] as int?,
      archivedAt: map['archived_at'] as String?,
      archivedBy: map['archived_by'] as String?,
    );
  }

  Hotel copyWith({
    int? id,
    String? arabicName,
    String? englishName,
    String? city,
    bool? active,
    bool? hasParking,
    int? identityColorValue,
    String? archivedAt,
    String? archivedBy,
  }) {
    return Hotel(
      id: id ?? this.id,
      arabicName: arabicName ?? this.arabicName,
      englishName: englishName ?? this.englishName,
      city: city ?? this.city,
      active: active ?? this.active,
      hasParking: hasParking ?? this.hasParking,
      identityColorValue: identityColorValue ?? this.identityColorValue,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
    );
  }
}