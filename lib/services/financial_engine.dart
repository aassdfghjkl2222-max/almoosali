import 'package:intl/intl.dart';
import '../core/database/database_service.dart';
import '../models/financial_account.dart';

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

  /// يستخرج معرف المنشأة الأخرى من فئة ديناميكية مثل entity_12 أو receivable_entity_12.
  int? _parseEntityOtherId(String category) {
    if (category.startsWith('receivable_entity_')) {
      return int.tryParse(category.substring('receivable_entity_'.length));
    }
    if (category.startsWith('entity_')) {
      return int.tryParse(category.substring('entity_'.length));
    }
    return null;
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
      if (sourceCategory.startsWith('entity_')) {
        final resolvedOtherId = otherHotelId ?? _parseEntityOtherId(sourceCategory);
        if (resolvedOtherId != null) {
          await _updateAccount(txn, resolvedOtherId, 'receivable_entity_$hotelId', amount, 'income', 'مستحقات (دفع مصروف عن فندق آخر): $description', referenceId, 'inter_entity');
        }
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
      if (debtCategory.startsWith('entity_')) {
        final resolvedOtherId = otherHotelId ?? _parseEntityOtherId(debtCategory);
        if (resolvedOtherId != null) {
          await _updateAccount(txn, resolvedOtherId, 'receivable_entity_$hotelId', amount, 'expense', 'استلام سداد مستحقات: $description', null, 'debt_settlement');
        }
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

  /// "مسحوبات المالك" — سحب مبلغ من خزنة الفندق (نقد/شبكة) لصالح المالك
  /// شخصياً: خصم من [paymentMethodCategory] ('cash' أو 'bank') + قيد مقابل
  /// على حساب `owner_debt` (أصل: المالك مدين للفندق) بنفس المبلغ، ذرّياً.
  /// عكس اتجاه حساب 'personal' (التزام: الفندق مدين للمالك) عمداً — مفهومان
  /// مختلفان، لا يجوز خلطهما. يُستدعى فقط عند الترحيل الفعلي، بنفس لحظة
  /// ترحيل أي نقد/شبكة عادي — راجع VaultRepository.
  Future<void> recordOwnerDrawing({
    required int hotelId,
    required double amount,
    required String paymentMethodCategory,
    required String description,
    int? referenceId,
    String? referenceType,
  }) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await _updateAccount(txn, hotelId, paymentMethodCategory, amount, 'expense', description, referenceId, referenceType);
      await _updateAccount(txn, hotelId, 'owner_debt', amount, 'income', description, referenceId, referenceType);
    });
  }

  /// "المصروف المشترك" — منشأة واحدة (fundingHotelId) تدفع مبلغاً إجمالياً
  /// بالكامل، ويُوزَّع الأثر المحاسبي على عدة منشآت مشارِكة عبر [otherShares]
  /// (hotelId → حصته، بلا المموِّل نفسه). يُنفَّذ فوراً عند الحفظ (بخلاف
  /// "مسحوبات المالك"/التمويل الأحادي التي تنتظر الترحيل) لأن المصروف
  /// المشترك مبلغ دُفع فعلياً بالكامل من طرف واحد. القيد: خصم كامل
  /// [totalAmount] من [paymentMethodCategory] للمموِّل، ثم لكل حصة زيادة
  /// `entity_$fundingHotelId` (التزام) على حساب المشارِك + `receivable_entity_<hotelId>`
  /// (أصل) على حساب المموِّل — نفس الزوج الذي ينشئه [recordTransaction] تلقائياً
  /// لحالة الفندق الواحد، مُكرَّراً هنا صراحة داخل معاملة واحدة بدل N استدعاء
  /// منفصل (كل استدعاء لـ recordTransaction يفتح معاملته الخاصة).
  Future<void> recordSharedExpense({
    required int fundingHotelId,
    required double totalAmount,
    required String paymentMethodCategory,
    required Map<int, double> otherShares,
    required String description,
    int? referenceId,
  }) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await _updateAccount(txn, fundingHotelId, paymentMethodCategory, totalAmount, 'expense', description, referenceId, 'shared_expense');
      for (final entry in otherShares.entries) {
        final otherHotelId = entry.key;
        final share = entry.value;
        await _updateAccount(txn, otherHotelId, 'entity_$fundingHotelId', share, 'expense', 'مصروف مشترك: $description', referenceId, 'shared_expense');
        await _updateAccount(txn, fundingHotelId, 'receivable_entity_$otherHotelId', share, 'income', 'مصروف مشترك (مستحق): $description', referenceId, 'shared_expense');
      }
    });
  }

  /// تحصيل ذمة أصل (receivable) لصالح المنشأة — عكس [settleDebt] تماماً:
  /// هناك المنشأة تدفع لتخفيض التزام عليها؛ هنا المنشأة تستلم (يزيد النقد/
  /// الشبكة) لتخفيض أصل لها (owner_debt، receivable_entity_*، ...). لا
  /// تُستخدم لتسوية entity_/personal — تلك تبقى عبر settleDebt كما هي.
  Future<void> collectReceivable({
    required int hotelId,
    required String receivableCategory,
    required double amount,
    required String depositTarget, // 'cash' أو 'bank'
    required String description,
  }) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await _updateAccount(txn, hotelId, depositTarget, amount, 'income', 'تحصيل: $description', null, 'debt_settlement');
      await _updateAccount(txn, hotelId, receivableCategory, amount, 'expense', 'تحصيل ذمة: $description', null, 'debt_settlement');
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
    if (category.startsWith('entity_')) return 'دين لمنشأة أخرى';
    if (category.startsWith('receivable_entity_')) return 'مستحق من منشأة أخرى';
    switch (category) {
      case 'cash': return 'الخزنة (نقد)';
      case 'bank': return 'الحساب البنكي';
      case 'personal': return 'حساب المالك';
      case 'entity': return 'ديون لمنشآت أخرى';
      case 'receivable_entity': return 'مستحقات من منشآت أخرى';
      case 'owner_debt': return 'مسحوبات المالك (مستحقة)';
      default: return category;
    }
  }

  String _getAccountType(String category) {
    if (category.startsWith('receivable_entity_')) return 'asset';
    if (category.startsWith('entity_')) return 'liability';
    if (category == 'cash' || category == 'bank' || category == 'receivable_entity' || category == 'client') return 'asset';
    if (category.startsWith('person_') || category == 'owner_debt') return 'asset';
    if (category == 'personal' || category == 'entity' || category == 'supplier') return 'liability';
    return 'asset';
  }
}
