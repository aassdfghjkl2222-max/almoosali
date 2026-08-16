import '../core/database/database_service.dart';
import '../models/inter_entity_transfer.dart';
import '../services/financial_engine.dart';
import 'trash_repository.dart';

/// إنشاء واستعلام "التحويل بين المنشآت" — مبلغ يرسله فندق مباشرة إلى فندق
/// آخر بلا مصروف مرتبط. سجل معلَّق بحت عند الإنشاء — بلا أي قيد محاسبي، بلا
/// أي أثر على المركز المالي (راجع تعليق [InterEntityTransfer]). يمر بنفس
/// دورة الحياة المحاسبية المعتمَدة الآن: معلّق ← تقرير يومي ← ترحيل —
/// [markTransferredForReport] تُستدعى عند اعتماد التقرير اليومي (نفس لحظة
/// ExpenseRepository.transferExpenses)، و[bookTransfersForDate] تُستدعى عند
/// الترحيل الفعلي فقط (راجع VaultRepository.postReportComponents).
///
/// عندما يُنشأ التحويل من الفندق **المرسِل** (يُمرَّر [fundingSourceCategory])،
/// يُستخدم [FinancialEngine.recordSharedExpense] عند الترحيل — نفس الأسلوب
/// المُستخدم أصلاً لـ"المصروف المشترك": يخصم مصدر التمويل المُختار فعلياً من
/// أصول المرسِل (نقد/خزنة/شبكة) **و** ينشئ ذمة (المستقبِل مدين للمرسِل) معاً.
///
/// عندما يُنشأ من الفندق **المستقبِل** ([fundingSourceCategory] فارغ)، يُستخدم
/// [FinancialEngine.recordTransaction] بآلية entity_/receivable_entity — ذمة
/// فقط، بلا أثر على أي رصيد فعلي (نفس منطق "مصروف مموَّل من فندق آخر").
class InterEntityTransferRepository {
  final _dbService = DatabaseService();
  final _financialEngine = FinancialEngine();
  final _trashRepository = TrashRepository();

  Future<int> createTransfer({
    required int fromHotelId,
    required int toHotelId,
    required double amount,
    required String statement,
    String? fundingSourceCategory,
  }) async {
    final now = DateTime.now();
    final transfer = InterEntityTransfer(
      fromHotelId: fromHotelId,
      toHotelId: toHotelId,
      amount: amount,
      statement: statement,
      date: "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      time: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      createdAt: now.toIso8601String(),
      fundingSourceCategory: fundingSourceCategory,
      isTransferred: false,
    );
    // لا قيد محاسبي هنا — سجل معلَّق بحت، راجع تعليق الصنف.
    return await _dbService.insertInterEntityTransfer(transfer.toMap());
  }

  /// يسجِّل الأثر المحاسبي لتحويل واحد — يُستدعى فقط من [bookTransfersForDate]
  /// عند الترحيل الفعلي.
  Future<void> _bookTransfer(InterEntityTransfer t) async {
    if (t.fundingSourceCategory != null) {
      await _financialEngine.recordSharedExpense(
        fundingHotelId: t.fromHotelId,
        totalAmount: t.amount,
        paymentMethodCategory: t.fundingSourceCategory!,
        otherShares: {t.toHotelId: t.amount},
        description: "تحويل بين المنشآت: ${t.statement}",
        referenceId: t.id,
      );
    } else {
      await _financialEngine.recordTransaction(
        hotelId: t.toHotelId,
        sourceCategory: 'entity_${t.fromHotelId}',
        amount: t.amount,
        type: 'expense',
        description: "تحويل بين المنشآت: ${t.statement}",
        referenceId: t.id,
        referenceType: 'inter_entity_transfer',
        otherHotelId: t.fromHotelId,
      );
    }
  }

  /// يمنع تعديل/حذف تحويل اعتُمد تقرير يومه بالفعل — يفحص الحالة الفعلية من
  /// قاعدة البيانات مباشرة (لا من الكائن الممرَّر، الذي قد يكون لقطة قديمة).
  Future<void> _ensureTransferEditable(int id) async {
    final map = await _dbService.getInterEntityTransferById(id);
    if (map != null && (map['is_transferred'] as int? ?? 0) == 1) {
      throw StateError('لا يمكن تعديل/حذف تحويل اعتُمد تقريره المالي بالفعل.');
    }
  }

