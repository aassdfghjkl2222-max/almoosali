/// يطابق جدول `suppliers` — راجع
/// supabase/migrations/20260730000002_phase3_operational_money_flow.sql.
class SupaSupplier {
  final String? id;
  final String hotelId;
  final String officialName;
  final String shortName;
  final String taxNumber;
  final String? defaultCategoryId;
  final String? notes;
  final String? archivedAt;
  final String? createdAt;
  final String? updatedAt;

  const SupaSupplier({
    this.id,
    required this.hotelId,
    required this.officialName,
    required this.shortName,
    required this.taxNumber,
    this.defaultCategoryId,
    this.notes,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  Map<String, dynamic> toInsertMap() => {
        'hotel_id': hotelId,
        'official_name': officialName,
        'short_name': shortName,
        'tax_number': taxNumber,
        'default_category_id': defaultCategoryId,
        'notes': notes,
      };

  Map<String, dynamic> toUpdateMap() => {
        'official_name': officialName,
        'short_name': shortName,
        'tax_number': taxNumber,
        'default_category_id': defaultCategoryId,
        'notes': notes,
      };

  factory SupaSupplier.fromMap(Map<String, dynamic> map) {
    return SupaSupplier(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      officialName: map['official_name'] as String,
      shortName: map['short_name'] as String,
      taxNumber: map['tax_number'] as String,
      defaultCategoryId: map['default_category_id'] as String?,
      notes: map['notes'] as String?,
      archivedAt: map['archived_at'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
