import '../core/database/database_service.dart';
import '../models/pending_expense.dart';
import '../models/shared_expense.dart';

/// إنشاء/تعديل/حذف "المصروف المشترك" بنموذجه الجديد: توزيع تلقائي لمصروف
/// واحد كمصروفات معلَّقة مستقلة على عدة منشآت (بلا مفهوم "منشأة مموِّلة تُسدَّد
/// لها ذمة" — راجع تعليق SharedExpense وجدول shared_expenses في
/// database_service.dart، ترحيل v47، لسبب استقلاله عن shared_expense_groups
/// القديم الذي يبقى بلا تغيير لعرض بياناته التاريخية فقط).
class SharedExpenseDistributionRepository {
  final _dbService = DatabaseService();

  Future<List<SharedExpense>> getSharedExpensesForHotel(int hotelId) async {
    final data = await _dbService.getSharedExpensesForHotel(hotelId);
    return data.map((m) => SharedExpense.fromMap(m)).toList();
  }

  Future<List<SharedExpense>> getAllSharedExpenses() async {
    final data = await _dbService.getAllSharedExpenses();
    return data.map((m) => SharedExpense.fromMap(m)).toList();
  }

  Future<SharedExpense?> getSharedExpenseById(int id) async {
    final map = await _dbService.getSharedExpenseById(id);
    return map == null ? null : SharedExpense.fromMap(map);
  }

  /// كل المصروفات المعلَّقة المولَّدة من مصروف مشترك واحد (حقل عرض hotelName
  /// من JOIN — راجع DatabaseService.getPendingExpensesForSharedExpense).
  Future<List<PendingExpense>> getPendingExpensesFor(int sharedExpenseId) async {
    final data = await _dbService.getPendingExpensesForSharedExpense(sharedExpenseId);
    return data.map((m) => PendingExpense.fromMap(m)).toList();
  }

  /// [hotelAmounts] معرّف المنشأة → المبلغ الموزَّع عليها — يجب أن يساوي
  /// مجموعها [header.totalAmount] تماماً (يُتحقَّق منه في الواجهة قبل الاستدعاء).
  Future<int> createSharedExpense({
    required SharedExpense header,
    required Map<int, double> hotelAmounts,
    required String date,
    required String time,
    String performedBy = "مدير النظام",
  }) async {
    final now = DateTime.now().toIso8601String();
    final headerData = header.copyWith(createdBy: performedBy, createdAt: now).toMap();
    final rows = [
      for (final entry in hotelAmounts.entries)
        PendingExpense(
          hotelId: entry.key,
          amount: entry.value,
          paymentMethod: header.fundingSource,
          categoryId: header.categoryId,
          statement: header.description ?? '',
          notes: header.notes,
          date: date,
          time: time,
          createdAt: now,
        ).toMap(),
    ];
    return await _dbService.createSharedExpenseWithDistribution(headerData: headerData, pendingExpenseRows: rows);
  }

  /// تعديل مصروف مشترك: يوفّق [hotelAmounts] الجديدة مع المصروفات المعلَّقة
  /// المولَّدة الحالية (تحديث/حذف/إدراج حسب الحاجة). يُمنَع الاستدعاء إن كان
  /// أيٌّ منها مرحَّلاً بالفعل — راجع [canModify].
  Future<void> updateSharedExpense({
    required SharedExpense header,
    required Map<int, double> hotelAmounts,
    required String date,
    String performedBy = "مدير النظام",
  }) async {
    if (header.id == null) return;
    if (!await canModify(header.id!)) {
      throw StateError('لا يمكن تعديل مصروف مشترك رُحِّل جزء منه بالفعل إلى تقرير مالي مُعتمد.');
    }
    final existing = await getPendingExpensesFor(header.id!);
    final existingByHotel = {for (final e in existing) e.hotelId: e};

    final toInsert = <Map<String, dynamic>>[];
    final toUpdate = <int, Map<String, dynamic>>{};
    final toDeleteIds = <int>[];

    for (final entry in hotelAmounts.entries) {
      final current = existingByHotel.remove(entry.key);
      final data = PendingExpense(
        id: current?.id,
        hotelId: entry.key,
        amount: entry.value,
        paymentMethod: header.fundingSource,
        categoryId: header.categoryId,
        statement: header.description ?? '',
        notes: header.notes,
        date: date,
        time: current?.time ?? DateTime.now().toIso8601String().substring(11, 19),
        createdAt: current?.createdAt ?? DateTime.now().toIso8601String(),
      ).toMap();
      if (current != null) {
        data.remove('id');
        toUpdate[current.id!] = data;
      } else {
        data.remove('id');
        toInsert.add(data);
      }
    }
    // ما تبقى في existingByHotel هي منشآت أُزيلت من الاختيار.
    toDeleteIds.addAll(existingByHotel.values.map((e) => e.id!));

    final headerData = header.copyWith(updatedAt: DateTime.now().toIso8601String()).toMap();
    await _dbService.applySharedExpenseUpdate(
      sharedExpenseId: header.id!,
      headerData: headerData,
      toInsert: toInsert,
      toUpdate: toUpdate,
      toDeleteIds: toDeleteIds,
    );
  }

  /// حذف نهائي: يحذف رأس المصروف المشترك، وCASCADE يحذف تلقائياً كل مصروفاته
  /// المعلَّقة المولَّدة. يُمنَع إن كان أيٌّ منها مرحَّلاً بالفعل — راجع [canModify].
  Future<void> deleteSharedExpense(int id) async {
    if (!await canModify(id)) {
      throw StateError('لا يمكن حذف مصروف مشترك رُحِّل جزء منه بالفعل إلى تقرير مالي مُعتمد.');
    }
    await _dbService.deleteSharedExpense(id);
  }

  /// هل يمكن تعديل/حذف هذا المصروف المشترك؟ يُمنَع إن رُحِّل أيٌّ من مصروفاته
  /// المعلَّقة المولَّدة إلى تقرير يومي بالفعل (بيانات مرحَّلة لا تُعدَّل من هنا).
  Future<bool> canModify(int sharedExpenseId) async {
    final rows = await getPendingExpensesFor(sharedExpenseId);
    return rows.every((r) => !r.isTransferred);
  }
}
