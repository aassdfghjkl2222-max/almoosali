import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_contract.dart';
import '../supabase_config.dart';

class SupaContractRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaContract>> getContracts({required String hotelId, bool includeArchived = false}) async {
    var query = _db.from('contracts').select().eq('hotel_id', hotelId);
    if (!includeArchived) query = query.filter('archived_at', 'is', null);
    final rows = await query.order('start_date', ascending: false);
    return (rows as List).map((m) => SupaContract.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaContract> addContract(SupaContract contract) async {
    final row = await _db.from('contracts').insert(contract.toInsertMap()).select().single();
    return SupaContract.fromMap(row);
  }

  Future<SupaContract> updateContract(SupaContract contract) async {
    if (contract.id == null) throw ArgumentError('updateContract requires an existing contract.id');
    final row = await _db.from('contracts').update(contract.toUpdateMap()).eq('id', contract.id!).select().single();
    return SupaContract.fromMap(row);
  }

  Future<void> archiveContract(String id) async {
    await _db.from('contracts').update({'archived_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<List<SupaContractPayment>> getPayments(String contractId) async {
    final rows = await _db.from('contract_payments').select().eq('contract_id', contractId).order('payment_date');
    return (rows as List).map((m) => SupaContractPayment.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaContractPayment> addPayment(SupaContractPayment payment) async {
    final row = await _db.from('contract_payments').insert(payment.toInsertMap()).select().single();
    return SupaContractPayment.fromMap(row);
  }

  Future<void> markPaymentPaid(String paymentId) async {
    await _db.from('contract_payments').update({'status': SupaContractPayment.statusPaid}).eq('id', paymentId);
  }
}
