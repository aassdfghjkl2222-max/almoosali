import 'package:sqflite/sqflite.dart';

import '../core/database/database_service.dart';
import '../models/expense_category.dart';
import '../models/pending_expense.dart';
import '../models/pending_expense_attachment.dart';

class ExpenseRepository {
  final _dbService = DatabaseService();

  /// كل تصنيفات المصروفات الموحدة على مستوى التطبيق — [includeHidden] لعرض
  /// المخفي أيضاً (تُستخدم في شاشة إدارة التصنيفات نفسها).
  Future<List<ExpenseCategory>> getCategories({bool includeHidden = false}) async {
    final data = await _dbService.getExpenseCategories(includeHidden: includeHidden);
    return data.map((map) => ExpenseCategory.fromMap(map)).toList();
  }

  /// بحث فوري بالاسم أو الرمز المختصر — لشاشة إدارة التصنيفات.
  Future<List<ExpenseCategory>> searchCategories(String query, {bool includeHidden = true}) async {
    final all = await getCategories(includeHidden: includeHidden);
    if (query.trim().isEmpty) return all;
    final q = query.trim();
    return all.where((c) => c.name.contains(q) || (c.shortCode?.contains(q) ?? false)).toList();
  }

  /// يمنع إدراج اسم مكرر (فحص مسبق قبل addCategory) — الفهرس الفريد في قاعدة
  /// البيانات هو خط الدفاع الأخير، لكن هذا الفحص يسمح برسالة خطأ عربية واضحة.
  Future<ExpenseCategory?> getCategoryByName(String name) async {
    final db = await _dbService.database;
    final rows = await db.query('expense_categories', where: 'name = ?', whereArgs: [name], limit: 1);
    return rows.isNotEmpty ? ExpenseCategory.fromMap(rows.first) : null;
  }

  /// هل التصنيف مستخدم فعلياً في مصروفات معلقة أو فواتير ضريبية؟ يُستخدم لمنع
  /// الحذف الحقيقي (الحذف مسموح فقط للتصنيفات غير المستخدمة إطلاقاً؛ خلاف ذلك
  /// يُعرض إخفاء التصنيف بدلاً من حذفه).
  Future<bool> isCategoryInUse(int id, String name) async {
    final db = await _dbService.database;
    final pending = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pending_expenses WHERE category_id = ?', [id])) ?? 0;
    if (pending > 0) return true;
    final invoices = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM invoices WHERE expense_category = ?', [name])) ?? 0;
    return invoices > 0;
  }

  Future<int> addCategory(ExpenseCategory category) async {
    return await _dbService.insertExpenseCategory(category.toMap());
  }

  Future<int> updateCategory(ExpenseCategory category) async {
    if (category.id == null) return 0;
    return await _dbService.updateById('expense_categories', category.toMap(), category.id!);
  }

