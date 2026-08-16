import '../core/database/database_service.dart';
import '../models/settlement.dart';
import '../models/settlement_account.dart';
import '../models/settlement_transaction.dart';
import 'trash_repository.dart';

class SettlementRepository {
  final DatabaseService _dbService = DatabaseService();
  final _trashRepository = TrashRepository();

  // Accounts
  Future<int> addAccount(SettlementAccount account) async {
    return await _dbService.insertSettlementAccount(account.toMap());
  }

  Future<List<SettlementAccount>> getAccounts(int? hotelId, {String? type}) async {
    if (hotelId == null) return [];
    final List<Map<String, dynamic>> maps = await _dbService.getSettlementAccounts(hotelId: hotelId, type: type);
    return maps.map((map) => SettlementAccount.fromMap(map)).toList();
  }

  Future<SettlementAccount?> getAccountByName(int? hotelId, String name, String type) async {
    if (hotelId == null) return null;
    final map = await _dbService.getSettlementAccountByName(hotelId, name, type);
    if (map == null) return null;
    return SettlementAccount.fromMap(map);
  }

  // Settlements
  Future<int> addSettlement(Settlement settlement) async {
    return await _dbService.insertSettlement(settlement.toMap());
  }

  Future<List<Settlement>> getSettlements({
    String? type,
    int? accountId,
    int? creditorHotelId,
    int? debtorHotelId,
    int? hotelId,
  }) async {
    final List<Map<String, dynamic>> maps = await _dbService.getSettlements(
      type: type,
      accountId: accountId,
      creditorHotelId: creditorHotelId,
      debtorHotelId: debtorHotelId,
      hotelId: hotelId,
    );
    return maps.map((map) => Settlement.fromMap(map)).toList();
  }

  Future<int> updateSettlement(Settlement settlement) async {
    if (settlement.id == null) return 0;
    return await _dbService.updateById('settlements', settlement.toMap(), settlement.id!);
  }

  /// نقل ناعم إلى سلة المهملات — راجع TrashRepository.
  Future<void> deleteSettlement(Settlement settlement) async {
    await _trashRepository.trash('settlement', settlement.id!, settlement.description);
  }

  // Transactions (Payments)
  Future<int> addTransaction(SettlementTransaction transaction) async {
    return await _dbService.insertSettlementTransaction(transaction.toMap());
  }

  Future<List<SettlementTransaction>> getTransactions(int settlementId) async {
    final List<Map<String, dynamic>> maps = await _dbService.getSettlementTransactions(settlementId);
    return maps.map((map) => SettlementTransaction.fromMap(map)).toList();
  }

  Future<int> deleteTransaction(int id, int settlementId) async {
    return await _dbService.deleteSettlementTransaction(id, settlementId);
  }

  // Summaries
  Future<Map<String, dynamic>> getOverallSummary(int? hotelId, String type) async {
    if (hotelId == null) return {'totalDueToMe': 0, 'totalIOwe': 0, 'accountCount': 0};
    final settlements = await getSettlements(type: type, hotelId: hotelId);
    double totalDueToMe = 0;
    double totalIOwe = 0;
    
    for (var s in settlements) {
      final remaining = s.remainingAmount;
      if (s.direction == 'to_me') {
        totalDueToMe += remaining;
      } else {
        totalIOwe += remaining;
      }
    }
    
    final accounts = await getAccounts(hotelId, type: type);
    return {
      'totalDueToMe': totalDueToMe,
      'totalIOwe': totalIOwe,
      'accountCount': accounts.length,
    };
  }

  Future<Map<String, dynamic>> getAccountSummary(int? hotelId, int accountId) async {
    if (hotelId == null) return {'totalDueToMe': 0, 'totalIOwe': 0, 'opCount': 0, 'remaining': 0};
    final settlements = await getSettlements(accountId: accountId, hotelId: hotelId);
    double totalDueToMe = 0;
    double totalIOwe = 0;
    int opCount = settlements.length;
    
    for (var s in settlements) {
      final remaining = s.remainingAmount;
      if (s.direction == 'to_me') {
        totalDueToMe += remaining;
      } else {
        totalIOwe += remaining;
      }
    }
    
    return {
      'totalDueToMe': totalDueToMe,
      'totalIOwe': totalIOwe,
      'opCount': opCount,
      'remaining': totalDueToMe - totalIOwe,
    };
  }
}
