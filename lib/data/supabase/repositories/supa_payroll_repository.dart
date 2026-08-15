import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_payroll.dart';
import '../supabase_config.dart';

/// إنشاء سجل الراتب يمرّ حصراً عبر create_payroll_record (RPC) — يُعيد حساب
/// advances_total من صفوف employee_advances الحقيقية غير المسدَّدة بدل
/// الثقة بقيمة يُرسِلها العميل، ويُسوّي تلك السلف ذرّياً مع إنشاء السجل.
/// raja تعليق supabase/migrations/20260730000005_phase4_rpcs.sql.
class SupaPayrollRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaPayrollRecord>> getPayrollRecords({required String hotelId, String? period}) async {
    var query = _db.from('payroll_records').select().eq('hotel_id', hotelId);
    if (period != null) query = query.eq('period', period);
    final rows = await query.order('period', ascending: false);
    return (rows as List).map((m) => SupaPayrollRecord.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<String> createPayrollRecord({
    required String hotelId,
    required String employeeId,
    required String period,
    required double baseSalary,
    required double proratedBase,
    double allowancesTotal = 0,
    double deductionsTotal = 0,
    String? paymentSource,
    double cashAmount = 0,
    double bankAmount = 0,
    double personalAmount = 0,
    String? periodStart,
    String? periodEnd,
    int daysWorked = 0,
    int totalDaysInPeriod = 30,
    List<String> settleAdvanceIds = const [],
  }) async {
    final id = await _db.rpc('create_payroll_record', params: {
      'p_hotel_id': hotelId,
      'p_employee_id': employeeId,
      'p_period': period,
      'p_base_salary': baseSalary,
      'p_prorated_base': proratedBase,
      'p_allowances_total': allowancesTotal,
      'p_deductions_total': deductionsTotal,
      'p_payment_source': paymentSource,
      'p_cash_amount': cashAmount,
      'p_bank_amount': bankAmount,
      'p_personal_amount': personalAmount,
      'p_period_start': periodStart,
      'p_period_end': periodEnd,
      'p_days_worked': daysWorked,
      'p_total_days_in_period': totalDaysInPeriod,
      'p_settle_advance_ids': settleAdvanceIds,
    }) as String;
    return id;
  }

  Future<void> markPaid(String payrollId) async {
    await _db.rpc('mark_payroll_paid', params: {'target_payroll_id': payrollId});
  }

  Future<List<SupaEmployeeAllowance>> getAllowances(String employeeId) async {
    final rows = await _db.from('employee_allowances').select().eq('employee_id', employeeId);
    return (rows as List).map((m) => SupaEmployeeAllowance.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaEmployeeAllowance> addAllowance(SupaEmployeeAllowance allowance) async {
    final row = await _db.from('employee_allowances').insert(allowance.toInsertMap()).select().single();
    return SupaEmployeeAllowance.fromMap(row);
  }

  Future<List<SupaEmployeeDeduction>> getDeductions(String employeeId) async {
    final rows = await _db.from('employee_deductions').select().eq('employee_id', employeeId);
    return (rows as List).map((m) => SupaEmployeeDeduction.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaEmployeeDeduction> addDeduction(SupaEmployeeDeduction deduction) async {
    final row = await _db.from('employee_deductions').insert(deduction.toInsertMap()).select().single();
    return SupaEmployeeDeduction.fromMap(row);
  }

  Future<List<SupaEmployeeAdvance>> getAdvances({required String employeeId, bool? isSettled}) async {
    var query = _db.from('employee_advances').select().eq('employee_id', employeeId);
    if (isSettled != null) query = query.eq('is_settled', isSettled);
    final rows = await query.order('advance_date', ascending: false);
    return (rows as List).map((m) => SupaEmployeeAdvance.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaEmployeeAdvance> addAdvance(SupaEmployeeAdvance advance) async {
    final row = await _db.from('employee_advances').insert(advance.toInsertMap()).select().single();
    return SupaEmployeeAdvance.fromMap(row);
  }
}
