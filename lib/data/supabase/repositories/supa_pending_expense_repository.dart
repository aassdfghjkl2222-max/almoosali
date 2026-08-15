import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_pending_expense.dart';
import '../supabase_config.dart';

/// المصروفات المعلَّقة. الترحيل الفعلي إلى تقرير (تعليم is_transferred،
/// وإلغاؤه إن أُزيل البند لاحقاً) لا يمرّ من هنا — يحدث ذرّياً داخل
/// save_daily_financial_report عبر SupaFinancialReportRepository عند تمرير
/// pending_expense_id ضمن بند مصروف، راجع تعليق
/// supabase/migrations/20260730000003_phase3_rpcs.sql.
class SupaPendingExpenseRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaPendingExpense>> getPendingExpenses({required String hotelId, bool? isTransferred}) async {
    var query = _db.from('pending_expenses').select().eq('hotel_id', hotelId).filter('archived_at', 'is', null);
    if (isTransferred != null) query = query.eq('is_transferred', isTransferred);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((m) => SupaPendingExpense.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaPendingExpense> addPendingExpense(SupaPendingExpense expense) async {
    final row = await _db.from('pending_expenses').insert(expense.toInsertMap()).select().single();
    return SupaPendingExpense.fromMap(row);
  }

  Future<SupaPendingExpense> updatePendingExpense(SupaPendingExpense expense) async {
    if (expense.id == null) throw ArgumentError('updatePendingExpense requires an existing expense.id');
    final row = await _db.from('pending_expenses').update(expense.toUpdateMap()).eq('id', expense.id!).select().single();
    return SupaPendingExpense.fromMap(row);
  }

  Future<void> deletePendingExpense(String id) async {
    await _db.from('pending_expenses').delete().eq('id', id);
  }
}
