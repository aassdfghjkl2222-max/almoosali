import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_invoice.dart';
import '../models/supa_supplier.dart';
import '../supabase_config.dart';

class SupaSupplierRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaSupplier>> getSuppliers({required String hotelId, bool includeArchived = false}) async {
    var query = _db.from('suppliers').select().eq('hotel_id', hotelId);
    if (!includeArchived) query = query.filter('archived_at', 'is', null);
    final rows = await query.order('official_name');
    return (rows as List).map((m) => SupaSupplier.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<SupaSupplier>> searchSuppliers({required String hotelId, required String query}) async {
    final rows = await _db
        .from('suppliers')
        .select()
        .eq('hotel_id', hotelId)
        .filter('archived_at', 'is', null)
        .or('official_name.ilike.%$query%,short_name.ilike.%$query%')
        .order('official_name');
    return (rows as List).map((m) => SupaSupplier.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaSupplier?> getSupplierByTaxNumber({required String hotelId, required String taxNumber}) async {
    final row = await _db.from('suppliers').select().eq('hotel_id', hotelId).eq('tax_number', taxNumber).maybeSingle();
    return row == null ? null : SupaSupplier.fromMap(row);
  }

  Future<SupaSupplier> addSupplier(SupaSupplier supplier) async {
    final row = await _db.from('suppliers').insert(supplier.toInsertMap()).select().single();
    return SupaSupplier.fromMap(row);
  }

  Future<SupaSupplier> updateSupplier(SupaSupplier supplier) async {
    if (supplier.id == null) throw ArgumentError('updateSupplier requires an existing supplier.id');
    final row = await _db.from('suppliers').update(supplier.toUpdateMap()).eq('id', supplier.id!).select().single();
    return SupaSupplier.fromMap(row);
  }

  Future<void> archiveSupplier(String id) async {
    await _db.from('suppliers').update({'archived_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restoreSupplier(String id) async {
    await _db.from('suppliers').update({'archived_at': null}).eq('id', id);
  }

  Future<List<SupaSupplierDebt>> getDebts({required String hotelId, String? status}) async {
    var query = _db.from('supplier_debts').select().eq('hotel_id', hotelId);
    if (status != null) query = query.eq('status', status);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((m) => SupaSupplierDebt.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaSupplierPayment> addPayment(SupaSupplierPayment payment) async {
    final row = await _db.from('supplier_payments').insert(payment.toInsertMap()).select().single();
    return SupaSupplierPayment.fromMap(row);
  }
}
