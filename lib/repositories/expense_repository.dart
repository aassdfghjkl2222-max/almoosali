import '../core/database/database_service.dart';
import '../models/pending_expense.dart';
import '../models/pending_expense_attachment.dart';
import 'trash_repository.dart';

/// إدارة المصروفات المعلَّقة نفسها (CRUD + ترحيل + مرفقات + تحليل حسب الفئة).
/// إدارة الفئات المالية (مصروفات/إيرادات) انتقلت بالكامل إلى
/// FinancialCategoryRepository — راجع تعليقها لسبب توحيد المصدر.
class ExpenseRepository {
  final _dbService = DatabaseService();
  final _trashRepository = TrashRepository();

  Future<List<PendingExpense>> getPendingExpenses({int? hotelId, bool? isTransferred}) async {
    if (hotelId == null) return [];
    final data = await _dbService.getPendingExpenses(hotelId: hotelId, isTransferred: isTransferred);
    return data.map((map) => PendingExpense.fromMap(map)).toList();
  }

  /// عبر كل الفنادق معاً — راجع تعليق
  /// DatabaseService.getAllPendingExpensesAcrossHotels (البحث الشامل
  /// GlobalSearch فقط).
  Future<List<PendingExpense>> getAllPendingExpensesAcrossHotels() async {
    final data = await _dbService.getAllPendingExpensesAcrossHotels();
    return data.map((map) => PendingExpense.fromMap(map)).toList();
  }

  Future<int> addPendingExpense(PendingExpense expense) async {
    return await _dbService.insertPendingExpense(expense.toMap());
  }

  /// يمنع تعديل مصروف مُرحَّل بالفحص من قاعدة البيانات مباشرة (لا من الحالة
  /// الممرَّرة في [expense]، التي قد تكون قديمة) — طبقة حماية على مستوى
  /// الأعمال بالإضافة إلى القفل الموجود أصلاً في واجهة AddPendingExpensePage،
  /// حتى لا تعتمد الحماية على واجهة مستخدم واحدة فقط.
  Future<int> updatePendingExpense(PendingExpense expense) async {
    if (expense.id == null) return 0;
    if (await _dbService.isPendingExpenseTransferred(expense.id!)) {
      throw StateError('لا يمكن تعديل مصروف تم ترحيله بالفعل إلى تقرير مالي مُعتمد.');
    }
    return await _dbService.updateById('pending_expenses', expense.toMap(), expense.id!);
  }

  /// نفس حماية [updatePendingExpense] — راجع تعليقها. نقل ناعم إلى سلة
  /// المهملات (لا حذف فعلي) — الحارس أعلاه يضمن عدم وصول أي مصروف مُرحَّل
  /// إلى هذا المسار أصلاً، فسلة المهملات لا تشمل إلا المصروفات المعلَّقة غير
  /// المُرحَّلة فقط، كما هو مُقرَّر.
  Future<void> deletePendingExpense(PendingExpense expense) async {
    if (await _dbService.isPendingExpenseTransferred(expense.id!)) {
      throw StateError('لا يمكن حذف مصروف تم ترحيله بالفعل إلى تقرير مالي مُعتمد.');
    }
    await _trashRepository.trash('pending_expense', expense.id!, expense.statement);
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

  /// إجمالي كل بند مصروف (حسب category_id — المصدر الوحيد المعتمَد، راجع Core
  /// Principle في financial_category.dart: التقارير تُجمَّع بالمعرّف لا بالاسم
  /// المعروض حتى لا تنقسم بيانات نفس الفئة تاريخياً إن أُعيدت تسميتها لاحقاً)
  /// عبر الفنادق المختارة خلال فترة — يُستخدم في قسم "التحليل المالي" داخل
  /// مركز التحليل. مصدر الحقيقة هنا هو pending_expenses مباشرة (وليس تحليل
  /// details_json داخل financial_reports) لأن التصنيف الحقيقي (category_id)
  /// يبقى محفوظاً حتى بعد الترحيل.
  Future<List<Map<String, dynamic>>> getExpenseTotalsByCategory({
    required List<int> hotelIds,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (hotelIds.isEmpty) return [];
    final db = await _dbService.database;
    final where = <String>['pe.hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})', 'pe.is_deleted = 0'];
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
      SELECT ec.id as category_id, ec.name as category_name, SUM(pe.amount) as total, COUNT(*) as cnt
      FROM pending_expenses pe JOIN financial_categories ec ON ec.id = pe.category_id
      WHERE ${where.join(' AND ')}
      GROUP BY ec.id
      ORDER BY total DESC
      ''',
      args,
    );
  }

  /// كل عمليات بند مصروف واحد (بمعرّف الفئة الحقيقي) — القائمة التي تُبنى منها
  /// شاشة تحليل البند (السنة/الشهر/المتوسط/أعلى/أقل/الرسم البياني/العمليات).
  Future<List<PendingExpense>> getExpenseTransactionsByCategory({
    required List<int> hotelIds,
    required int categoryId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (hotelIds.isEmpty) return [];
    final db = await _dbService.database;
    final where = <String>['pe.hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})', 'pe.category_id = ?', 'pe.is_deleted = 0'];
    final args = <dynamic>[...hotelIds, categoryId];
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
      SELECT pe.* FROM pending_expenses pe
      WHERE ${where.join(' AND ')}
      ORDER BY pe.date DESC, pe.time DESC
      ''',
      args,
    );
    return rows.map((e) => PendingExpense.fromMap(e)).toList();
  }
}
