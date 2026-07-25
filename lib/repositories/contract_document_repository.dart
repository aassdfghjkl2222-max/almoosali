import 'dart:io';

import '../core/database/database_service.dart';
import '../models/contract_document.dart';
import '../models/contract_document_audit_log.dart';
import '../models/contract_folder.dart';
import '../services/attachment_service.dart';

/// نتيجة بحث موحَّدة عبر شجرة مستندات العقود بالكامل (مجلدات ومستندات معاً)
/// — [pathLabel] هو المسار الكامل (Breadcrumb) كنص واحد للعرض السريع.
class ContractSearchResult {
  final bool isFolder;
  final ContractFolder? folder;
  final ContractDocument? document;
  final String pathLabel;
  const ContractSearchResult.folder(this.folder, this.pathLabel) : isFolder = true, document = null;
  const ContractSearchResult.document(this.document, this.pathLabel) : isFolder = false, folder = null;
}

class ContractDocumentRepository {
  final _dbService = DatabaseService();

  // ---------------- المجلدات ----------------

  Future<List<ContractFolder>> getFolders({int? parentId}) async {
    final data = await _dbService.getContractFolders(parentId: parentId);
    return data.map((m) => ContractFolder.fromMap(m)).toList();
  }

  Future<ContractFolder?> getFolder(int id) async {
    final map = await _dbService.getContractFolderById(id);
    return map == null ? null : ContractFolder.fromMap(map);
  }

  Future<List<ContractFolder>> getAllFolders() async {
    final data = await _dbService.getAllContractFolders();
    return data.map((m) => ContractFolder.fromMap(m)).toList();
  }

  Future<List<ContractFolder>> getArchivedFolders() async {
    final data = await _dbService.getArchivedContractFolders();
    return data.map((m) => ContractFolder.fromMap(m)).toList();
  }

  /// المسار الكامل من الجذر حتى [folderId] (شامله) — لعرض شريط التنقل
  /// (Breadcrumb). قائمة فارغة إن كان [folderId] هو الجذر (null).
  Future<List<ContractFolder>> getBreadcrumb(int? folderId) async {
    if (folderId == null) return [];
    final all = await getAllFolders();
    final byId = {for (final f in all) f.id: f};
    final path = <ContractFolder>[];
    int? current = folderId;
    final visited = <int>{};
    while (current != null && !visited.contains(current)) {
      visited.add(current);
      final folder = byId[current];
      if (folder == null) break;
      path.insert(0, folder);
      current = folder.parentId;
    }
    return path;
  }

  Future<bool> isFolderNameTaken(String name, {int? parentId, int? excludeId}) async {
    final siblings = await getFolders(parentId: parentId);
    final normalized = name.trim();
    return siblings.any((f) => f.id != excludeId && f.name.trim() == normalized);
  }

