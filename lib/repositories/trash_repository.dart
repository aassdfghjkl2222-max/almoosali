import '../core/database/database_service.dart';
import '../core/trash/trashable_entity.dart';
import '../models/trashed_item.dart';
import '../services/attachment_service.dart';

/// الطبقة العامة الوحيدة لسلة المهملات الموحّدة — تُستدعى من كل مستودعات
/// المرحلة الأولى (بدل استدعاء DatabaseService.deleteById/softDeleteById
/// مباشرة) لضمان أن كل حذف ناعم يُسجَّل في trash_log بنفس الأسلوب، وأن شاشة
/// "سلة المهملات" تعرض كل الأنواع من مكان واحد. راجع lib/core/trash/trashable_entity.dart
/// للسجل الثابت لكل نوع، ولماذا الفنادق/الموظفون غير مُدرَجين هنا.
class TrashRepository {
  final _db = DatabaseService();

  TrashableEntity _entity(String type) => trashableEntities.firstWhere((e) => e.type == type, orElse: () => throw ArgumentError('نوع غير مسجَّل في سلة المهملات: $type'));

  /// يُستدعى من مستودع الكيان نفسه بعد أي حارس/فحص حالة موجود مسبقاً (مثل
  /// StateError لمصروف مُرحَّل) — ينقل الصف للسلة (حذف ناعم) ويسجّل الإجراء.
  Future<void> trash(String type, int id, String name, {String? performedBy, String? reason}) async {
    final entity = _entity(type);
    await _db.softDeleteById(entity.table, id, deletedBy: performedBy, reason: reason);
    await _db.insertTrashLog({
      'entity_type': type,
      'entity_id': id,
      'entity_name': name,
      'action': 'trashed',
      'performed_by': performedBy,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// كل العناصر الموجودة حالياً في السلة عبر كل الأنواع المسجَّلة — مُرتَّبة
  /// بالأحدث حذفاً أولاً.
  Future<List<TrashedItem>> listAll() async {
    final items = <TrashedItem>[];
    for (final entity in trashableEntities) {
      final rows = await _db.getTrashedRows(entity.table);
      for (final row in rows) {
        // مصروفات معلَّقة مولَّدة من مصروف مشترك تُنقَل للسلة مع رأسها معاً
        // (راجع SharedExpenseDistributionRepository.deleteSharedExpense) —
        // تُمثَّل ببند "shared_expense" واحد فقط، لا تُكرَّر هنا أيضاً.
        if (entity.type == 'pending_expense' && row['shared_expense_id'] != null) continue;
        final deletedAtStr = row['deleted_at'] as String?;
        if (deletedAtStr == null) continue;
        items.add(TrashedItem(
          type: entity.type,
          typeLabel: entity.label,
          id: row['id'] as int,
          name: entity.displayName(row),
          deletedAt: DateTime.parse(deletedAtStr),
        ));
      }
    }
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  /// حذف الملفات الفعلية على القرص للمرفقات المرتبطة قبل الحذف النهائي —
  /// ضروري فقط للأنواع التي كانت سابقاً تحذف الملف الفعلي فور ضغط "حذف"
  /// (المستندات/الفواتير). نُقل هذا الآن من لحظة "النقل للسلة" (حيث كان
  /// سيكسر الاستعادة: الصف يبقى لكن ملفه اختفى) إلى لحظة الحذف النهائي
  /// الفعلية فقط — يدوياً أو تلقائياً بعد 30 يوماً. صفوف document_attachments/
  /// invoice_attachments نفسها تُحذف تلقائياً عبر ON DELETE CASCADE مع الصف
  /// الأصل، فلا حاجة لحذفها هنا صراحة.
  Future<void> _deleteAttachmentFiles(String type, int id) async {
    if (type == 'document') {
      final rows = await _db.getDocumentAttachments(id);
      for (final row in rows) {
        await AttachmentService.deleteFile(row['file_path'] as String);
      }
    } else if (type == 'invoice') {
      final rows = await _db.getInvoiceAttachments(id);
      for (final row in rows) {
        await AttachmentService.deleteFile(row['file_path'] as String);
      }
    }
  }

  Future<void> restore(String type, int id, {String? performedBy}) async {
    final entity = _entity(type);
    await _db.restoreById(entity.table, id);
    if (type == 'shared_expense') {
      await _db.setPendingExpensesDeletedForSharedExpense(id, false);
    }
    await _db.insertTrashLog({
      'entity_type': type,
      'entity_id': id,
      'entity_name': '',
      'action': 'restored',
      'performed_by': performedBy,
      'reason': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> permanentlyDelete(String type, int id, {String? performedBy}) async {
    final entity = _entity(type);
    await _deleteAttachmentFiles(type, id);
    await _db.deleteById(entity.table, id);
    await _db.insertTrashLog({
      'entity_type': type,
      'entity_id': id,
      'entity_name': '',
      'action': 'purged_manually',
      'performed_by': performedBy,
      'reason': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// يُستدعى بلا await عند إقلاع التطبيق (main.dart) — يحذف نهائياً كل عنصر
  /// تجاوز 30 يوماً في السلة عبر كل الأنواع المسجَّلة. لا يشمل الفنادق/الموظفين
  /// (غير مسجَّلين هنا أصلاً — يبقيان محكومين بمسارهما اليدوي الحالي فقط).
  Future<void> purgeExpired() async {
    final all = await listAll();
    for (final item in all) {
      if (!item.isOverdue) continue;
      await _deleteAttachmentFiles(item.type, item.id);
      await _db.deleteById(_entity(item.type).table, item.id);
      await _db.insertTrashLog({
        'entity_type': item.type,
        'entity_id': item.id,
        'entity_name': item.name,
        'action': 'purged_auto',
        'performed_by': null,
        'reason': 'انتهت مدة 30 يوماً في سلة المهملات',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
