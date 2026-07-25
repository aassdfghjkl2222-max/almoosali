/// مجلد داخل شجرة مستندات العقود — [parentId] يشير لمجلد آخر (null = مجلد
/// جذري) ويسمح بتعشيش غير محدود العمق. راجع تعليق جدول contract_folders في
/// database_service.dart (ترحيل v46) لسبب استقلال هذا النظام عن document_types.
class ContractFolder {
  final int? id;
  final int? parentId;
  final String name;
  final String? description;
  final String iconKey;
  final int colorValue;
  final String? coverImagePath;
  final bool isArchived;
  final String? archivedAt;
  final String? archivedBy;
  final String? archiveReason;
  final String? createdBy;
  final String createdAt;
  final String? updatedAt;

  const ContractFolder({
    this.id,
    this.parentId,
    required this.name,
    this.description,
    this.iconKey = 'folder',
    this.colorValue = 0xFF7A1E2C,
    this.coverImagePath,
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
      'parent_id': parentId,
      'name': name,
      'description': description,
      'icon_key': iconKey,
      'color_value': colorValue,
      'cover_image_path': coverImagePath,
      'is_archived': isArchived ? 1 : 0,
      'archived_at': archivedAt,
      'archived_by': archivedBy,
      'archive_reason': archiveReason,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ContractFolder.fromMap(Map<String, dynamic> map) {
    return ContractFolder(
      id: map['id'] as int?,
      parentId: map['parent_id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      iconKey: map['icon_key'] as String? ?? 'folder',
      colorValue: map['color_value'] as int? ?? 0xFF7A1E2C,
      coverImagePath: map['cover_image_path'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      archivedAt: map['archived_at'] as String?,
      archivedBy: map['archived_by'] as String?,
      archiveReason: map['archive_reason'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }

  ContractFolder copyWith({
    int? id,
    int? parentId,
    bool clearParentId = false,
    String? name,
    String? description,
    String? iconKey,
    int? colorValue,
    String? coverImagePath,
    bool? isArchived,
    String? archivedAt,
    String? archivedBy,
    String? archiveReason,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
  }) {
    return ContractFolder(
      id: id ?? this.id,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      name: name ?? this.name,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      coverImagePath: coverImagePath ?? this.coverImagePath,
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
