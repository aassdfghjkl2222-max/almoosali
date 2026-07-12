import '../core/database/database_service.dart';
import '../models/relationship_txn.dart';
import 'settlement_repository.dart';

/// مستودع قراءة فقط يجمع العلاقات المالية (فنادق/أشخاص/موردون) من نظامين
/// حقيقيين قائمين فعلاً في المشروع:
/// 1) دفتر الأستاذ FinancialEngine (financial_accounts/financial_ledger) —
///    فئات entity_(id)/receivable_entity_(id) بين الفنادق، وperson_(id) للأشخاص.
/// 2) نظام التسويات Settlements (settlements/settlement_transactions) —
///    المصدر الوحيد الحقيقي لديون الموردين، ومصدر موازٍ لبعض ديون
///    الفنادق/الأشخاص المُنشأة من شاشات "التسويات المالية".
/// لا يُعدَّل أي من النظامين هنا؛ فقط تُقرأ عملياتهما وتُعرض معاً بشكل موحّد
/// مع الإبقاء على حقل `source` واضحاً لكل عملية حتى يبقى أصلها معروفاً.
class FinancialRelationshipsRepository {
  final _dbService = DatabaseService();
  final _settlementRepo = SettlementRepository();

  String _refTypeLabel(String? refType) {
    switch (refType) {
      case 'daily_report':
        return "مصروف يومي";
      case 'employee_advance':
        return "سلفة موظف";
      case 'debt_settlement':
        return "سداد دين";
      case 'inter_entity':
        return "تحويل بين المنشآت";
      case 'personal_action':
        return "حركة شخصية";
      case 'entity_loan':
        return "قرض على المنشأة";
      default:
        return "حركة مالية";
    }
  }

  /// أرصدة حالية (وليست مجموع حركات تاريخية) — تُستخدم في بطاقات الملخص وقوائم
  /// الفنادق حتى لا تُحتسب دفعة سداد ودّينها الأصلي مرتين. المصدر: الرصيد
  /// الحالي المخزَّن في financial_accounts + المتبقي الحالي remainingAmount
  /// من التسويات المفتوحة فقط.
  Future<Map<int, Map<String, double>>> getHotelBalances(Map<int, String> hotelNames) async {
    final result = <int, Map<String, double>>{for (final id in hotelNames.keys) id: {'receivable': 0, 'payable': 0}};
    final db = await _dbService.database;
    final accounts = await db.rawQuery("SELECT * FROM financial_accounts WHERE category GLOB 'entity_*' OR category GLOB 'receivable_entity_*'");
    for (final acc in accounts) {
      final hotelId = acc['hotel_id'] as int;
      if (!result.containsKey(hotelId)) continue;
      final category = acc['category'] as String;
      final balance = (acc['balance'] as num).toDouble();
      if (category.startsWith('receivable_entity_')) {
        result[hotelId]!['receivable'] = result[hotelId]!['receivable']! + balance;
      } else {
        result[hotelId]!['payable'] = result[hotelId]!['payable']! + balance;
      }
    }
    final settlements = await _settlementRepo.getSettlements(type: 'inter_entity');
    for (final s in settlements) {
      final rem = s.remainingAmount;
      if (rem <= 0) continue;
      if (s.creditorHotelId != null && result.containsKey(s.creditorHotelId)) {
        result[s.creditorHotelId]!['receivable'] = result[s.creditorHotelId]!['receivable']! + rem;
      }
      if (s.debtorHotelId != null && result.containsKey(s.debtorHotelId)) {
        result[s.debtorHotelId]!['payable'] = result[s.debtorHotelId]!['payable']! + rem;
      }
    }
    return result;
  }