  Future<int> createFolder({
    required String name,
    String? description,
    String iconKey = 'folder',
    required int colorValue,
    int? parentId,
    String performedBy = "مدير النظام",
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await _dbService.insertContractFolder(ContractFolder(
      parentId: parentId,
      name: name.trim(),
      description: description,
      iconKey: iconKey,
      colorValue: colorValue,
      createdBy: performedBy,
      createdAt: now,
    ).toMap());
    await _logAudit(ContractDocumentAuditLog.typeFolder, id, name.trim(), ContractDocumentAuditLog.actionCreated, performedBy);
    return id;
  }

  Future<int> updateFolder(ContractFolder folder, {String performedBy = "مدير النظام", ContractFolder? previous}) async {
    if (folder.id == null) return 0;
    final updated = folder.copyWith(updatedAt: DateTime.now().toIso8601String());
    final result = await _dbService.updateContractFolder(updated.toMap(), folder.id!);
    final colorChanged = previous != null && previous.colorValue != folder.colorValue;
    final iconChanged = previous != null && previous.iconKey != folder.iconKey;
    await _logAudit(
      ContractDocumentAuditLog.typeFolder,
      folder.id!,
      folder.name,
      colorChanged ? ContractDocumentAuditLog.actionColorChanged : (iconChanged ? ContractDocumentAuditLog.actionIconChanged : ContractDocumentAuditLog.actionEdited),
      performedBy,
    );
    return result;
  }

  Future<int> archiveFolder(int id, {required String performedBy, String? reason}) async {
    final folder = await getFolder(id);
    final result = await _dbService.archiveContractFolder(id, archivedBy: performedBy, reason: reason);
    await _logAudit(ContractDocumentAuditLog.typeFolder, id, folder?.name ?? "مجلد #$id", ContractDocumentAuditLog.actionArchived, performedBy, details: reason);
    return result;
  }

  Future<int> restoreFolder(int id, {required String performedBy}) async {
    final folder = await getFolder(id);
    final result = await _dbService.restoreContractFolder(id);
    await _logAudit(ContractDocumentAuditLog.typeFolder, id, folder?.name ?? "مجلد #$id", ContractDocumentAuditLog.actionRestored, performedBy);
    return result;
  }

  /// كل المستندات الموجودة داخل [folderId] أو أي مجلد فرعي منه، مهما بلغ
  /// عمق التعشيش — تُستخدَم لحذف الملفات الفعلية من التخزين قبل الحذف النهائي
  /// (ON DELETE CASCADE يحذف صفوف قاعدة البيانات فقط، وليس الملفات).
  Future<List<ContractDocument>> _collectDocumentsRecursively(int folderId) async {
    final result = <ContractDocument>[];
    final docs = await _dbService.getContractDocuments(folderId: folderId, includeArchived: true);
    result.addAll(docs.map((m) => ContractDocument.fromMap(m)));
    final subfolders = await _dbService.getContractFolders(parentId: folderId, includeArchived: true);
    for (final sub in subfolders) {
      result.addAll(await _collectDocumentsRecursively(sub['id'] as int));
    }
    return result;
  }

  /// حذف نهائي لمجلد وكل ما بداخله (مجلدات فرعية بأي عمق + مستنداتها) — لا
  /// رجعة عنه. يحذف ملفات المرفقات من التخزين أولاً، ثم يسجّل التدقيق، ثم
  /// يحذف صف المجلد (CASCADE يتكفّل ببقية الصفوف).
  Future<int> deleteFolderPermanently(ContractFolder folder, {required String performedBy, String? reason}) async {
    if (folder.id == null) return 0;
    final docs = await _collectDocumentsRecursively(folder.id!);
    for (final doc in docs) {
      await AttachmentService.deleteFile(doc.filePath);
    }
    await _logAudit(ContractDocumentAuditLog.typeFolder, folder.id!, folder.name, ContractDocumentAuditLog.actionPermanentlyDeleted, performedBy, details: reason);
    return await _dbService.deleteContractFolder(folder.id!);
  }

  // ---------------- المستندات ----------------

  Future<List<ContractDocument>> getDocuments({int? folderId}) async {
    final data = await _dbService.getContractDocuments(folderId: folderId);
    return data.map((m) => ContractDocument.fromMap(m)).toList();
  }

  Future<List<ContractDocument>> getAllDocuments() async {
    final data = await _dbService.getAllContractDocuments();
    return data.map((m) => ContractDocument.fromMap(m)).toList();
  }

  Future<List<ContractDocument>> getArchivedDocuments() async {
    final data = await _dbService.getArchivedContractDocuments();
    return data.map((m) => ContractDocument.fromMap(m)).toList();
  }

  Future<int> createDocument({
    int? folderId,
    required String name,
    String? description,
    String? category,
    List<String> tags = const [],
    String? notes,
    required String filePath,
    required String fileName,
    required String fileType,
    String? expiryDate,
    String? reminderDate,
    String performedBy = "مدير النظام",
  }) async {
    final size = await File(filePath).exists() ? await File(filePath).length() : 0;
    final now = DateTime.now().toIso8601String();
    final id = await _dbService.insertContractDocument(ContractDocument(
      folderId: folderId,
      name: name.trim(),
      description: description,
      category: category,
      tags: tags,
      notes: notes,
      filePath: filePath,
      fileName: fileName,
      fileType: fileType,
      fileSize: size,
      expiryDate: expiryDate,
      reminderDate: reminderDate,
      createdBy: performedBy,
      createdAt: now,
    ).toMap());
    await _logAudit(ContractDocumentAuditLog.typeDocument, id, name.trim(), ContractDocumentAuditLog.actionCreated, performedBy);
    return id;
  }

  Future<int> updateDocument(ContractDocument document, {String performedBy = "مدير النظام"}) async {
    if (document.id == null) return 0;
    final updated = document.copyWith(updatedAt: DateTime.now().toIso8601String());
    final result = await _dbService.updateContractDocument(updated.toMap(), document.id!);
    await _logAudit(ContractDocumentAuditLog.typeDocument, document.id!, document.name, ContractDocumentAuditLog.actionEdited, performedBy);
    return result;
  }

  /// استبدال ملف المرفق (بلا Version History بعد — مُعَدّة للمستقبل، راجع
  /// وصف الوحدة): يحذف الملف القديم من التخزين، ويحدّث المسار/الاسم/النوع/الحجم.
  Future<int> replaceAttachment(ContractDocument document, {required String newPath, required String newFileName, required String newFileType, String performedBy = "مدير النظام"}) async {
    if (document.id == null) return 0;
    final oldPath = document.filePath;
    final size = await File(newPath).exists() ? await File(newPath).length() : 0;
    final updated = document.copyWith(filePath: newPath, fileName: newFileName, fileType: newFileType, fileSize: size, updatedAt: DateTime.now().toIso8601String());
    final result = await _dbService.updateContractDocument(updated.toMap(), document.id!);
    if (oldPath != newPath) await AttachmentService.deleteFile(oldPath);
    await _logAudit(ContractDocumentAuditLog.typeDocument, document.id!, document.name, ContractDocumentAuditLog.actionAttachmentReplaced, performedBy);
    return result;
  }

  Future<int> archiveDocument(int id, {required String performedBy, String? reason}) async {
    final doc = await _findDocumentById(id);
    final result = await _dbService.archiveContractDocument(id, archivedBy: performedBy, reason: reason);
    await _logAudit(ContractDocumentAuditLog.typeDocument, id, doc?.name ?? "مستند #$id", ContractDocumentAuditLog.actionArchived, performedBy, details: reason);
    return result;
  }

  Future<int> restoreDocument(int id, {required String performedBy}) async {
    final doc = await _findDocumentById(id);
    final result = await _dbService.restoreContractDocument(id);
    await _logAudit(ContractDocumentAuditLog.typeDocument, id, doc?.name ?? "مستند #$id", ContractDocumentAuditLog.actionRestored, performedBy);
    return result;
  }

  Future<int> deleteDocumentPermanently(ContractDocument document, {required String performedBy, String? reason}) async {
    if (document.id == null) return 0;
    await AttachmentService.deleteFile(document.filePath);
    await _logAudit(ContractDocumentAuditLog.typeDocument, document.id!, document.name, ContractDocumentAuditLog.actionPermanentlyDeleted, performedBy, details: reason);
    return await _dbService.deleteContractDocument(document.id!);
  }

  Future<ContractDocument?> _findDocumentById(int id) async {
    final map = await _dbService.getContractDocumentById(id);
    return map == null ? null : ContractDocument.fromMap(map);
  }

  // ---------------- البحث الفوري ----------------

  /// بحث فوري عبر الشجرة بالكامل (اسم المجلد/المستند، الوسوم، الوصف،
  /// الملاحظات، الفئة، اسم الملف) — مجلدات ومستندات غير مؤرشَفة فقط.
  Future<List<ContractSearchResult>> searchAll(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final results = <ContractSearchResult>[];
    final allFolders = await getAllFolders();
    final byId = {for (final f in allFolders) f.id: f};

    String pathFor(int? parentId) {
      final path = <String>[];
      int? current = parentId;
      final visited = <int>{};
      while (current != null && !visited.contains(current)) {
        visited.add(current);
        final f = byId[current];
        if (f == null) break;
        path.insert(0, f.name);
        current = f.parentId;
      }
      return path.isEmpty ? "الرئيسية" : path.join(' / ');
    }

    for (final f in allFolders) {
      if (f.isArchived) continue;
      final hay = [f.name, f.description ?? ''].join(' ').toLowerCase();
      if (hay.contains(q)) {
        results.add(ContractSearchResult.folder(f, pathFor(f.parentId)));
      }
    }

    final allDocs = await _dbService.getAllContractDocuments();
    for (final map in allDocs) {
      final d = ContractDocument.fromMap(map);
      if (d.isArchived) continue;
      final hay = [d.name, d.description ?? '', d.notes ?? '', d.category ?? '', d.fileName, d.tags.join(' ')].join(' ').toLowerCase();
      if (hay.contains(q)) {
        results.add(ContractSearchResult.document(d, pathFor(d.folderId)));
      }
    }
    return results;
  }

  // ---------------- سجل التدقيق ----------------

  Future<List<ContractDocumentAuditLog>> getAuditLog({String? entityType, int? entityId}) async {
    final data = await _dbService.getContractDocumentAuditLog(entityType: entityType, entityId: entityId);
    return data.map((m) => ContractDocumentAuditLog.fromMap(m)).toList();
  }

  Future<void> _logAudit(String entityType, int entityId, String entityName, String action, String performedBy, {String? details}) async {
    await _dbService.insertContractDocumentAuditLog(ContractDocumentAuditLog(
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      action: action,
      performedBy: performedBy,
      details: details,
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());
  }
}
