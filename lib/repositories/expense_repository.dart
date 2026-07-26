import '../core/database/database_service.dart';
import '../models/pending_expense.dart';
import '../models/pending_expense_attachment.dart';

/// إدارة المصروفات المعلَّقة نفسها (CRUD + ترحيل + مرفقات + تحليل حسب الفئة).
/// إدارة الفئات المالية (مصروفات/إيرادات) انتقلت بالكامل إلى
/// FinancialCategoryRepository — راجع تعليقها لسبب توحيد المصدر.
class ExpenseRepository {
  final _dbService = DatabaseService();

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
      FROM pending_expenses pe JOIN financial_categories ec ON ec.id = pe.category_id
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
      SELECT pe.* FROM pending_expenses pe JOIN financial_categories ec ON ec.id = pe.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY pe.date DESC, pe.time DESC
      ''',
      args,
    );
    return rows.map((e) => PendingExpense.fromMap(e)).toList();
  }
}