  /// أرصدة حالية لكل شخص/مورد (حسب نوع الحساب) — مفتاح كل عنصر "hotelId|name".
  Future<Map<String, Map<String, dynamic>>> getCounterpartyBalances(String type, Map<int, String> hotelNames) async {
    final result = <String, Map<String, dynamic>>{};
    final db = await _dbService.database;

    if (type == 'person') {
      final accounts = await db.rawQuery("SELECT * FROM financial_accounts WHERE category GLOB 'person_*'");
      for (final acc in accounts) {
        final hotelId = acc['hotel_id'] as int;
        final name = acc['name'] as String;
        final key = "$hotelId|$name";
        final balance = (acc['balance'] as num).toDouble();
        result[key] = {
          'hotelId': hotelId,
          'name': name,
          'receivable': balance > 0 ? balance : 0.0,
          'payable': balance < 0 ? -balance : 0.0,
          'lastDate': null,
          'opCount': 0,
        };
        final lastLedger = await db.query('financial_ledger', where: 'account_id = ?', whereArgs: [acc['id']], orderBy: 'date DESC, time DESC', limit: 1);
        final countResult = await db.rawQuery('SELECT COUNT(*) as c FROM financial_ledger WHERE account_id = ?', [acc['id']]);
        result[key]!['lastDate'] = lastLedger.isNotEmpty ? lastLedger.first['date'] : null;
        result[key]!['opCount'] = (countResult.first['c'] as int?) ?? 0;
      }
    }

    final accType = type; // 'person' or 'supplier'
    final settlementAccounts = await db.query('settlement_accounts', where: 'type = ?', whereArgs: [accType]);
    for (final sa in settlementAccounts) {
      final hotelId = sa['hotel_id'] as int? ?? 0;
      final name = sa['name'] as String;
      final key = "$hotelId|$name";
      final settlements = await _settlementRepo.getSettlements(accountId: sa['id'] as int);
      double receivable = (result[key]?['receivable'] as double?) ?? 0;
      double payable = (result[key]?['payable'] as double?) ?? 0;
      int opCount = (result[key]?['opCount'] as int?) ?? 0;
      String? lastDate = result[key]?['lastDate'] as String?;
      for (final s in settlements) {
        final rem = s.remainingAmount;
        if (s.direction == 'to_me') {
          receivable += rem;
        } else {
          payable += rem;
        }
        opCount++;
        final sDateStr = s.date.toIso8601String();
        if (lastDate == null || sDateStr.compareTo(lastDate) > 0) lastDate = sDateStr;
      }
      result[key] = {'hotelId': hotelId, 'name': name, 'receivable': receivable, 'payable': payable, 'lastDate': lastDate, 'opCount': opCount};
    }
    return result;
  }

