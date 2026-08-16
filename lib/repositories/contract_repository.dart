import '../core/database/database_service.dart';
import '../models/contract.dart';
import '../models/contract_payment.dart';
import 'trash_repository.dart';

class ContractRepository {
  final _dbService = DatabaseService();
  final _trashRepository = TrashRepository();

  Future<List<Contract>> getAllContracts(int hotelId) async {
    final data = await _dbService.getContracts(hotelId);
    return data.map((map) => Contract.fromMap(map)).toList();
  }

  /// عبر كل الفنادق معاً — راجع تعليق DatabaseService.getAllContractsAcrossHotels
  /// (البحث الشامل GlobalSearch فقط).
  Future<List<Contract>> getAllContractsAcrossHotels() async {
    final data = await _dbService.getAllContractsAcrossHotels();
    return data.map((map) => Contract.fromMap(map)).toList();
  }

  Future<Contract?> getContractById(int id) async {
    final db = await _dbService.database;
    final results = await db.query('contracts', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Contract.fromMap(results.first);
  }

  Future<int> addContract(Contract contract) async {
    return await _dbService.insertContract(contract.toMap());
  }

  Future<int> updateContract(Contract contract) async {
    if (contract.id == null) return 0;
    return await _dbService.updateById('contracts', contract.toMap(), contract.id!);
  }

  /// نقل ناعم إلى سلة المهملات — راجع TrashRepository. لا حذف فعلي هنا إطلاقاً
  /// (دفعات هذا العقد تبقى مرتبطة به كما هي، تظهر معه مجدداً عند الاستعادة).
  Future<void> deleteContract(Contract contract) async {
    await _trashRepository.trash('contract', contract.id!, contract.name);
  }

  Future<List<ContractPayment>> getContractPayments(int contractId) async {
    final data = await _dbService.getContractPayments(contractId);
    return data.map((map) => ContractPayment.fromMap(map)).toList();
  }

  Future<int> addPayment(ContractPayment payment) async {
    return await _dbService.insertContractPayment(payment.toMap());
  }

  Future<int> updatePayment(ContractPayment payment) async {
    if (payment.id == null) return 0;
    return await _dbService.updateById('contract_payments', payment.toMap(), payment.id!);
  }

  /// نقل ناعم إلى سلة المهملات — راجع TrashRepository.
  Future<void> deletePayment(ContractPayment payment) async {
    await _trashRepository.trash('contract_payment', payment.id!, 'دفعة عقد بمبلغ ${payment.amount}');
  }

  Future<void> saveContractWithPayments(Contract contract, List<ContractPayment> payments) async {
    await _dbService.insertContractWithPayments(
      contract.toMap(),
      payments.map((p) => p.toMap()).toList(),
    );
  }
}
