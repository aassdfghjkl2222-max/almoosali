import 'dart:convert';
import '../core/database/database_service.dart';
import '../models/vault_transaction.dart';
import '../models/deposited_fund.dart';
import '../models/pending_expense.dart';
import '../models/personal_withdrawal.dart';
import '../models/entity_loan.dart';
import '../models/advance_withdrawal.dart';
import '../services/financial_engine.dart';
import 'inter_entity_transfer_repository.dart';
import 'supplier_repository.dart';

class VaultRepository {
  final _dbService = DatabaseService();
  final _financialEngine = FinancialEngine();
  final _supplierRepository = SupplierRepository();
  final _transferRepository = InterEntityTransferRepository();

  Future<Map<String, double>> getBalances(int? hotelId) async {
    if (hotelId == null) return {'cash': 0, 'bank': 0, 'personal': 0};
    final cash = await _financialEngine.getBalance(hotelId, 'cash');
    final bank = await _financialEngine.getBalance(hotelId, 'bank');
    final personal = await _financialEngine.getBalance(hotelId, 'personal');
    return {'cash': cash, 'bank': bank, 'personal': personal};
  }

  Future<List<VaultTransaction>> getTransactions(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getVaultTransactions(hotelId);
    return data.map((e) => VaultTransaction.fromMap(e)).toList();
  }

  Future<int> addTransaction(VaultTransaction transaction) async {
    return await _dbService.insertVaultTransaction(transaction.toMap());
  }

  Future<List<DepositedFund>> getDepositedFunds({required int? hotelId, bool? isArchived}) async {
    if (hotelId == null) return [];
    final data = await _dbService.getDepositedFunds(hotelId: hotelId, isArchived: isArchived);
    return data.map((e) => DepositedFund.fromMap(e)).toList();
  }

  Future<int> addDepositedFund(DepositedFund fund) async {
    return await _dbService.insertDepositedFund(fund.toMap());
  }

  Future<int> updateDepositedFund(DepositedFund fund) async {
    if (fund.id == null) return 0;
    return await _dbService.updateDepositedFund(fund.toMap(), fund.id!);
  }

  Future<DepositedFund?> getDepositedFundByReportId(int reportId) async {
    final map = await _dbService.getDepositedFundByReportId(reportId);
    return map != null ? DepositedFund.fromMap(map) : null;
  }

  /// يُستخدم فقط عند حذف تقرير مالي لم يُرحَّل بعد (راجع
  /// FinancialSummaryPage._deleteReport) — تقرير مُرحَّل لا يُحذف إطلاقاً.
  Future<int> deleteDepositedFund(int id) async {
    return await _dbService.deleteById('deposited_funds', id);
  }

  Future<int> updateDepositedFundByReportId(DepositedFund fund, int reportId) async {
    return await _dbService.updateDepositedFundByReportId(fund.toMap(), reportId);
  }

  /// "ترحيل صافي النقد" — الإجراء الوحيد الذي يخصم/يودع صافي النقد نفسه. لا
  /// يمس أي مصروف/سحب مالك/تحويل/عهدة على الفندق أخرى بعد الآن — تلك كلها
  /// مسؤولية [postReportComponents] وحدها (راجع البند 4 من متطلبات إعادة
  /// التصميم: الفصل الكامل بين الإجراءين). مستقل تماماً ولا ينتظر
  /// [postReportComponents] بأي اتجاه.
  Future<void> transferCashToVault(DepositedFund fund) async {
    if (fund.id == null) return;
    // إعادة قراءة الحالة من قاعدة البيانات مباشرة (لا من [fund] الممرَّرة، التي
    // قد تكون لقطة قديمة من قائمة لم تُحدَّث بعد) — يمنع الترحيل المزدوج عند
    // ضغطتين متتاليتين سريعتين قبل انعكاس أول ترحيل في الواجهة.
    final freshMap = await _dbService.getDepositedFundById(fund.id!);
    if (freshMap == null || freshMap['cash_status'] == 'transferred') return;

    await _financialEngine.recordTransaction(
      hotelId: fund.hotelId,
      sourceCategory: 'cash',
      amount: fund.cashAmount,
      type: 'income',
      description: "ترحيل صافي النقد: ${fund.date}",
      referenceId: fund.id,
      referenceType: 'deposited_fund',
    );

    final updatedFund = fund.copyWith(
      cashStatus: 'transferred',
      isArchived: fund.reportStatus == 'posted',
      postedAt: DateTime.now().toIso8601String(),
      postedBy: "مدير النظام",
    );
    await updateDepositedFund(updatedFund);

    if (updatedFund.isArchived) {
      await _dbService.updateById('financial_reports', {'is_posted': 1, 'is_locked': 1}, fund.reportId!);
    }
  }