  Future<List<RelationshipTxn>> getHotelToHotelTxns(Map<int, String> hotelNames) async {
    final txns = <RelationshipTxn>[];
    final db = await _dbService.database;

    final accounts = await db.rawQuery("SELECT * FROM financial_accounts WHERE category GLOB 'entity_*' OR category GLOB 'receivable_entity_*'");
    for (final acc in accounts) {
      final category = acc['category'] as String;
      final hotelId = acc['hotel_id'] as int;
      final isReceivableAccount = category.startsWith('receivable_entity_');
      final otherIdStr = isReceivableAccount ? category.substring('receivable_entity_'.length) : category.substring('entity_'.length);
      final otherId = int.tryParse(otherIdStr);
      if (otherId == null) continue;
      final hotelName = hotelNames[hotelId] ?? 'فندق #$hotelId';
      final otherName = hotelNames[otherId] ?? 'فندق #$otherId';

      final ledgerRows = await db.query('financial_ledger', where: 'account_id = ?', whereArgs: [acc['id']], orderBy: 'date DESC, time DESC');
      for (final l in ledgerRows) {
        final increased = l['type'] == 'debit';
        String payer, beneficiary;
        if (isReceivableAccount) {
          payer = increased ? hotelName : otherName;
          beneficiary = increased ? otherName : hotelName;
        } else {
          payer = increased ? otherName : hotelName;
          beneficiary = increased ? hotelName : otherName;
        }
        txns.add(RelationshipTxn(
          source: 'ledger',
          id: l['id'] as int,
          hotelId: hotelId,
          hotelName: hotelName,
          counterpartyType: 'hotel',
          counterpartyName: otherName,
          counterpartyHotelId: otherId,
          amount: (l['amount'] as num).toDouble(),
          isReceivable: isReceivableAccount,
          date: DateTime.tryParse("${l['date']} ${l['time']}".replaceFirst(' ', 'T')) ?? DateTime.tryParse(l['date'] as String) ?? DateTime.now(),
          description: l['description'] as String,
          operationType: _refTypeLabel(l['reference_type'] as String?),
          status: 'مُنفَّذة',
          reportId: l['reference_type'] == 'daily_report' ? l['reference_id'] as int? : null,
          payerName: payer,
          beneficiaryName: beneficiary,
        ));
      }
    }

    final settlements = await _settlementRepo.getSettlements(type: 'inter_entity');
    for (final s in settlements) {
      final creditorId = s.creditorHotelId;
      final debtorId = s.debtorHotelId;
      if (creditorId == null || debtorId == null) continue;
      final creditorName = hotelNames[creditorId] ?? 'فندق #$creditorId';
      final debtorName = hotelNames[debtorId] ?? 'فندق #$debtorId';

      txns.add(RelationshipTxn(
        source: 'settlement', id: s.id ?? 0, hotelId: debtorId, hotelName: debtorName,
        counterpartyType: 'hotel', counterpartyName: creditorName, counterpartyHotelId: creditorId,
        amount: s.amount, isReceivable: false, date: s.date, description: s.description,
        operationType: 'دين مسجَّل عبر التسويات', status: s.status == 'paid' ? 'مسدَّدة' : 'مفتوحة',
        attachments: s.attachments, payerName: debtorName, beneficiaryName: creditorName,
      ));
      txns.add(RelationshipTxn(
        source: 'settlement', id: s.id ?? 0, hotelId: creditorId, hotelName: creditorName,
        counterpartyType: 'hotel', counterpartyName: debtorName, counterpartyHotelId: debtorId,
        amount: s.amount, isReceivable: true, date: s.date, description: s.description,
        operationType: 'مستحق مسجَّل عبر التسويات', status: s.status == 'paid' ? 'مسدَّدة' : 'مفتوحة',
        attachments: s.attachments, payerName: debtorName, beneficiaryName: creditorName,
      ));

      if (s.id != null) {
        final payments = await _settlementRepo.getTransactions(s.id!);
        for (final p in payments) {
          txns.add(RelationshipTxn(
            source: 'settlement', id: p.id ?? 0, hotelId: debtorId, hotelName: debtorName,
            counterpartyType: 'hotel', counterpartyName: creditorName, counterpartyHotelId: creditorId,
            amount: p.amount, isReceivable: false, date: p.date, description: p.notes ?? 'سداد دفعة',
            operationType: 'سداد جزئي', status: 'مُنفَّذة', viaAccount: p.amountSource,
            payerName: debtorName, beneficiaryName: creditorName,
          ));
          txns.add(RelationshipTxn(
            source: 'settlement', id: p.id ?? 0, hotelId: creditorId, hotelName: creditorName,
            counterpartyType: 'hotel', counterpartyName: debtorName, counterpartyHotelId: debtorId,
            amount: p.amount, isReceivable: true, date: p.date, description: p.notes ?? 'استلام دفعة',
            operationType: 'سداد جزئي', status: 'مُنفَّذة', viaAccount: p.amountSource,
            payerName: debtorName, beneficiaryName: creditorName,
          ));
        }
      }
    }
    return txns;
  }

