/// سجل تدقيق لعمليات إدارة الفنادق — راجع HotelRepository.logAudit وتعليق
/// جدول hotel_audit_log في database_service.dart (بلا FOREIGN KEY عمداً حتى
/// يبقى السجل موجوداً بعد حذف الفندق نهائياً).
class HotelAuditLog {
  final int? id;
  final int hotelId;
  final String hotelName;
  final String action;
  final String performedBy;
  final String? details;
  final String createdAt;

  const HotelAuditLog({
    this.id,
    required this.hotelId,
    required this.hotelName,
    required this.action,
    required this.performedBy,
    this.details,
    required this.createdAt,
  });

  static const actionCreated = 'created';
  static const actionEdited = 'edited';
  static const actionLogoChanged = 'logo_changed';
  static const actionColorsChanged = 'colors_changed';
  static const actionStatusChanged = 'status_changed';
  static const actionArchived = 'archived';
  static const actionRestored = 'restored';
  static const actionPermanentlyDeleted = 'permanently_deleted';
  static const actionDuplicated = 'duplicated';

  static const Map<String, String> actionLabels = {
    actionCreated: 'إنشاء الفندق',
    actionEdited: 'تعديل بيانات الفندق',
    actionLogoChanged: 'تغيير الشعار',
    actionColorsChanged: 'تغيير الهوية اللونية',
    actionStatusChanged: 'تغيير الحالة',
    actionArchived: 'أرشفة',
    actionRestored: 'استعادة',
    actionPermanentlyDeleted: 'حذف نهائي',
    actionDuplicated: 'نسخ الفندق',
  };

  String get actionLabel => actionLabels[action] ?? action;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'hotel_name': hotelName,
      'action': action,
      'performed_by': performedBy,
      'details': details,
      'created_at': createdAt,
    };
  }

  factory HotelAuditLog.fromMap(Map<String, dynamic> map) {
    return HotelAuditLog(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      hotelName: map['hotel_name'] as String,
      action: map['action'] as String,
      performedBy: map['performed_by'] as String,
      details: map['details'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
