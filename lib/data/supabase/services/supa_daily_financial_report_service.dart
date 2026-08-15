import '../models/supa_financial_report.dart';
import '../repositories/supa_financial_category_repository.dart';
import '../repositories/supa_financial_report_repository.dart';

/// طبقة تنسيق فوق SupaFinancialReportRepository — الفرق عن استدعاء
/// المستودع مباشرة: بعد أي حفظ ناجح، يُسجَّل استخدام كل فئة ظهرت في بنود
/// التقرير (نفس ما يفعله مُنتقي الفئة الموحَّد عند الاختيار اليدوي، راجع
/// FinancialCategoryTile/showFinancialCategoryPicker في النسخة المحلية) —
/// هذا تنسيق بين مستودعين لا ينتمي إلى أيٍّ منهما بمفرده، فوُضع هنا بدل أن
/// يتكرر في كل شاشة تستدعي الحفظ مستقبلاً. تسجيل الاستخدام "أفضل جهد" فقط:
/// فشله لا يُسقِط عملية الحفظ نفسها (نجحت البيانات المالية فعلياً بالفعل).
class SupaDailyFinancialReportService {
  final SupaFinancialReportRepository _reportRepository;
  final SupaFinancialCategoryRepository _categoryRepository;

  SupaDailyFinancialReportService({
    SupaFinancialReportRepository? reportRepository,
    SupaFinancialCategoryRepository? categoryRepository,
  })  : _reportRepository = reportRepository ?? SupaFinancialReportRepository(),
        _categoryRepository = categoryRepository ?? SupaFinancialCategoryRepository();

  /// يحمِّل تقريراً محفوظاً، أو يُنشئ مسودة فارغة جاهزة للتحرير إن لم يوجد
  /// بعد لهذا (hotel_id, date) — الفرق عن استدعاء repository.loadFullReport
  /// مباشرة: تلك تُعيد null، وشاشة "تقرير جديد" تحتاج كائناً قابلاً للتحرير
  /// فوراً لا قيمة فارغة.
  Future<SupaDailyReportDraft> loadOrCreateDraft({
    required String hotelId,
    required String date,
    String reportType = SupaFinancialReport.typeMain,
  }) async {
    final existing = await _reportRepository.loadFullReport(hotelId: hotelId, date: date, reportType: reportType);
    if (existing != null) return existing;
    return SupaDailyReportDraft(
      report: SupaFinancialReport(hotelId: hotelId, reportDate: date, reportType: reportType),
      incomeBreakdown: const SupaFinancialReportIncomeBreakdown(reportId: ''),
    );
  }

  Future<String> saveDraft(SupaDailyReportDraft draft) async {
    final reportId = await _reportRepository.saveWholeReport(
      hotelId: draft.report.hotelId,
      date: draft.report.reportDate,
      reportType: draft.report.reportType,
      notes: draft.report.notes,
      increaseAmount: draft.report.increaseAmount,
      increaseDescription: draft.report.increaseDescription,
      increaseFundingSource: draft.report.increaseFundingSource,
      shortageAmount: draft.report.shortageAmount,
      shortageDescription: draft.report.shortageDescription,
      shortageFundingSource: draft.report.shortageFundingSource,
      incomeBreakdown: draft.incomeBreakdown,
      revenueLines: draft.revenueLines,
      expenseLines: draft.expenseLines,
    );

    final usedCategoryIds = <String>{
      ...draft.revenueLines.map((l) => l.categoryId),
      ...draft.expenseLines.map((l) => l.categoryId),
    };
    for (final categoryId in usedCategoryIds) {
      try {
        await _categoryRepository.recordUsage(categoryId);
      } catch (_) {
        // أفضل جهد فقط — لا يُسقِط نجاح حفظ التقرير نفسه.
      }
    }

    return reportId;
  }

  Future<void> postReport(String reportId) => _reportRepository.postReport(reportId);
}