  /// "ترحيل التقرير" — كل شيء في التقرير ما عدا صافي النقد: إيراد الشبكة/
  /// البنك، ثم كل المصروفات الخاصة (مسحوبات المالك بالمسار القديم، عهدة على
  /// الفندق، مصروف ممَّول من فندق آخر، مصروف من الخزنة) عبر
  /// [_postSpecialPendingExpenses] كما كانت سابقاً بالضبط — فقط لم تعد
  /// مُنتظِرة اكتمال صافي النقد لتُنفَّذ. مستقل تماماً وقابل للتكرار الآمن
  /// (يتحقق من [DepositedFund.reportStatus] أولاً فلا يُعاد تنفيذه مرتين).
  Future<void> postReportComponents(DepositedFund fund) async {
    if (fund.id == null) return;
    // إعادة قراءة الحالة من قاعدة البيانات مباشرة قبل التنفيذ — نفس سبب
    // الفحص الطازج في [transferCashToVault]، يمنع تكرار ترحيل التقرير.
    final freshMap = await _dbService.getDepositedFundById(fund.id!);
    if (freshMap == null || freshMap['report_status'] == 'posted') return;

    if (fund.networkStatus != 'transferred') {
      await _financialEngine.recordTransaction(
        hotelId: fund.hotelId,
        sourceCategory: 'bank',
        amount: fund.networkAmount,
        type: 'income',
        description: "ترحيل شبكة تقرير يومي: ${fund.date}",
        referenceId: fund.id,
        referenceType: 'deposited_fund',
      );
    }

    await _postSpecialPendingExpenses(fund);
    // التحويل بين المنشآت المُعتمَد (is_transferred=1 عند تأكيد التقرير) يُسجَّل
    // محاسبياً هنا فقط، عند الترحيل الفعلي — راجع
    // InterEntityTransferRepository.bookTransfersForDate.
    await _transferRepository.bookTransfersForDate(fund.hotelId, fund.date);
    // المصروفات بتمويل شبكة/بنك — لا تُخصَم من إيراد اليوم (راجع
    // FinancialSummaryPage._calculateTotals)، بل من رصيد البنك المتراكم في
    // المركز المالي هنا فقط، عند الترحيل.
    await _postNetworkFundedExpenses(fund);

    final updatedFund = fund.copyWith(
      networkStatus: 'transferred',
      reportStatus: 'posted',
      isArchived: fund.cashStatus == 'transferred',
      postedAt: DateTime.now().toIso8601String(),
      postedBy: "مدير النظام",
    );
    await updateDepositedFund(updatedFund);

    if (updatedFund.isArchived) {
      await _dbService.updateById('financial_reports', {'is_posted': 1, 'is_locked': 1}, fund.reportId!);
    }
  }

  /// هل "ترحيل التقرير" اكتمل بالفعل لهذا الفندق بهذا التاريخ؟ — المرجع
  /// المعتمَد الوحيد لتحديد إن كانت العمليات المرتبطة بهذا التاريخ (مسحوبات
  /// المالك، تحويل بين المنشآت، ...) "مُرحَّلة" أم لا (راجع البند 2 من متطلبات
  /// إعادة التصميم). false أيضاً إن لم يوجد تقرير مالي بهذا التاريخ إطلاقاً —
  /// لا شيء يُرحَّل بعد فتبقى العمليات قابلة للتعديل.
  Future<bool> isReportComponentsPostedForDate(int hotelId, String date) async {
    final map = await _dbService.getDepositedFundByHotelAndDate(hotelId, date);
    return map != null && map['report_status'] == 'posted';
  }