  Future<List<RelationshipTxn>> getPersonTxns(Map<int, String> hotelNames) async {
    final txns = <RelationshipTxn>[];
    final db = await _dbService.database;

    final accounts = await db.rawQuery("SELECT * FROM financial_accounts WHERE category GLOB 'person_*'");
    for (final acc in accounts) {
      final hotelId = acc['hotel_id'] as int;
      final personName = acc['name'] as String;
      final hotelName = hotelNames[hotelId] ?? 'فندق #$hotelId';
      final ledgerRows = await db.query('financial_ledger', where: 'account_id = ?', whereArgs: [acc['id']], orderBy: 'date DESC, time DESC');
      for (final l in ledgerRows) {
        final increased = l['type'] == 'debit';
        txns.add(RelationshipTxn(
          source: 'ledger', id: l['id'] as int, hotelId: hotelId, hotelName: hotelName,
          counterpartyType: 'person', counterpartyName: personName,
          amount: (l['amount'] as num).toDouble(), isReceivable: true,
          date: DateTime.tryParse(l['date'] as String) ?? DateTime.now(),
          description: l['description'] as String,
          operationType: _refTypeLabel(l['reference_type'] as String?), status: 'مُنفَّذة',
          reportId: l['reference_type'] == 'daily_report' ? l['reference_id'] as int? : null,
          payerName: increased ? hotelName : personName,
          beneficiaryName: increased ? personName : hotelName,
        ));
      }
    }

    final personAccounts = await db.query('settlement_accounts', where: "type = ?", whereArgs: ['person']);
    for (final pa in personAccounts) {
      final hotelId = pa['hotel_id'] as int? ?? 0;
      final name = pa['name'] as String;
      final accId = pa['id'] as int;
      final hotelName = hotelNames[hotelId] ?? 'فندق #$hotelId';
      final settlements = await _settlementRepo.getSettlements(accountId: accId);
      for (final s in settlements) {
        final isReceivable = s.direction == 'to_me';
        final debtPayer = isReceivable ? hotelName : name;
        final debtBeneficiary = isReceivable ? name : hotelName;
        txns.add(RelationshipTxn(
          source: 'settlement', id: s.id ?? 0, hotelId: hotelId, hotelName: hotelName,
          counterpartyType: 'person', counterpartyName: name, amount: s.amount, isReceivable: isReceivable,
          date: s.date, description: s.description, operationType: 'عملية شخصية مسجَّلة',
          status: s.status == 'paid' ? 'مسدَّدة' : 'مفتوحة', attachments: s.attachments,
          payerName: debtPayer, beneficiaryName: debtBeneficiary,
        ));
        if (s.id != null) {
          final payments = await _settlementRepo.getTransactions(s.id!);
          for (final p in payments) {
            txns.add(RelationshipTxn(
              source: 'settlement', id: p.id ?? 0, hotelId: hotelId, hotelName: hotelName,
              counterpartyType: 'person', counterpartyName: name, amount: p.amount, isReceivable: isReceivable,
              date: p.date, description: p.notes ?? 'سداد دفعة', operationType: 'سداد جزئي',
              status: 'مُنفَّذة', viaAccount: p.amountSource,
              payerName: debtBeneficiary, beneficiaryName: debtPayer,
            ));
          }
        }
      }
    }
    return txns;
  }

  Future<List<RelationshipTxn>> getSupplierTxns(Map<int, String> hotelNames) async {
    final txns = <RelationshipTxn>[];
    final db = await _dbService.database;

    final supplierAccounts = await db.query('settlement_accounts', where: "type = ?", whereArgs: ['supplier']);
    for (final sa in supplierAccounts) {
      final hotelId = sa['hotel_id'] as int? ?? 0;
      final name = sa['name'] as String;
      final accId = sa['id'] as int;
      final hotelName = hotelNames[hotelId] ?? 'فندق #$hotelId';
      final settlements = await _settlementRepo.getSettlements(accountId: accId);
      for (final s in settlements) {
        final isReceivable = s.direction == 'to_me';
        final debtPayer = isReceivable ? hotelName : name;
        final debtBeneficiary = isReceivable ? name : hotelName;
        txns.add(RelationshipTxn(
          source: 'settlement', id: s.id ?? 0, hotelId: hotelId, hotelName: hotelName,
          counterpartyType: 'supplier', counterpartyName: name, amount: s.amount, isReceivable: isReceivable,
          date: s.date, description: s.description, operationType: 'فاتورة/دين مورد',
          status: s.status == 'paid' ? 'مسدَّدة' : 'مفتوحة', attachments: s.attachments,
          payerName: debtPayer, beneficiaryName: debtBeneficiary,
        ));
        if (s.id != null) {
          final payments = await _settlementRepo.getTransactions(s.id!);
          for (final p in payments) {
            txns.add(RelationshipTxn(
              source: 'settlement', id: p.id ?? 0, hotelId: hotelId, hotelName: hotelName,
              counterpartyType: 'supplier', counterpartyName: name, amount: p.amount, isReceivable: isReceivable,
              date: p.date, description: p.notes ?? 'سداد دفعة', operationType: 'سداد جزئي',
              status: 'مُنفَّذة', viaAccount: p.amountSource,
              payerName: debtBeneficiary, beneficiaryName: debtPayer,
            ));
          }
        }
      }
    }
    return txns;
  }
}
