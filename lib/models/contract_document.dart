/// مستند داخل مجلد من مستندات العقود. بخلاف نظام documents الحالي،
/// expiry/reminder اختياريان بالكامل هنا — راجع تعليق جدول contract_documents
/// في database_service.dart (ترحيل v46).
class ContractDocument {
  final int? id;
  final int? folderId;
  final String name;
  final String? description;
  final String? category;
  final List<String> tags;
  final String? notes;
  final String filePath;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String? expiryDate;
  final String? reminderDate;
  final bool isArchived;
  final String? archivedAt;
  final String? archivedBy;
  final String? archiveReason;
  final String? createdBy;
  final String createdAt;
  final String? updatedAt;

  const ContractDocument({
    this.id,
    required this.folderId,
    required this.name,
    this.description,
    this.category,
    this.tags = const [],
    this.notes,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    this.fileSize = 0,
    this.expiryDate,
    this.reminderDate,
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    this.archiveReason,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'folder_id': folderId,
      'name': name,
      'description': description,
      'category': category,
      'tags': tags.join(','),
      'notes': notes,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'expiry_date': expiryDate,
      'reminder_date': reminderDate,
      'is_archived': isArchived ? 1 : 0,
      'archived_at': archivedAt,
      'archived_by': archivedBy,
      'archive_reason': archiveReason,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ContractDocument.fromMap(Map<String, dynamic> map) {
    final tagsRaw = map['tags'] as String?;
    return ContractDocument(
      id: map['id'] as int?,
      folderId: map['folder_id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      tags: (tagsRaw == null || tagsRaw.trim().isEmpty) ? const [] : tagsRaw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      notes: map['notes'] as String?,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      fileType: map['file_type'] as String,
      fileSize: map['file_size'] as int? ?? 0,
      expiryDate: map['expiry_date'] as String?,
      reminderDate: map['reminder_date'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      archivedAt: map['archived_at'] as String?,
      archivedBy: map['archived_by'] as String?,
      archiveReason: map['archive_reason'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }

  ContractDocument copyWith({
    int? id,
    int? folderId,
    String? name,
    String? description,
    String? category,
    List<String>? tags,
    String? notes,
    String? filePath,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? expiryDate,
    bool clearExpiryDate = false,
    String? reminderDate,
    bool clearReminderDate = false,
    bool? isArchived,
    String? archivedAt,
    String? archivedBy,
    String? archiveReason,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
  }) {
    return ContractDocument(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      reminderDate: clearReminderDate ? null : (reminderDate ?? this.reminderDate),
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      archiveReason: archiveReason ?? this.archiveReason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