  /// يجعل تصنيفاً واحداً فقط هو الافتراضي (يُلغي الافتراضي عن البقية أولاً) —
  /// يُستخدم في شاشة إضافة الفاتورة الضريبية لتحديد التصنيف المُختار مسبقاً.
  Future<void> setDefaultCategory(int id) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.update('expense_categories', {'is_default': 0});
      await txn.update('expense_categories', {'is_default': 1}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deleteCategory(int id) async {
    return await _dbService.deleteById('expense_categories', id);
  }

  Future<void> updateCategoriesOrder(List<ExpenseCategory> categories) async {
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i].copyWith(sortOrder: i);
      await updateCategory(cat);
    }
  }

  Future<List<PendingExpense>> getPendingExpenses({int? hotelId, bool? isTransferred}) async {
    if (hotelId == null) return [];
    final data = await _dbService.getPendingExpenses(hotelId: hotelId, isTransferred: isTransferred);
    return data.map((map) => PendingExpense.fromMap(map)).toList();
  }

  Future<int> addPendingExpense(PendingExpense expense) async {
    return await _dbService.insertPendingExpense(expense.toMap());
  }

  Future<int> updatePendingExpense(PendingExpense expense) async {
    if (expense.id == null) return 0;
    return await _dbService.updateById('pending_expenses', expense.toMap(), expense.id!);
  }

  Future<int> deletePendingExpense(int id) async {
    return await _dbService.deleteById('pending_expenses', id);
  }

  Future<void> transferExpenses(List<int> ids) async {
    await _dbService.transferPendingExpenses(ids);
  }

  /// إلغاء ترحيل مصروفات معلقة — تُعيدها إلى المصروفات المعلقة القابلة
  /// للتعديل (راجع تعليق [DatabaseService.untransferExpenses]).
  Future<void> untransferExpenses(List<int> ids) async {
    await _dbService.untransferExpenses(ids);
  }

  // ---------------- مرفقات المصروف المعلق ----------------

  Future<int> addAttachment(PendingExpenseAttachment attachment) async {
    return await _dbService.insertPendingExpenseAttachment(attachment.toMap());
  }

  Future<List<PendingExpenseAttachment>> getAttachments(int pendingExpenseId) async {
    final data = await _dbService.getPendingExpenseAttachments(pendingExpenseId);
    return data.map((map) => PendingExpenseAttachment.fromMap(map)).toList();
  }

  Future<int> deleteAttachment(int id) async {
    return await _dbService.deleteById('pending_expense_attachments', id);
  }

  String _fmtDate(DateTime d) => "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// إجمالي كل بند مصروف (حسب اسم التصنيف) عبر الفنادق المختارة خلال فترة —
  /// يُستخدم في قسم "التحليل المالي" داخل مركز التحليل. مصدر الحقيقة هنا هو
  /// pending_expenses مباشرة (وليس تحليل details_json داخل financial_reports)
  /// لأن التصنيف الحقيقي (category_id) يبقى محفوظاً حتى بعد الترحيل.
  Future<List<Map<String, dynamic>>> getExpenseTotalsByCategory({
    required List<int> hotelIds,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (hotelIds.isEmpty) return [];
    final db = await _dbService.database;
    final where = <String>['pe.hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})'];
    final args = <dynamic>[...hotelIds];
    if (fromDate != null) {
      where.add('pe.date >= ?');
      args.add(_fmtDate(fromDate));
    }
    if (toDate != null) {
      where.add('pe.date <= ?');
      args.add(_fmtDate(toDate));
    }
    return db.rawQuery(
      '''
      SELECT ec.name as category_name, SUM(pe.amount) as total, COUNT(*) as cnt
      FROM pending_expenses pe JOIN expense_categories ec ON ec.id = pe.category_id
      WHERE ${where.join(' AND ')}
      GROUP BY ec.name
      ORDER BY total DESC
      ''',
      args,
    );
  }

  /// كل عمليات بند مصروف واحد (بالاسم) — القائمة التي تُبنى منها شاشة تحليل
  /// البند (السنة/الشهر/المتوسط/أعلى/أقل/الرسم البياني/العمليات).
  Future<List<PendingExpense>> getExpenseTransactionsByCategory({
    required List<int> hotelIds,
    required String categoryName,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (hotelIds.isEmpty) return [];
    final db = await _dbService.database;
    final where = <String>['pe.hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})', 'ec.name = ?'];
    final args = <dynamic>[...hotelIds, categoryName];
    if (fromDate != null) {
      where.add('pe.date >= ?');
      args.add(_fmtDate(fromDate));
    }
    if (toDate != null) {
      where.add('pe.date <= ?');
      args.add(_fmtDate(toDate));
    }
    final rows = await db.rawQuery(
      '''
      SELECT pe.* FROM pending_expenses pe JOIN expense_categories ec ON ec.id = pe.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY pe.date DESC, pe.time DESC
      ''',
      args,
    );
    return rows.map((e) => PendingExpense.fromMap(e)).toList();
  }
}
