/// سجل تدقيق مستندات العقود (مجلدات ومستندات معاً، عبر [entityType]). بلا
/// FOREIGN KEY عمداً (نفس نمط hotel_audit_log) — يبقى موجوداً بعد الحذف النهائي.
class ContractDocumentAuditLog {
  final int? id;
  final String entityType; // 'folder' | 'document'
  final int entityId;
  final String entityName;
  final String action;
  final String performedBy;
  final String? details;
  final String createdAt;

  const ContractDocumentAuditLog({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.action,
    required this.performedBy,
    this.details,
    required this.createdAt,
  });

  static const typeFolder = 'folder';
  static const typeDocument = 'document';

  static const actionCreated = 'created';
  static const actionEdited = 'edited';
  static const actionColorChanged = 'color_changed';
  static const actionIconChanged = 'icon_changed';
  static const actionAttachmentReplaced = 'attachment_replaced';
  static const actionArchived = 'archived';
  static const actionRestored = 'restored';
  static const actionPermanentlyDeleted = 'permanently_deleted';

  static const Map<String, String> actionLabels = {
    actionCreated: 'إنشاء',
    actionEdited: 'تعديل',
    actionColorChanged: 'تغيير اللون',
    actionIconChanged: 'تغيير الأيقونة',
    actionAttachmentReplaced: 'استبدال المرفق',
    actionArchived: 'أرشفة',
    actionRestored: 'استعادة',
    actionPermanentlyDeleted: 'حذف نهائي',
  };

  String get actionLabel => actionLabels[action] ?? action;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'entity_name': entityName,
      'action': action,
      'performed_by': performedBy,
      'details': details,
      'created_at': createdAt,
    };
  }

  factory ContractDocumentAuditLog.fromMap(Map<String, dynamic> map) {
    return ContractDocumentAuditLog(
      id: map['id'] as int?,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as int,
      entityName: map['entity_name'] as String,
      action: map['action'] as String,
      performedBy: map['performed_by'] as String,
      details: map['details'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
