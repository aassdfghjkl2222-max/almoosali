import 'dart:convert';
import 'package:intl/intl.dart';
import '../core/database/database_service.dart';
import '../models/financial_account.dart';
import '../models/financial_report.dart';

class FinancialEngine {
  static final FinancialEngine _instance = FinancialEngine._internal();
  final _dbService = DatabaseService();

  factory FinancialEngine() => _instance;

  FinancialEngine._internal();

  Future<double> getBalance(int hotelId, String category) async {
    final db = await _dbService.database;
    final results = await db.query(
      'financial_accounts',
      columns: ['balance'],
      where: 'hotel_id = ? AND category = ?',
      whereArgs: [hotelId, category],
      limit: 1,
    );
    if (results.isEmpty) return 0.0;
    return (results.first['balance'] as num).toDouble();
  }

  Future<double> getTotalLiability(int hotelId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'financial_accounts',
      columns: ['SUM(balance) as total'],
      where: 'hotel_id = ? AND type = ?',
      whereArgs: [hotelId, 'liability'],
    );
    if (results.isEmpty || results.first['total'] == null) return 0.0;
    return (results.first['total'] as num).toDouble();
  }

  Future<double> getTotalReceivable(int hotelId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'financial_accounts',
      columns: ['SUM(balance) as total'],
      where: 'hotel_id = ? AND type = ? AND category NOT IN (?, ?)',
      whereArgs: [hotelId, 'asset', 'cash', 'bank'],
    );
    if (results.isEmpty || results.first['total'] == null) return 0.0;
    return (results.first['total'] as num).toDouble();
  }

  Future<List<FinancialAccount>> getAccountsByType(int hotelId, String type) async {
    final db = await _dbService.database;
    final results = await db.query(
      'financial_accounts',
      where: 'hotel_id = ? AND type = ? AND category NOT IN (?, ?)',
      whereArgs: [hotelId, type, 'cash', 'bank'],
    );
    return results.map((e) => FinancialAccount.fromMap(e)).toList();
  }

  Future<void> postReport(FinancialReport report) async {
    if (report.isPosted) return;
    final db = await _dbService.database;

    await db.transaction((txn) async {
      final details = jsonDecode(report.detailsJson ?? '{}');
      final incomeDetails = details['income_details'] ?? {};
      final expenseDetails = details['expense_details'] ?? {};
      final adjustments = details['adjustments'] ?? {};

      // 1. معالجة الإيرادات (النقد والبنك)
      double cashIn = (double.tryParse(incomeDetails['cash']?.toString() ?? '0') ?? 0) +
                      (double.tryParse(incomeDetails['parking_cash']?.toString() ?? '0') ?? 0);
      double bankIn = (double.tryParse(incomeDetails['pos']?.toString() ?? '0') ?? 0) +
                      (double.tryParse(incomeDetails['parking_pos']?.toString() ?? '0') ?? 0) +
                      (double.tryParse(incomeDetails['transfer']?.toString() ?? '0') ?? 0);

      if (cashIn > 0) await _updateAccount(txn, report.hotelId, 'cash', cashIn, 'income', 'إيراد تقرير يومي: ${report.date}', report.id, 'daily_report');
      if (bankIn > 0) await _updateAccount(txn, report.hotelId, 'bank', bankIn, 'income', 'إيراد تقرير يومي (شبكة/تحويل): ${report.date}', report.id, 'daily_report');

      // 2. معالجة المصروفات
      final List otherExpenses = expenseDetails['other'] ?? [];
      for (var exp in otherExpenses) {
        double amt = (exp['amount'] as num).toDouble();
        String method = exp['method'] ?? 'نقد';
        
        if (method == 'نقد') {
          await _updateAccount(txn, report.hotelId, 'cash', amt, 'expense', "مصروف: ${exp['name']}", report.id, 'daily_report');
        } else if (method == 'شبكة') {
          await _updateAccount(txn, report.hotelId, 'bank', amt, 'expense', "مصروف: ${exp['name']}", report.id, 'daily_report');
        } else if (method == 'شخصي') {
          // المالك دفع من جيبه -> التزام على الفندق للمالك (زيادة رصيد المالك الدائن)
          await _updateAccount(txn, report.hotelId, 'personal', amt, 'expense', "مصروف (دفع من المالك): ${exp['name']}", report.id, 'daily_report');
        } else if (method == 'مصروف خاص') {
          // الفندق دفع للمالك -> خصم من النقد/البنك وزيادة مديونية المالك (مدين)
          String source = exp['private_source'] ?? 'cash'; 
          await _updateAccount(txn, report.hotelId, source, amt, 'expense', "مصروف خاص (للمالك): ${exp['name']}", report.id, 'daily_report');
          // حساب المالك (أصل هنا لأنه مدين للفندق)
          await _updateAccount(txn, report.hotelId, 'person_owner_debt', amt, 'income', "مديونية مصروف خاص: ${exp['name']}", report.id, 'daily_report');
        } else {
          // فندق آخر (دين على هذه المنشأة لمنشأة أخرى)
          await _updateAccount(txn, report.hotelId, 'entity', amt, 'expense', "مصروف (عن طريق فندق زميل): ${exp['name']}", report.id, 'daily_report');
        }
      }

      // مصروفات الإعاشة والاسترداد
      double subsistence = double.tryParse(expenseDetails['subsistence']?.toString() ?? '0') ?? 0;
      if (subsistence > 0) {
        String method = expenseDetails['subsistence_method'] ?? 'نقد';
        String accCat = method == 'نقد' ? 'cash' : 'bank';
        await _updateAccount(txn, report.hotelId, accCat, subsistence, 'expense', 'إعاشة تقرير يومي: ${report.date}', report.id, 'daily_report');
      }
      
      double refund = double.tryParse(expenseDetails['refund']?.toString() ?? '0') ?? 0;
      if (refund > 0) {
        String method = expenseDetails['refund_method'] ?? 'نقد';
        String accCat = method == 'نقد' ? 'cash' : 'bank';
        await _updateAccount(txn, report.hotelId, accCat, refund, 'expense', 'استرداد (Refund) تقرير يومي: ${report.date}', report.id, 'daily_report');
      }

      // تحويل نقد لشبكة
      double cashToPos = double.tryParse(expenseDetails['cash_to_pos']?.toString() ?? '0') ?? 0;
      if (cashToPos > 0) {
        await _updateAccount(txn, report.hotelId, 'cash', cashToPos, 'expense', 'تحويل نقد لشبكة (خروج)', report.id, 'daily_report');
        await _updateAccount(txn, report.hotelId, 'bank', cashToPos, 'income', 'تحويل نقد لشبكة (دخول)', report.id, 'daily_report');
      }

      // 3. الزيادة والنقص
      double increase = double.tryParse(adjustments['increase']?.toString() ?? '0') ?? 0;
      if (increase > 0) {
        String method = adjustments['increase_effect'] == 'نقد' ? 'cash' : 'bank';
        await _updateAccount(txn, report.hotelId, method, increase, 'income', 'زيادة في العهدة: ${report.date}', report.id, 'daily_report');
      }
      
      double shortage = double.tryParse(adjustments['shortage']?.toString() ?? '0') ?? 0;
      if (shortage > 0) {
        String method = adjustments['shortage_effect'] == 'نقد' ? 'cash' : 'bank';
        await _updateAccount(txn, report.hotelId, method, shortage, 'expense', 'عجز في العهدة: ${report.date}', report.id, 'daily_report');
      }

      // 4. إنشاء سجل في الأموال المودعة (لغرض الأرشفة)
      await txn.insert('deposited_funds', {
        'hotel_id': report.hotelId,
        'report_id': report.id,
        'date': report.date,
        'cash_amount': cashIn - (double.tryParse(expenseDetails['cash_to_pos']?.toString() ?? '0') ?? 0), // تقريبي للأرشفة
        'network_amount': bankIn,
        'cash_status': 'transferred',
        'network_status': 'transferred',
        'is_archived': 1,
      });

      // 5. تحديث حالة التقرير وإقفاله
      await txn.update('financial_reports', {'is_posted': 1, 'is_locked': 1}, where: 'id = ?', whereArgs: [report.id]);
    });
  }

  Future<void> addPerson(int hotelId, String name) async {
    final db = await _dbService.database;
    final category = 'person_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('financial_accounts', {
      'hotel_id': hotelId,
      'name': name,
      'type': 'asset', // ديون على أشخاص تعتبر أصول للمنشأة
      'category': category,
      'balance': 0.0,
    });
  }

  Future<List<FinancialAccount>> getPeople(int hotelId) async {
    final data = await _dbService.getPeopleAccounts(hotelId);
    return data.map((e) => FinancialAccount.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getLedger(int hotelId, String category) async {
    return await _dbService.getLedgerByAccount(hotelId, category);
  }

  Future<void> _updateAccount(dynamic txn, int hotelId, String category, double amount, String actionType, String desc, int? refId, String? refType) async {
    final acc = await _getAccount(txn, hotelId, category);
    double before = acc.balance;
    double after;

    if (acc.type == 'asset') {
      after = actionType == 'income' ? before + amount : before - amount;
    } else {
      // liability
      after = actionType == 'income' ? before - amount : before + amount;
    }

    await txn.update('financial_accounts', {'balance': after}, where: 'id = ?', whereArgs: [acc.id]);

    await txn.insert('financial_ledger', {
      'hotel_id': hotelId,
      'account_id': acc.id,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'time': DateFormat('HH:mm:ss').format(DateTime.now()),
      'type': (acc.type == 'asset' && actionType == 'income') || (acc.type == 'liability' && actionType == 'expense') ? 'debit' : 'credit',
      'amount': amount,
      'balance_before': before,
      'balance_after': after,
      'description': desc,
      'reference_id': refId,
      'reference_type': refType,
    });
  }

  Future<void> recordTransaction({
    required int hotelId,
    required String sourceCategory,
    required double amount,
    required String type,
    required String description,
    int? referenceId,
    String? referenceType,
    int? otherHotelId,
  }) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await _updateAccount(txn, hotelId, sourceCategory, amount, type == 'income' ? 'income' : 'expense', description, referenceId, referenceType);
      if (sourceCategory == 'entity' && otherHotelId != null) {
        await _updateAccount(txn, otherHotelId, 'receivable_entity', amount, 'income', 'مستحقات (دفع مصروف عن فندق آخر): $description', referenceId, 'inter_entity');
      }
    });
  }

  Future<void> settleDebt({
    required int hotelId,
    required String debtCategory,
    required double amount,
    required String paymentSource,
    required String description,
    int? otherHotelId,
  }) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await _updateAccount(txn, hotelId, paymentSource, amount, 'expense', 'سداد مديونية: $description', null, 'debt_settlement');
      await _updateAccount(txn, hotelId, debtCategory, amount, 'income', 'تخفيض دين: $description', null, 'debt_settlement');
      if (debtCategory == 'entity' && otherHotelId != null) {
        await _updateAccount(txn, otherHotelId, 'receivable_entity', amount, 'expense', 'استلام سداد مستحقات: $description', null, 'debt_settlement');
      }
    });
  }

  Future<void> recordPersonalAction({
    required int hotelId,
    required String personCategory, // 'personal' (owner) or person account
    required double amount,
    required String action, // 'withdraw' or 'deposit'
    required String source, // 'cash' or 'bank'
    required String description,
  }) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      if (action == 'withdraw') {
        // سحب: نقص في الأصول (نقد/بنك) وزيادة في مديونية الشخص (Asset)
        await _updateAccount(txn, hotelId, source, amount, 'expense', 'سحب شخصي: $description', null, 'personal_action');
        await _updateAccount(txn, hotelId, personCategory, amount, 'income', 'مديونية سحب: $description', null, 'personal_action');
      } else {
        // إيداع: زيادة في الأصول ونقص في المديونية
        await _updateAccount(txn, hotelId, source, amount, 'income', 'إيداع شخصي: $description', null, 'personal_action');
        await _updateAccount(txn, hotelId, personCategory, amount, 'expense', 'سداد مديونية: $description', null, 'personal_action');
      }
    });
  }

  Future<FinancialAccount> _getAccount(dynamic txn, int hotelId, String category) async {
    final results = await txn.query('financial_accounts', where: 'hotel_id = ? AND category = ?', whereArgs: [hotelId, category], limit: 1);
    if (results.isEmpty) {
      String name = _getAccountName(category);
      String type = _getAccountType(category);
      final id = await txn.insert('financial_accounts', {'hotel_id': hotelId, 'name': name, 'type': type, 'category': category, 'balance': 0.0});
      return FinancialAccount(id: id, hotelId: hotelId, name: name, type: type, category: category, balance: 0.0);
    }
    return FinancialAccount.fromMap(results.first);
  }

  String _getAccountName(String category) {
    switch (category) {
      case 'cash': return 'الخزنة (نقد)';
      case 'bank': return 'الحساب البنكي';
      case 'personal': return 'حساب المالك';
      case 'entity': return 'ديون لمنشآت أخرى';
      case 'receivable_entity': return 'مستحقات من منشآت أخرى';
      default: return category;
    }
  }

  String _getAccountType(String category) {
    if (category == 'cash' || category == 'bank' || category == 'receivable_entity' || category == 'client') return 'asset';
    if (category.startsWith('person_')) return 'asset';
    if (category == 'personal' || category == 'entity' || category == 'supplier') return 'liability';
    return 'asset';
  }
}
