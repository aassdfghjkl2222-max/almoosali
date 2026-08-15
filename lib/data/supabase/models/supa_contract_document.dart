/// يطابق `contract_document_folders`/`contract_documents`/
/// `contract_document_audit_log` — راجع
/// supabase/migrations/20260730000004_phase4_people_and_contracts.sql.
/// hotelId == null يعني مجلداً على مستوى الشركة كاملة (مشترك بين كل الفنادق).
library;

class SupaContractDocumentFolder {
  final String? id;
  final String? parentFolderId;
  final String? hotelId;
  final String name;
  final String? archivedAt;
  final String? createdAt;

  const SupaContractDocumentFolder({
    this.id,
    this.parentFolderId,
    this.hotelId,
    required this.name,
    this.archivedAt,
    this.createdAt,
  });

  bool get isArchived => archivedAt != null;
  bool get isCompanyWide => hotelId == null;

  Map<String, dynamic> toInsertMap() => {'parent_folder_id': parentFolderId, 'hotel_id': hotelId, 'name': name};

  factory SupaContractDocumentFolder.fromMap(Map<String, dynamic> map) {
    return SupaContractDocumentFolder(
      id: map['id'] as String?,
      parentFolderId: map['parent_folder_id'] as String?,
      hotelId: map['hotel_id'] as String?,
      name: map['name'] as String,
      archivedAt: map['archived_at'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}

class SupaContractDocument {
  final String? id;
  final String folderId;
  final String name;
  final String storagePath;
  final String fileType;
  final int version;
  final String? archivedAt;
  final String? createdAt;
  final String? updatedAt;

  const SupaContractDocument({
    this.id,
    required this.folderId,
    required this.name,
    required this.storagePath,
    required this.fileType,
    this.version = 1,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  Map<String, dynamic> toInsertMap() => {
        'folder_id': folderId,
        'name': name,
        'storage_path': storagePath,
        'file_type': fileType,
        'version': version,
      };

  factory SupaContractDocument.fromMap(Map<String, dynamic> map) {
    return SupaContractDocument(
      id: map['id'] as String?,
      folderId: map['folder_id'] as String,
      name: map['name'] as String,
      storagePath: map['storage_path'] as String,
      fileType: map['file_type'] as String,
      version: map['version'] as int? ?? 1,
      archivedAt: map['archived_at'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}

class SupaContractDocumentAuditLogEntry {
  static const actionCreated = 'created';
  static const actionArchived = 'archived';
  static const actionRestored = 'restored';
  static const actionDeleted = 'deleted';
  static const actionReplaced = 'replaced';

  final String? id;
  final String? documentId;
  final String? folderId;
  final String? performedBy;
  final String action;
  final String? reason;
  final String? occurredAt;

  const SupaContractDocumentAuditLogEntry({
    this.id,
    this.documentId,
    this.folderId,
    this.performedBy,
    required this.action,
    this.reason,
    this.occurredAt,
  });

  Map<String, dynamic> toInsertMap() => {
        'document_id': documentId,
        'folder_id': folderId,
        'performed_by': performedBy,
        'action': action,
        'reason': reason,
      };

  factory SupaContractDocumentAuditLogEntry.fromMap(Map<String, dynamic> map) {
    return SupaContractDocumentAuditLogEntry(
      id: map['id'] as String?,
      documentId: map['document_id'] as String?,
      folderId: map['folder_id'] as String?,
      performedBy: map['performed_by'] as String?,
      action: map['action'] as String,
      reason: map['reason'] as String?,
      occurredAt: map['occurred_at'] as String?,
    );
  }
}
