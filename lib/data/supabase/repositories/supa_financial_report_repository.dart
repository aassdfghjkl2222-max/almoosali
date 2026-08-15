import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_financial_report.dart';
import '../supabase_config.dart';

/// التقارير المالية اليومية — نسخة Supabase. الحفظ الكامل (تقرير + بنود +
/// تفصيل الإيراد الثابت) والترحيل يمرّان عبر دالتَي RPC ذريَّتين
/// (save_daily_financial_report, post_financial_report) بدل عدة نداءات
/// عميل منفصلة — راجع تعليق
/// supabase/migrations/20260730000001_phase2_reports_and_category_rpcs.sql
/// لسبب ذلك: حفظ بعدة نداءات مستقلة غير ذرّي (قد ينقطع الاتصال في المنتصف
/// ويترك تقريراً بلا كل بنوده). القراءات المفردة (بند واحد إضافي لاحقاً،
/// عرض تقرير محفوظ) تبقى نداءات مباشرة عادية.
class SupaFinancialReportRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<SupaFinancialReport?> getReportForDate({
    required String hotelId,
    required String date,
    String reportType = SupaFinancialReport.typeMain,
  }) async {
    final row = await _db
        .from('financial_reports')
        .select()
        .eq('hotel_id', hotelId)
        .eq('report_date', date)
        .eq('report_type', reportType)
        .maybeSingle();
    return row == null ? null : SupaFinancialReport.fromMap(row);
  }

  Future<List<SupaFinancialReport>> getReportsInRange({
    required String hotelId,
    required String startDate,
    required String endDate,
  }) async {
    final rows = await _db
        .from('financial_reports')
        .select()
        .eq('hotel_id', hotelId)
        .gte('report_date', startDate)
        .lte('report_date', endDate)
        .order('report_date', ascending: false);
    return (rows as List).map((m) => SupaFinancialReport.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<SupaFinancialReportRevenueLine>> getRevenueLines(String reportId) async {
    final rows = await _db.from('financial_report_revenue_lines').select().eq('report_id', reportId);
    return (rows as List).map((m) => SupaFinancialReportRevenueLine.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<SupaFinancialReportExpenseLine>> getExpenseLines(String reportId) async {
    final rows = await _db.from('financial_report_expense_lines').select().eq('report_id', reportId);
    return (rows as List).map((m) => SupaFinancialReportExpenseLine.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaFinancialReportIncomeBreakdown?> getIncomeBreakdown(String reportId) async {
    final row = await _db.from('financial_report_income_breakdown').select().eq('report_id', reportId).maybeSingle();
    return row == null ? null : SupaFinancialReportIncomeBreakdown.fromMap(row);
  }

  /// يحمِّل التقرير كاملاً (رأس + بنود + تفصيل الإيراد) في نداء واحد منطقي —
  /// يُستخدَم لبناء [SupaDailyReportDraft] عند فتح شاشة تقرير محفوظ مسبقاً.
  Future<SupaDailyReportDraft?> loadFullReport({
    required String hotelId,
    required String date,
    String reportType = SupaFinancialReport.typeMain,
  }) async {
    final report = await getReportForDate(hotelId: hotelId, date: date, reportType: reportType);
    if (report == null) return null;
    final results = await Future.wait([
      getRevenueLines(report.id!),
      getExpenseLines(report.id!),
      getIncomeBreakdown(report.id!),
    ]);
    return SupaDailyReportDraft(
      report: report,
      revenueLines: results[0] as List<SupaFinancialReportRevenueLine>,
      expenseLines: results[1] as List<SupaFinancialReportExpenseLine>,
      incomeBreakdown: results[2] as SupaFinancialReportIncomeBreakdown? ??
          SupaFinancialReportIncomeBreakdown(reportId: report.id!),
    );
  }

  /// يحفظ التقرير كاملاً (رأس + تفصيل الإيراد + كل البنود) دفعة واحدة، ذرّياً،
  /// عبر save_daily_financial_report — يُنشئ التقرير إن لم يوجد بعد لنفس
  /// (hotel_id, report_date, report_type)، أو يُحدِّثه إن وُجد (upsert)،
  /// ويستبدل كل بنوده بالمجموعة الممرَّرة هنا بالضبط (وليس دمجاً/فرقاً).
  /// يرمي استثناء Postgrest إن كان التقرير مُرحَّلاً (is_posted) بالفعل.
  Future<String> saveWholeReport({
    required String hotelId,
    required String date,
    String reportType = SupaFinancialReport.typeMain,
    String? notes,
    double increaseAmount = 0,
    String? increaseDescription,
    String? increaseFundingSource,
    double shortageAmount = 0,
    String? shortageDescription,
    String? shortageFundingSource,
    required SupaFinancialReportIncomeBreakdown incomeBreakdown,
    List<SupaFinancialReportRevenueLine> revenueLines = const [],
    List<SupaFinancialReportExpenseLine> expenseLines = const [],
  }) async {
    final reportId = await _db.rpc('save_daily_financial_report', params: {
      'p_hotel_id': hotelId,
      'p_report_date': date,
      'p_report_type': reportType,
      'p_notes': notes,
      'p_increase_amount': increaseAmount,
      'p_increase_description': increaseDescription,
      'p_increase_funding_source': increaseFundingSource,
      'p_shortage_amount': shortageAmount,
      'p_shortage_description': shortageDescription,
      'p_shortage_funding_source': shortageFundingSource,
      'p_room_cash': incomeBreakdown.roomCash,
      'p_room_pos': incomeBreakdown.roomPos,
      'p_room_bank_transfer': incomeBreakdown.roomBankTransfer,
      'p_parking_cash': incomeBreakdown.parkingCash,
      'p_parking_pos': incomeBreakdown.parkingPos,
      'p_revenue_lines': revenueLines.map((l) => l.toRpcJson()).toList(),
      'p_expense_lines': expenseLines.map((l) => l.toRpcJson()).toList(),
    }) as String;
    return reportId;
  }

  /// ترحيل/تثبيت التقرير — بعدها يصبح كل شيء (الرأس والبنود) غير قابل
  /// للتعديل على مستوى قاعدة البيانات نفسها (راجع المُشغِّلات في migration
  /// Phase 2)، لا واجهة التطبيق فقط.
  Future<void> postReport(String reportId) async {
    await _db.rpc('post_financial_report', params: {'target_report_id': reportId});
  }

  /// حذف تقرير مسودة (غير مُرحَّل) بالكامل — سياسة RLS ترفض حذف تقرير مُرحَّل.
  Future<void> deleteDraftReport(String reportId) async {
    await _db.from('financial_reports').delete().eq('id', reportId);
  }
}
