import 'package:sqflite/sqflite.dart';

import '../core/database/database_service.dart';
import '../models/document_category.dart';
import '../models/document_type.dart';

/// مستودع أنواع المستندات المرجعية وفئاتها — المصدر الوحيد للحقيقة على
/// مستوى التطبيق بالكامل (راجع database_service.dart لتوثيق الجداول).
class DocumentTypeRepository {
  final _dbService = DatabaseService();

  // ---------------- الفئات ----------------

  Future<List<DocumentCategory>> getCategories() async {
    final data = await _dbService.getDocumentCategories();
    return data.map((map) => DocumentCategory.fromMap(map)).toList();
  }

  Future<DocumentCategory?> getCategoryByName(String name) async {
    final db = await _dbService.database;
    final rows = await db.query('document_categories', where: 'name = ?', whereArgs: [name], limit: 1);
    return rows.isNotEmpty ? DocumentCategory.fromMap(rows.first) : null;
  }

  Future<int> addCategory(DocumentCategory category) async {
    return await _dbService.insertDocumentCategory(category.toMap());
  }

  Future<int> updateCategory(DocumentCategory category) async {
    if (category.id == null) return 0;
    return await _dbService.updateById('document_categories', category.toMap(), category.id!);
  }

  /// يمنع الحذف الحقيقي لفئة مستخدمة في نوع مستند واحد على الأقل.
  Future<bool> isCategoryInUse(int id) async {
    final db = await _dbService.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM document_types WHERE category_id = ?', [id])) ?? 0;
    return count > 0;
  }

  Future<int> deleteCategory(int id) async {
    return await _dbService.deleteById('document_categories', id);
  }

  // ---------------- الأنواع ----------------

  Future<List<DocumentType>> getTypes({bool includeInactive = true, String? lifecycle}) async {
    final data = await _dbService.getDocumentTypes(includeInactive: includeInactive, lifecycle: lifecycle);
    return data.map((map) => DocumentType.fromMap(map)).toList();
  }

  Future<DocumentType?> getTypeById(int id) async {
    final map = await _dbService.getDocumentTypeById(id);
    return map != null ? DocumentType.fromMap(map) : null;
  }

  Future<DocumentType?> getTypeByName(String name) async {
    final db = await _dbService.database;
    final rows = await db.query('document_types', where: 'name = ?', whereArgs: [name], limit: 1);
    return rows.isNotEmpty ? DocumentType.fromMap(rows.first) : null;
  }

  /// يحفظ النوع، ثم يضبط نطاق الفنادق المحددة (إن وُجدت)، ثم — إن كان
  /// النوع مفعَّلاً و[autoProvision] صحيحاً — ينشره فوراً على كل الفنادق
  /// المطابقة الحالية بدل انتظار إنشاء فندق جديد (نفس مبدأ توحيد
  /// expense_categories). [autoProvision] يجب أن يبقى `true` (الافتراضي)
  /// فقط لأنواع "مستندات الفندق" الحقيقية (تُنشأ نسخة فارغة تلقائياً لكل
  /// فندق) — أما "مجلدات" قسم المستندات (دائم/موسمي) فهي حاويات مراجع
  /// فقط ولا تُنشئ أي مستند تلقائياً، لذلك تُمرِّر `autoProvision: false`.
  Future<int> addType(DocumentType type, {List<int> hotelIds = const [], bool autoProvision = true}) async {
    final id = await _dbService.insertDocumentType(type.toMap());
    if (type.scope == 'specific' && hotelIds.isNotEmpty) {
      await _dbService.setDocumentTypeHotels(id, hotelIds);
    }
    if (type.isActive && autoProvision) {
      await _dbService.provisionDocumentTypesAcrossHotels();
    }
    return id;
  }

  Future<void> updateType(DocumentType type, {List<int> hotelIds = const [], bool autoProvision = true}) async {
    if (type.id == null) return;
    await _dbService.updateById('document_types', type.toMap(), type.id!);
    if (type.scope == 'specific') {
      await _dbService.setDocumentTypeHotels(type.id!, hotelIds);
    } else {
      await _dbService.setDocumentTypeHotels(type.id!, []);
    }
    if (type.isActive && autoProvision) {
      await _dbService.provisionDocumentTypesAcrossHotels();
    }
  }

  /// يمنع الحذف الحقيقي لنوع مستخدم في مستندات فندق واحد على الأقل — يُقترح
  /// تعطيله (is_active=0) بدلاً من ذلك.
  Future<bool> isTypeInUse(int id) async {
    final db = await _dbService.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM documents WHERE document_type_id = ?', [id])) ?? 0;
    return count > 0;
  }

  Future<int> deleteType(int id) async {
    return await _dbService.deleteById('document_types', id);
  }

  Future<List<int>> getHotelsForType(int typeId) async {
    return await _dbService.getDocumentTypeHotelIds(typeId);
  }
}
