class Hotel {
  final int? id;
  final String arabicName;
  final String englishName;
  final String city;

  /// false = مؤرشَف (في سلة المحذوفات) — راجع HotelRepository.archiveHotel/restoreHotel.
  /// يبقى العلم الوحيد الذي تعتمد عليه استعلامات "نشط/مؤرشَف" (بلا تغيير)؛
  /// [status] تصنيف تشغيلي أدق يُستخدَم للعرض فقط فوقه.
  final bool active;
  final bool hasParking;
  final int? identityColorValue;
  final String? archivedAt;
  final String? archivedBy;
  final String? archiveReason;

  /// 'active' | 'inactive' | 'maintenance' | 'opening_soon' | 'archived'
  /// راجع HotelStatus في hotel_color_palettes.dart للتسميات/الألوان الموحَّدة.
  final String status;

  // ---------------- عام ----------------
  final String? hotelCode;
  final String? description;

  // ---------------- الموقع ----------------
  final String? country;
  final String? district;
  final String? address;
  final String? mapsLink;

  // ---------------- التواصل ----------------
  final String? phone;
  final String? mobile;
  final String? whatsapp;
  final String? email;
  final String? website;

  // ---------------- معلومات الفندق ----------------
  final int? starRating;
  final int? roomsCount;
  final String? openingDate;
  final String? notes;

  // ---------------- الهوية البصرية ----------------
  final int? secondaryColorValue;

  /// مسارا الشعار وصورة الغلاف — حقلان مُعَدَّان للمستقبل فقط (راجع تعليق
  /// HotelWizardPage): لا توجد بعد أي شاشة رفع/التقاط فعلية تكتب فيهما، ولا
  /// أي شاشة تقرأهما لعرض شعار حقيقي بدل الأيقونة الرمزية الحالية.
  final String? logoPath;
  final String? coverImagePath;

  /// إعدادات إقليمية لكل فندق — حقول قابلة للتخزين فقط حالياً (راجع تعليق
  /// HotelWizardPage): لا يقرأها أي تقرير/شاشة تنسيق مبالغ أو تواريخ بعد،
  /// فالتطبيق بأكمله لا يزال يفترض SAR/عربي/التوقيت المحلي في كل مكان آخر.
  final String? currency;
  final String? language;
  final String? timeZone;
  final String? dateFormat;
  final String? timeFormat;

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
    this.archiveReason,
    this.status = 'active',
    this.hotelCode,
    this.description,
    this.country,
    this.district,
    this.address,
    this.mapsLink,
    this.phone,
    this.mobile,
    this.whatsapp,
    this.email,
    this.website,
    this.starRating,
    this.roomsCount,
    this.openingDate,
    this.notes,
    this.secondaryColorValue,
    this.logoPath,
    this.coverImagePath,
    this.currency,
    this.language,
    this.timeZone,
    this.dateFormat,
    this.timeFormat,
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
      'archive_reason': archiveReason,
      'status': status,
      'hotel_code': hotelCode,
      'description': description,
      'country': country,
      'district': district,
      'address': address,
      'maps_link': mapsLink,
      'phone': phone,
      'mobile': mobile,
      'whatsapp': whatsapp,
      'email': email,
      'website': website,
      'star_rating': starRating,
      'rooms_count': roomsCount,
      'opening_date': openingDate,
      'notes': notes,
      'secondary_color_value': secondaryColorValue,
      'logo_path': logoPath,
      'cover_image_path': coverImagePath,
      'currency': currency,
      'language': language,
      'time_zone': timeZone,
      'date_format': dateFormat,
      'time_format': timeFormat,
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
      archiveReason: map['archive_reason'] as String?,
      status: (map['status'] as String?) ?? 'active',
      hotelCode: map['hotel_code'] as String?,
      description: map['description'] as String?,
      country: map['country'] as String?,
      district: map['district'] as String?,
      address: map['address'] as String?,
      mapsLink: map['maps_link'] as String?,
      phone: map['phone'] as String?,
      mobile: map['mobile'] as String?,
      whatsapp: map['whatsapp'] as String?,
      email: map['email'] as String?,
      website: map['website'] as String?,
      starRating: map['star_rating'] as int?,
      roomsCount: map['rooms_count'] as int?,
      openingDate: map['opening_date'] as String?,
      notes: map['notes'] as String?,
      secondaryColorValue: map['secondary_color_value'] as int?,
      logoPath: map['logo_path'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      currency: map['currency'] as String?,
      language: map['language'] as String?,
      timeZone: map['time_zone'] as String?,
      dateFormat: map['date_format'] as String?,
      timeFormat: map['time_format'] as String?,
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
    String? archiveReason,
    String? status,
    String? hotelCode,
    String? description,
    String? country,
    String? district,
    String? address,
    String? mapsLink,
    String? phone,
    String? mobile,
    String? whatsapp,
    String? email,
    String? website,
    int? starRating,
    int? roomsCount,
    String? openingDate,
    String? notes,
    int? secondaryColorValue,
    String? logoPath,
    String? coverImagePath,
    String? currency,
    String? language,
    String? timeZone,
    String? dateFormat,
    String? timeFormat,
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
      archiveReason: archiveReason ?? this.archiveReason,
      status: status ?? this.status,
      hotelCode: hotelCode ?? this.hotelCode,
      description: description ?? this.description,
      country: country ?? this.country,
      district: district ?? this.district,
      address: address ?? this.address,
      mapsLink: mapsLink ?? this.mapsLink,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      website: website ?? this.website,
      starRating: starRating ?? this.starRating,
      roomsCount: roomsCount ?? this.roomsCount,
      openingDate: openingDate ?? this.openingDate,
      notes: notes ?? this.notes,
      secondaryColorValue: secondaryColorValue ?? this.secondaryColorValue,
      logoPath: logoPath ?? this.logoPath,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      timeZone: timeZone ?? this.timeZone,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
    );
  }
}
