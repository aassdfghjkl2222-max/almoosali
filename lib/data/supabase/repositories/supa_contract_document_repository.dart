import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_contract_document.dart';
import '../supabase_config.dart';

/// المجلدات المتداخلة بلا حدود + المستندات — [hotelId] null عند الإنشاء يعني
/// مجلداً مشتركاً بين كل الفنادق (راجع تعليق RLS في
/// supabase/migrations/20260730000004_phase4_people_and_contracts.sql).
class SupaContractDocumentRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaContractDocumentFolder>> getSubfolders({String? parentFolderId}) async {
    var query = _db.from('contract_document_folders').select();
    query = parentFolderId == null ? query.filter('parent_folder_id', 'is', null) : query.eq('parent_folder_id', parentFolderId);
    final rows = await query.filter('archived_at', 'is', null).order('name');
    return (rows as List).map((m) => SupaContractDocumentFolder.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaContractDocumentFolder> addFolder(SupaContractDocumentFolder folder) async {
    final row = await _db.from('contract_document_folders').insert(folder.toInsertMap()).select().single();
    return SupaContractDocumentFolder.fromMap(row);
  }

  Future<void> archiveFolder(String id, {String? reason}) async {
    await _db.from('contract_document_folders').update({'archived_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    await logAudit(SupaContractDocumentAuditLogEntry(
      folderId: id,
      action: SupaContractDocumentAuditLogEntry.actionArchived,
      reason: reason,
    ));
  }

  Future<List<SupaContractDocument>> getDocuments(String folderId) async {
    final rows = await _db.from('contract_documents').select().eq('folder_id', folderId).filter('archived_at', 'is', null).order('name');
    return (rows as List).map((m) => SupaContractDocument.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaContractDocument> addDocument(SupaContractDocument document) async {
    final row = await _db.from('contract_documents').insert(document.toInsertMap()).select().single();
    await logAudit(SupaContractDocumentAuditLogEntry(
      documentId: row['id'] as String,
      folderId: document.folderId,
      action: SupaContractDocumentAuditLogEntry.actionCreated,
    ));
    return SupaContractDocument.fromMap(row);
  }

  Future<void> archiveDocument(String id, {required String folderId, String? reason}) async {
    await _db.from('contract_documents').update({'archived_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    await logAudit(SupaContractDocumentAuditLogEntry(
      documentId: id,
      folderId: folderId,
      action: SupaContractDocumentAuditLogEntry.actionArchived,
      reason: reason,
    ));
  }

  Future<void> logAudit(SupaContractDocumentAuditLogEntry entry) async {
    await _db.from('contract_document_audit_log').insert(entry.toInsertMap());
  }

  Future<List<SupaContractDocumentAuditLogEntry>> getAuditLog({String? documentId, String? folderId}) async {
    var query = _db.from('contract_document_audit_log').select();
    if (documentId != null) query = query.eq('document_id', documentId);
    if (folderId != null) query = query.eq('folder_id', folderId);
    final rows = await query.order('occurred_at', ascending: false);
    return (rows as List).map((m) => SupaContractDocumentAuditLogEntry.fromMap(m as Map<String, dynamic>)).toList();
  }
}
