import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_shared_expense.dart';
import '../supabase_config.dart';

/// توزيع المصروف المشترك. الإنشاء يمرّ حصراً عبر create_shared_expense_distribution
/// (RPC، security definer) — إنشاء مجموعة + تخصيصاتها + مصروف معلَّق حقيقي
/// على كل فندق مخصَّص له معاً وذرّياً، راجع تعليق
/// supabase/migrations/20260730000003_phase3_rpcs.sql لسبب الحاجة لصلاحية
/// مرتفعة هنا تحديداً (يكتب على فنادق غير الفندق المموِّل، بسلطة الفندق
/// المموِّل فقط — تماماً كما يعمل التوزيع الحقيقي في الواقع).
class SupaSharedExpenseRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaSharedExpenseGroup>> getGroupsVisibleToMe() async {
    final rows = await _db.from('shared_expense_groups').select().order('expense_date', ascending: false);
    return (rows as List).map((m) => SupaSharedExpenseGroup.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<SupaSharedExpenseAllocation>> getAllocations(String groupId) async {
    final rows = await _db.from('shared_expense_allocations').select().eq('shared_expense_group_id', groupId);
    return (rows as List).map((m) => SupaSharedExpenseAllocation.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<String> createDistribution({
    required String categoryId,
    String? description,
    required String paymentMethod,
    required String fundingHotelId,
    required String expenseDate,
    required List<SupaSharedExpenseAllocation> allocations,
  }) async {
    final groupId = await _db.rpc('create_shared_expense_distribution', params: {
      'p_category_id': categoryId,
      'p_description': description,
      'p_payment_method': paymentMethod,
      'p_funding_hotel_id': fundingHotelId,
      'p_expense_date': expenseDate,
      'p_allocations': allocations.map((a) => a.toRpcJson()).toList(),
    }) as String;
    return groupId;
  }
}
