import '../core/database/database_service.dart';
import '../models/vault_transaction.dart';
import '../models/deposited_fund.dart';
import '../models/pending_expense.dart';
import '../models/personal_withdrawal.dart';
import '../models/entity_loan.dart';
import '../models/advance_withdrawal.dart';
import '../services/financial_engine.dart';

class VaultRepository {
  final _dbService = DatabaseService();
  final _financialEngine = FinancialEngine();

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

  Future<void> transferNetworkToBank(DepositedFund fund) async {
    if (fund.id == null || fund.networkStatus == 'transferred') return;
    
    await _financialEngine.recordTransaction(
      hotelId: fund.hotelId,
      sourceCategory: 'bank',
      amount: fund.networkAmount,
      type: 'income',
      description: "ترحيل شبكة تقرير يومي: ${fund.date}",
      referenceId: fund.id,
      referenceType: 'deposited_fund',
    );

    final updatedFund = fund.copyWith(
      networkStatus: 'transferred',
      isArchived: fund.cashStatus == 'transferred',
      postedAt: DateTime.now().toIso8601String(),
      postedBy: "مدير النظام",
    );
    await updateDepositedFund(updatedFund);

    if (updatedFund.isArchived) {
      await _dbService.updateById('financial_reports', {'is_posted': 1, 'is_locked': 1}, fund.reportId!);
      await _postSpecialPendingExpenses(updatedFund);
    }
  }

  Future<void> transferCashToVault(DepositedFund fund) async {
    if (fund.id == null || fund.cashStatus == 'transferred') return;
    
    await _financialEngine.recordTransaction(
      hotelId: fund.hotelId,
      sourceCategory: 'cash',
      amount: fund.cashAmount,
      type: 'income',
      description: "ترحيل نقد تقرير يومي: ${fund.date}",
      referenceId: fund.id,
      referenceType: 'deposited_fund',
    );

    final updatedFund = fund.copyWith(
      cashStatus: 'transferred',
      isArchived: fund.networkStatus == 'transferred',
      postedAt: DateTime.now().toIso8601String(),
      postedBy: "مدير النظام",
    );
    await updateDepositedFund(updatedFund);

    if (updatedFund.isArchived) {
      await _dbService.updateById('financial_reports', {'is_posted': 1, 'is_locked': 1}, fund.reportId!);
      await _postSpecialPendingExpenses(updatedFund);
    }
  }

  /// يُنفَّذ فقط في لحظة اكتمال ترحيل التقرير بالكامل (isArchived يتحوّل لأول
  /// مرة إلى true — إما من [transferCashToVault] أو [transferNetworkToBank]،
  /// أيّهما يُتمِّم الترحيل، فلا يتكرر التنفيذ لأن الصندوق يختفي من "الأموال
  /// غير المرحَّلة" بعدها). يبحث عن مصروفات معلقة مُرحَّلة (is_transferred=1)
  /// بنفس تاريخ التقرير ولها أثر مالي خاص (مسحوبات مالك، أو مموَّلة من فندق
  /// آخر)، وينشئ القيود التلقائية المقابلة في المركز المالي — أي مصروف نقد/
  /// شبكة عادي مُغطّى أصلاً بالمبلغ الصافي المُرحَّل أعلاه، فلا يُعاد هنا.
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
      } else if (expense.paymentMethod == 'شخصي') {
        // المالك دفع المصروف من ماله الخاص عن المنشأة — بلا خصم أي نقد/شبكة
        // (مُستبعَد أصلاً من oCash/oBank في _calculateTotals)، فقط زيادة التزام
        // "حساب المالك" (المنشأة مدينة للمالك) — نفس آلية entity_ بفئة 'personal'.
        await _financialEngine.recordTransaction(
          hotelId: expense.hotelId,
          sourceCategory: 'personal',
          amount: expense.amount,
          type: 'expense',
          description: "دفع شخصي من المالك: ${expense.statement}",
          referenceId: expense.id,
          referenceType: 'pending_expense',
        );
      }
    }
  }

  // Personal Withdrawals
  Future<List<PersonalWithdrawal>> getPersonalWithdrawals(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getPersonalWithdrawals(hotelId);
    return data.map((e) => PersonalWithdrawal.fromMap(e)).toList();
  }

  Future<int> addPersonalWithdrawal(PersonalWithdrawal withdrawal) async {
    final balanceType = withdrawal.method == 'حساب بنكي' ? 'bank' : 'cash';
    
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
    final balanceType = loan.source == 'حساب بنكي' ? 'bank' : 'cash';
    
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

  // السلفة (Advance Withdrawals)
  Future<List<AdvanceWithdrawal>> getAdvanceWithdrawals(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getAdvanceWithdrawals(hotelId);
    return data.map((e) => AdvanceWithdrawal.fromMap(e)).toList();
  }

  /// "سلفة" — سحب فوري من نقد/شبكة الفندق لصالح المالك، ليست مصروفاً (بخلاف
  /// "مسحوبات المالك" عبر مصروف معلّق التي تنتظر الترحيل). القيد المحاسبي
  /// (خصم فوري + ذمة owner_debt) عبر [FinancialEngine.recordOwnerDrawing]
  /// نفسها المُستخدَمة هناك — نفس الحساب المحاسبي بالضبط، فقط بابا دخول مختلف
  /// وتوقيت فوري بدل مؤجَّل.
  Future<int> addAdvanceWithdrawal(AdvanceWithdrawal advance) async {
    await _financialEngine.recordOwnerDrawing(
      hotelId: advance.hotelId,
      amount: advance.amount,
      paymentMethodCategory: advance.method == 'شبكة' ? 'bank' : 'cash',
      description: "سلفة: ${advance.statement}",
      referenceType: 'advance_withdrawal',
    );
    return await _dbService.insertAdvanceWithdrawal(advance.toMap());
  }

  Future<void> undoTransaction(VaultTransaction transaction) async {
    final balanceType = transaction.source == 'الحساب البنكي' ? 'bank' : 'cash';
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