  /// يُنفَّذ من [postReportComponents] فقط الآن (لم يعد يعتمد على اكتمال صافي
  /// النقد). يبحث عن مصروفات معلقة مُرحَّلة (is_transferred=1) بنفس تاريخ
  /// التقرير ولها أثر مالي خاص (مسحوبات مالك، أو مموَّلة من فندق آخر)، وينشئ
  /// القيود التلقائية المقابلة في المركز المالي — أي مصروف نقد/شبكة عادي
  /// مُغطّى أصلاً بالمبلغ الصافي المُرحَّل عبر [transferCashToVault]/
  /// [postReportComponents]، فلا يُعاد هنا.
  Future<void> _postSpecialPendingExpenses(DepositedFund fund) async {
    final rows = await _dbService.getPendingExpenses(hotelId: fund.hotelId, isTransferred: true);
    final sameDay = rows.where((m) => m['date'] == fund.date);
    for (final map in sameDay) {
      final expense = PendingExpense.fromMap(map);
      if (expense.isOwnerDrawing) {
        await _financialEngine.recordOwnerDrawing(
          hotelId: expense.hotelId,
          amount: expense.amount,
          paymentMethodCategory: 'cash',
          description: "مسحوبات المالك: ${expense.statement}",
          referenceId: expense.id,
          referenceType: 'pending_expense',
        );
      } else if (expense.isFundedByOtherHotel) {
        await _financialEngine.recordTransaction(
          hotelId: expense.hotelId,
          sourceCategory: 'entity_${expense.fundingSourceHotelId}',
          amount: expense.amount,
          type: 'expense',
          description: "مصروف ممَّول من فندق آخر: ${expense.statement}",
          referenceId: expense.id,
          referenceType: 'pending_expense',
          otherHotelId: expense.fundingSourceHotelId,
        );
      } else if (expense.isHotelAdvance) {
        // "عهدة على الفندق": المالك دفع المصروف من ماله الخاص عن المنشأة — بلا خصم
        // أي نقد/خزنة/شبكة (مُستبعَد أصلاً من oCash/oBank في _calculateTotals)،
        // فقط زيادة التزام "حساب المالك" (المنشأة مدينة للمالك) — نفس آلية
        // entity_ بفئة 'personal'.
        await _financialEngine.recordTransaction(
          hotelId: expense.hotelId,
          sourceCategory: 'personal',
          amount: expense.amount,
          type: 'expense',
          description: "عهدة على الفندق (تمويل شخصي من المالك): ${expense.statement}",
          referenceId: expense.id,
          referenceType: 'pending_expense',
        );
      } else if (expense.paymentMethod == PendingExpense.paymentMethodSafe) {
        // مصروف بتمويل "الخزنة": خصم فوري من رصيد الخزنة المتراكم (نفس فئة
        // 'cash' الداخلية التي يستخدمها "نقد")، بخلاف "نقد" الذي يُخصم من
        // إيراد اليوم نفسه (مُغطّى ضمن المبلغ الصافي المُرحَّل، لا يُعاد هنا).
        await _financialEngine.recordTransaction(
          hotelId: expense.hotelId,
          sourceCategory: 'cash',
          amount: expense.amount,
          type: 'expense',
          description: "مصروف من الخزنة: ${expense.statement}",
          referenceId: expense.id,
          referenceType: 'pending_expense',
        );
      } else if (expense.isDeferredDebt && expense.supplierId != null) {
        // "آجل (دين)": مصروف حقيقي غير مدفوع — لا يُخصَم أي نقد/بنك، فقط يُنشأ
        // دين على المنشأة لصالح المورد الآن عند الترحيل فعلياً (وليس عند
        // إنشاء المصروف المعلَّق نفسه — كان يُنشأ فوراً سابقاً، وهذا يخالف مبدأ
        // "العمليات المعلَّقة لا تؤثر على المركز المالي قبل الترحيل").
        await _supplierRepository.ensureDebtForPendingExpense(
          hotelId: expense.hotelId,
          supplierId: expense.supplierId!,
          pendingExpenseId: expense.id!,
          amount: expense.amount,
          statement: expense.statement,
          dueDate: expense.dueDate,
        );
      }
    }
  }

  /// يُنفَّذ من [postReportComponents] فقط الآن — يجمع كل مبالغ المصروفات
  /// بتمويل "شبكة" في هذا التقرير (إعاشة/استرداد ببند شبكة + كل بند مصروف
  /// حر/معلَّق ممَّول شبكة، مقروءة من details_json مباشرة — وليس من جدول
  /// pending_expenses فقط، لأن البنود الحرة غير موجودة فيه إطلاقاً) ويسجِّلها
  /// كخصم واحد مُجمَّع من رصيد البنك المتراكم في المركز المالي — لا فرق بين
  /// "شبكة" و"بنك" (راجع البند المقابل من متطلبات إعادة بناء دورة الحياة
  /// المحاسبية). يستبعد أي بند مموَّل من فندق آخر (funding_source_hotel_name)،
  /// فتلك تُعالَج بالكامل عبر entity_ في [_postSpecialPendingExpenses] فلا
  /// يجوز خصمها من رصيد بنك هذا الفندق أيضاً — كان أثرها سابقاً مطموراً ضمن
  /// صافي الشبكة المُرحَّل نفسه بلا أي قيد صريح، فلا يُعاد هنا احترازاً من
  /// ازدواج الخصم.
  Future<void> _postNetworkFundedExpenses(DepositedFund fund) async {
    final reportMap = fund.reportId != null ? await _dbService.getFinancialReportById(fund.reportId!) : null;
    final detailsJson = reportMap?['details_json'] as String?;
    if (detailsJson == null) return;
    final details = jsonDecode(detailsJson) as Map<String, dynamic>;
    final exp = (details['expense_details'] as Map?) ?? {};
    double asDouble(dynamic v) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);