  /// تعديل تحويل معلَّق لم يُعتمَد تقريره بعد — تحديث مباشر بلا أي عكس محاسبي
  /// (لا قيد سُجِّل بعد أصلاً، بخلاف مسحوبات المالك/التحويلات القديمة التي
  /// نُفِّذت فوراً).
  Future<void> updateTransfer(InterEntityTransfer newTransfer) async {
    await _ensureTransferEditable(newTransfer.id!);
    await _dbService.updateById('inter_entity_transfers', newTransfer.toMap(), newTransfer.id!);
  }

  /// نقل ناعم إلى سلة المهملات لتحويل معلَّق لم يُعتمَد تقريره بعد — بلا عكس
  /// محاسبي (لا قيد سُجِّل أصلاً طالما لم يُعتمَد).
  Future<void> deleteTransfer(InterEntityTransfer transfer) async {
    await _ensureTransferEditable(transfer.id!);
    await _trashRepository.trash('inter_entity_transfer', transfer.id!, transfer.statement);
  }

  Future<List<InterEntityTransfer>> getForHotel(int hotelId) async {
    final data = await _dbService.getInterEntityTransfers(hotelId);
    return data.map((e) => InterEntityTransfer.fromMap(e)).toList();
  }

  /// كل التحويلات (بأي حالة، بأي اتجاه) بين هذا الفندق وفندق آخر تحديداً —
  /// "كشف الحساب" الكامل بينهما لعرضه عند التصفّح من InterEntityDebtsPage
  /// (Financial Center ← ديون المنشآت ← فندق ← سجل التحويلات).
  Future<List<InterEntityTransfer>> getHistoryBetween(int hotelId, int otherHotelId) async {
    final all = await getForHotel(hotelId);
    return all.where((t) => t.fromHotelId == otherHotelId || t.toHotelId == otherHotelId).toList();
  }

  /// كل التحويلات المعلَّقة (غير المعتمَدة) لهذا الفندق — كمُرسِل فقط
  /// (fromHotelId)، بأي تاريخ — لعرضها ضمن التقرير اليومي بغض النظر عن تاريخ
  /// التقرير المعروض حالياً، تماماً كمصروفات معلَّقة عادية (راجع
  /// ExpenseRepository.getPendingExpenses بلا أي قيد تاريخ). عدم تقييدها
  /// بتاريخ التقرير يمنع مشكلة "تحويل أُنشئ اليوم لا يظهر" حين يفتح التقرير
  /// افتراضياً على تاريخ الأمس (راجع FinancialSummaryPage._selectedDate).
  Future<List<InterEntityTransfer>> getAllPendingForHotel(int hotelId) async {
    final data = await _dbService.getInterEntityTransfers(hotelId);
    return data.map((e) => InterEntityTransfer.fromMap(e)).where((t) => t.fromHotelId == hotelId && !t.isTransferred).toList();
  }

  /// يُستدعى عند اعتماد التقرير اليومي (نفس لحظة
  /// ExpenseRepository.transferExpenses) — يقفل كل التحويلات المعلَّقة الحالية
  /// لهذا الفندق من التعديل/الحذف **ويُحدِّث تاريخها إلى تاريخ هذا التقرير**
  /// (بلا أي قيد محاسبي بعد، ذاك يبقى مؤجَّلاً إلى الترحيل الفعلي عبر
  /// [bookTransfersForDate]) — ضروري لأن [bookTransfersForDate] عند الترحيل
  /// الفعلي لاحقاً ما زالت تُطابق حسب `date == fund.date` بلا تغيير (لتفادي أي
  /// ترحيل مزدوج بلا إضافة عمود حالة جديد)؛ تاريخ الإنشاء الحقيقي يبقى محفوظاً
  /// دائماً في [InterEntityTransfer.createdAt] فلا يُفقَد شيء.
  Future<void> markTransferredForReport(int hotelId, String reportDate) async {
    final pending = await getAllPendingForHotel(hotelId);
    for (final t in pending) {
      await _dbService.updateById('inter_entity_transfers', {'is_transferred': 1, 'date': reportDate}, t.id!);
    }
  }

  /// يُستدعى فقط من VaultRepository.postReportComponents عند الترحيل الفعلي —
  /// يسجِّل الأثر المحاسبي الحقيقي لكل تحويل اعتُمد (is_transferred=1) بنفس
  /// تاريخ التقرير المُرحَّل، مرة واحدة فقط (postReportComponents نفسها
  /// محمية بفحص reportStatus فلا تتكرر).
  Future<void> bookTransfersForDate(int hotelId, String date) async {
    final data = await _dbService.getInterEntityTransfers(hotelId);
    final sameDay = data.map((e) => InterEntityTransfer.fromMap(e)).where((t) => t.fromHotelId == hotelId && t.date == date && t.isTransferred);
    for (final t in sameDay) {
      await _bookTransfer(t);
    }
  }
}
