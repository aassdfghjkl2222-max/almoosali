import '../core/database/database_service.dart';
import '../models/vault_transaction.dart';
import '../models/deposited_fund.dart';
import '../models/personal_withdrawal.dart';
import '../models/entity_loan.dart';
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