    double total = 0;
    if ((exp['subsistence_method']?.toString() ?? 'نقد') == 'شبكة') total += asDouble(exp['subsistence']);
    if ((exp['refund_method']?.toString() ?? 'نقد') == 'شبكة') total += asDouble(exp['refund']);
    for (final item in (exp['other'] as List? ?? [])) {
      if (item['funding_source_hotel_name'] != null) continue;
      if (item['method']?.toString() == 'شبكة') total += asDouble(item['amount']);
    }
    if (total.abs() < 0.01) return;

    await _financialEngine.recordTransaction(
      hotelId: fund.hotelId,
      sourceCategory: 'bank',
      amount: total,
      type: 'expense',
      description: "مصروفات ممَّولة من الشبكة/البنك: ${fund.date}",
      referenceId: fund.id,
      referenceType: 'deposited_fund_network_expenses',
    );
  }

  // Personal Withdrawals
  Future<List<PersonalWithdrawal>> getPersonalWithdrawals(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getPersonalWithdrawals(hotelId);
    return data.map((e) => PersonalWithdrawal.fromMap(e)).toList();
  }

  Future<int> addPersonalWithdrawal(PersonalWithdrawal withdrawal) async {
    final balanceType = withdrawal.method == 'شبكة' ? 'bank' : 'cash';
    
    await _financialEngine.recordTransaction(
      hotelId: withdrawal.hotelId,
      sourceCategory: balanceType,
      amount: withdrawal.amount,
      type: 'expense',
      description: "سحب شخصي: ${withdrawal.statement}",
      referenceType: 'personal_withdrawal',
    );

    return await _dbService.insertPersonalWithdrawal(withdrawal.toMap());
  }

  // Entity Loans
  Future<List<EntityLoan>> getEntityLoans(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getEntityLoans(hotelId);
    return data.map((e) => EntityLoan.fromMap(e)).toList();
  }

  Future<int> addEntityLoan(EntityLoan loan) async {
    final balanceType = loan.source == 'شبكة' ? 'bank' : 'cash';
    
    await _financialEngine.recordTransaction(
      hotelId: loan.hotelId,
      sourceCategory: balanceType,
      amount: loan.amount,
      type: 'income',
      description: "إيداع قرض على المنشأة: ${loan.statement}",
      referenceType: 'entity_loan',
    );

    return await _dbService.insertEntityLoan(loan.toMap());
  }

  // مسحوبات المالك (Owner Withdrawals) — الجدول الداخلي لا يزال باسم advance_withdrawals
  Future<List<AdvanceWithdrawal>> getAdvanceWithdrawals(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getAdvanceWithdrawals(hotelId);
    return data.map((e) => AdvanceWithdrawal.fromMap(e)).toList();
  }

  /// "مسحوبات المالك" — سحب فوري من نقد/خزنة/شبكة الفندق لصالح المالك، ليست
  /// مصروفاً: نقص في أصول الفندق وزيادة ذمة owner_debt المستحقة على المالك،
  /// عبر [FinancialEngine.recordOwnerDrawing]. عكس "عهدة على الفندق" (paymentMethodHotelAdvance)
  /// تماماً في اتجاه القيد — هناك المالك يموِّل الفندق، هنا الفندق يدفع للمالك.
  /// "نقد" و"الخزنة" كلاهما يؤولان لنفس فئة FinancialEngine الداخلية ('cash')
  /// — الفرق نصّي/توثيقي فقط في هذا المسار الفوري (لا يوجد يوم تقرير يُنسَب
  /// إليه الفرق بينهما هنا، بخلاف المصروف المعلّق العادي). الصف يُدرَج أولاً
  /// (قبل القيد المحاسبي) حتى يحمل القيد referenceId حقيقياً يشير إليه —
  /// يلزم لتتبّع/عكس هذه العملية لاحقاً عبر updateOwnerWithdrawal/deleteOwnerWithdrawal.
  Future<int> addOwnerWithdrawal(AdvanceWithdrawal withdrawal) async {
    final id = await _dbService.insertAdvanceWithdrawal(withdrawal.toMap());
    await _financialEngine.recordOwnerDrawing(
      hotelId: withdrawal.hotelId,
      amount: withdrawal.amount,
      paymentMethodCategory: withdrawal.method == 'شبكة' ? 'bank' : 'cash',
      description: "مسحوبات المالك (${withdrawal.method}): ${withdrawal.statement}",
      referenceId: id,
      referenceType: 'owner_withdrawal',
    );
    return id;
  }

  /// يمنع تعديل/حذف سحب مالك رُحِّل تقرير يوم تسجيله بالفعل — راجع البند 2 من
  /// متطلبات إعادة تصميم سير العمل المالي. "مُرحَّل" هنا يعني تحديداً: اكتمل
  /// "ترحيل التقرير" (postReportComponents) لتاريخ هذا السحب — راجع
  /// isReportComponentsPostedForDate.
  Future<void> _ensureOwnerWithdrawalEditable(AdvanceWithdrawal withdrawal) async {
    if (await isReportComponentsPostedForDate(withdrawal.hotelId, withdrawal.date)) {
      throw StateError('لا يمكن تعديل/حذف مسحوب مالك بتاريخ رُحِّل تقريره المالي بالفعل.');
    }
  }

  /// تعديل سحب مالك لم يُرحَّل تقريره بعد — يعكس الأثر المحاسبي القديم
  /// (بقيم [oldWithdrawal] المخزَّنة فعلياً) ثم يسجِّل الأثر الجديد بقيم
  /// [newWithdrawal]، بدل تعديل الرصيد مباشرة — يحافظ على أثر كامل في دفتر
  /// الأستاذ (financial_ledger) لكلا الحركتين. [newWithdrawal.id] يجب أن
  /// يساوي [oldWithdrawal.id].
  Future<void> updateOwnerWithdrawal(AdvanceWithdrawal oldWithdrawal, AdvanceWithdrawal newWithdrawal) async {
    await _ensureOwnerWithdrawalEditable(oldWithdrawal);
    await _financialEngine.reverseOwnerDrawing(
      hotelId: oldWithdrawal.hotelId,
      amount: oldWithdrawal.amount,
      paymentMethodCategory: oldWithdrawal.method == 'شبكة' ? 'bank' : 'cash',
      description: "عكس مسحوب مالك (تعديل): ${oldWithdrawal.statement}",
      referenceId: oldWithdrawal.id,
      referenceType: 'owner_withdrawal',
    );
    await _financialEngine.recordOwnerDrawing(
      hotelId: newWithdrawal.hotelId,
      amount: newWithdrawal.amount,
      paymentMethodCategory: newWithdrawal.method == 'شبكة' ? 'bank' : 'cash',
      description: "مسحوبات المالك (${newWithdrawal.method}): ${newWithdrawal.statement}",
      referenceId: newWithdrawal.id,
      referenceType: 'owner_withdrawal',
    );
    await _dbService.updateById('advance_withdrawals', newWithdrawal.toMap(), newWithdrawal.id!);
  }

  /// حذف سحب مالك لم يُرحَّل تقريره بعد — يعكس أثره المحاسبي ثم يحذف الصف.
  Future<void> deleteOwnerWithdrawal(AdvanceWithdrawal withdrawal) async {
    await _ensureOwnerWithdrawalEditable(withdrawal);
    await _financialEngine.reverseOwnerDrawing(
      hotelId: withdrawal.hotelId,
      amount: withdrawal.amount,
      paymentMethodCategory: withdrawal.method == 'شبكة' ? 'bank' : 'cash',
      description: "عكس مسحوب مالك (حذف): ${withdrawal.statement}",
      referenceId: withdrawal.id,
      referenceType: 'owner_withdrawal',
    );
    await _dbService.deleteById('advance_withdrawals', withdrawal.id!);
  }

  Future<void> undoTransaction(VaultTransaction transaction) async {
    final balanceType = transaction.source == 'شبكة' ? 'bank' : 'cash';
    await _financialEngine.recordTransaction(
      hotelId: transaction.hotelId,
      sourceCategory: balanceType,
      amount: transaction.amount,
      type: 'income',
      description: "تراجع عن: ${transaction.type}",
      referenceId: transaction.id,
      referenceType: 'undo',
    );
  }
}
