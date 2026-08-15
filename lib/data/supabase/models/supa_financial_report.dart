/// النماذج المطابقة لجداول التقرير المالي اليومي في Supabase — راجع
/// supabase/migrations/20260728000002_phase2_financial_core.sql. لا مقابل
/// لـ details_json (النمط القديم في SQLite): كل بند هنا صف حقيقي في جدول
/// مستقل (Section 5 من وثيقة التصميم).
library;

class SupaFinancialReport {
  static const typeMain = 'main';
  static const typeAdjustment = 'adjustment';

  final String? id;
  final String hotelId;
  final String reportDate; // 'YYYY-MM-DD'
  final String reportType;
  final double incomeTotal;   // للعرض فقط — تُحسَب دائماً بواسطة المُشغِّل recalc_report_totals في قاعدة البيانات
  final double expenseTotal;  // نفس الشيء
  final String? notes;
  final double increaseAmount;
  final String? increaseDescription;
  final String? increaseFundingSource;
  final double shortageAmount;
  final String? shortageDescription;
  final String? shortageFundingSource;
  final bool isPosted;
  final bool isLocked;
  final String? postedAt;
  final String? postedBy;
  final String? createdAt;
  final String? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const SupaFinancialReport({
    this.id,
    required this.hotelId,
    required this.reportDate,
    this.reportType = typeMain,
    this.incomeTotal = 0,
    this.expenseTotal = 0,
    this.notes,
    this.increaseAmount = 0,
    this.increaseDescription,
    this.increaseFundingSource,
    this.shortageAmount = 0,
    this.shortageDescription,
    this.shortageFundingSource,
    this.isPosted = false,
    this.isLocked = false,
    this.postedAt,
    this.postedBy,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  double get netProfit => incomeTotal - expenseTotal;

  factory SupaFinancialReport.fromMap(Map<String, dynamic> map) {
    return SupaFinancialReport(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      reportDate: map['report_date'] as String,
      reportType: map['report_type'] as String? ?? typeMain,
      incomeTotal: (map['income_total'] as num?)?.toDouble() ?? 0,
      expenseTotal: (map['expense_total'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      increaseAmount: (map['increase_amount'] as num?)?.toDouble() ?? 0,
      increaseDescription: map['increase_description'] as String?,
      increaseFundingSource: map['increase_funding_source'] as String?,
      shortageAmount: (map['shortage_amount'] as num?)?.toDouble() ?? 0,
      shortageDescription: map['shortage_description'] as String?,
      shortageFundingSource: map['shortage_funding_source'] as String?,
      isPosted: map['is_posted'] as bool? ?? false,
      isLocked: map['is_locked'] as bool? ?? false,
      postedAt: map['posted_at'] as String?,
      postedBy: map['posted_by'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      createdBy: map['created_by'] as String?,
      updatedBy: map['updated_by'] as String?,
    );
  }
}

class SupaFinancialReportRevenueLine {
  final String? id;
  final String reportId;
  final String categoryId;
  final double amount;
  final String paymentMethod; // 'cash' | 'pos' | 'bank_transfer'
  final String? notes;
  final String? createdAt;
  final String? createdBy;

  const SupaFinancialReportRevenueLine({
    this.id,
    required this.reportId,
    required this.categoryId,
    required this.amount,
    required this.paymentMethod,
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  /// الصياغة التي يتوقعها save_daily_financial_report (RPC) داخل
  /// p_revenue_lines — راجع SupaFinancialReportRepository.saveWholeReport.
  Map<String, dynamic> toRpcJson() => {
        'category_id': categoryId,
        'amount': amount,
        'payment_method': paymentMethod,
        if (notes != null) 'notes': notes,
      };

  factory SupaFinancialReportRevenueLine.fromMap(Map<String, dynamic> map) {
    return SupaFinancialReportRevenueLine(
      id: map['id'] as String?,
      reportId: map['report_id'] as String,
      categoryId: map['category_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      createdBy: map['created_by'] as String?,
    );
  }
}

class SupaFinancialReportExpenseLine {
  final String? id;
  final String reportId;
  final String categoryId;
  final double amount;
  final String paymentMethod;
  final String? fundingSourceHotelId;

  /// غير null فقط للبنود التي أصلها مصروف معلَّق حقيقي مُرحَّل داخل هذا
  /// التقرير — راجع Phase 3 (save_daily_financial_report يُعلِّم/يُلغي تعليم
  /// pending_expenses.is_transferred تلقائياً بناءً على هذا الحقل).
  final String? pendingExpenseId;
  final String? supplierId;
  final String? notes;
  final String? createdAt;
  final String? createdBy;

  const SupaFinancialReportExpenseLine({
    this.id,
    required this.reportId,
    required this.categoryId,
    required this.amount,
    required this.paymentMethod,
    this.fundingSourceHotelId,
    this.pendingExpenseId,
    this.supplierId,
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  Map<String, dynamic> toRpcJson() => {
        'category_id': categoryId,
        'amount': amount,
        'payment_method': paymentMethod,
        if (fundingSourceHotelId != null) 'funding_source_hotel_id': fundingSourceHotelId,
        if (pendingExpenseId != null) 'pending_expense_id': pendingExpenseId,
        if (supplierId != null) 'supplier_id': supplierId,
        if (notes != null) 'notes': notes,
      };

  factory SupaFinancialReportExpenseLine.fromMap(Map<String, dynamic> map) {
    return SupaFinancialReportExpenseLine(
      id: map['id'] as String?,
      reportId: map['report_id'] as String,
      categoryId: map['category_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      fundingSourceHotelId: map['funding_source_hotel_id'] as String?,
      pendingExpenseId: map['pending_expense_id'] as String?,
      supplierId: map['supplier_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      createdBy: map['created_by'] as String?,
    );
  }
}

class SupaFinancialReportIncomeBreakdown {
  final String reportId;
  final double roomCash;
  final double roomPos;
  final double roomBankTransfer;
  final double parkingCash;
  final double parkingPos;

  const SupaFinancialReportIncomeBreakdown({
    required this.reportId,
    this.roomCash = 0,
    this.roomPos = 0,
    this.roomBankTransfer = 0,
    this.parkingCash = 0,
    this.parkingPos = 0,
  });

  double get total => roomCash + roomPos + roomBankTransfer + parkingCash + parkingPos;

  factory SupaFinancialReportIncomeBreakdown.fromMap(Map<String, dynamic> map) {
    return SupaFinancialReportIncomeBreakdown(
      reportId: map['report_id'] as String,
      roomCash: (map['room_cash'] as num?)?.toDouble() ?? 0,
      roomPos: (map['room_pos'] as num?)?.toDouble() ?? 0,
      roomBankTransfer: (map['room_bank_transfer'] as num?)?.toDouble() ?? 0,
      parkingCash: (map['parking_cash'] as num?)?.toDouble() ?? 0,
      parkingPos: (map['parking_pos'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// تجميعة قابلة للتحرير في الواجهة — تقرير + بنوده + تفصيل الإيراد الثابت
/// معاً، تماماً كما تُبنى شاشة التقرير اليومي الحالية (financial_summary_page.dart)
/// من عدة قوائم منفصلة قبل الحفظ دفعة واحدة.
class SupaDailyReportDraft {
  final SupaFinancialReport report;
  final List<SupaFinancialReportRevenueLine> revenueLines;
  final List<SupaFinancialReportExpenseLine> expenseLines;
  final SupaFinancialReportIncomeBreakdown incomeBreakdown;

  const SupaDailyReportDraft({
    required this.report,
    this.revenueLines = const [],
    this.expenseLines = const [],
    required this.incomeBreakdown,
  });
}
