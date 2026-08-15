/// بند واحد داخل أي قسم من التقرير (اسم + مبلغ) — بنود القيمة صفر تُستبعَد
/// دوماً قبل بناء القالب (راجع buildDailyReportTemplate)، وليس عند العرض.
class ReportTemplateLine {
  final String label;
  final double amount;
  const ReportTemplateLine({required this.label, required this.amount});
}

/// بند واحد داخل "مصروفات خارج إيراد اليوم" — مصروف فعلي لم يُدفع من نقد
/// إيراد اليوم (راجع classifyExpenseFunding في daily_report_builder.dart،
/// المصدر الوحيد لهذا التصنيف). [icon] أيقونة نوع المصروف نفسه (🔧 صيانة،
/// 🍽️ إعاشة، ...) — لا علاقة لها بمصدر التمويل. [itemName] نوع/فئة المصروف.
/// [label] مصدر التمويل (المالك، الخزنة، اسم فندق آخر، دين - مورد، ...).
/// [methodLabel] طريقة الدفع (نقد/بنك) — null عندما لا تُعرض (تمويل المالك
/// دائماً بلا طريقة دفع؛ "شبكة" هي نفسها الطريقة فلا حاجة لتكرارها).
class UnwithdrawnTemplateLine {
  final String icon;
  final String itemName;
  final String label;
  final String? methodLabel;
  final double amount;
  const UnwithdrawnTemplateLine({required this.icon, required this.itemName, required this.label, this.methodLabel, this.amount = 0});
}

/// بند سحب مالك واحد — عرض معلوماتي بحت (القيد المحاسبي نُفِّذ فوراً عند
/// تسجيل السحب نفسه، أو عند ترحيل مصروف معلّق قديم بمصدر
/// [PendingExpense.paymentMethodOwnerDrawing] — راجع تعليق classifyExpenseFunding).
/// لا يدخل ضمن أي مجموع بهذا التقرير ولا يُعرَض إطلاقاً ضمن أي من قسمي
/// المصروفات — قسمه المستقل يظهر فقط عند وجود سحوبات فعلية بهذا التاريخ.
class OwnerWithdrawalTemplateLine {
  final String methodLabel;
  final double amount;
  const OwnerWithdrawalTemplateLine({required this.methodLabel, required this.amount});
}

/// بند تحويل بين المنشآت معلَّق واحد بنفس تاريخ التقرير — لم يُرحَّل بعد
/// (راجع InterEntityTransferRepository)، قسمه المستقل يظهر فقط عند وجود
/// تحويلات معلَّقة فعلية بهذا التاريخ، ولا يدخل ضمن أي مجموع بهذا التقرير
/// (ليس مصروفاً — راجع تعليق InterEntityTransfer).
class InterHotelTransferTemplateLine {
  final String statement;
  final String counterpartHotelName;
  final double amount;
  final bool isOutgoing;
  const InterHotelTransferTemplateLine({required this.statement, required this.counterpartHotelName, required this.amount, required this.isOutgoing});
}

/// حصة هذا الفندق من "مصروف مشترك" بنفس تاريخ التقرير — عرض معلوماتي فقط
/// (القيد المحاسبي نُفِّذ فوراً عند حفظ المصروف المشترك نفسه، راجع
/// FinancialEngine.recordSharedExpense)، لا يدخل في أي مجموع بهذا التقرير.
class SharedExpenseTemplateLine {
  final String description;
  final String fundingHotelName;
  final double amount;
  final bool isFundingHotel;
  const SharedExpenseTemplateLine({required this.description, required this.fundingHotelName, required this.amount, required this.isFundingHotel});
}

/// القالب الرسمي الموحّد للتقرير المالي اليومي — بنية عرض بحتة (DTO) بلا أي
/// منطق حسابي؛ كل الأرقام تصل إليه جاهزة من FinancialSummaryPage (المصدر
/// الوحيد للحساب، دون أي تغيير). يُستهلَك من 3 مُخرجات بنفس الترتيب والمحتوى
/// تماماً: عرض المعاينة داخل التطبيق (DailyReportView)، نص المشاركة/النسخ
/// (renderDailyReportAsText)، وملف PDF (PdfService.shareDailyReportPdf) —
/// حتى لا يتكرر بناء القالب في 3 أماكن مختلفة فيختلف عرضه بينها.
class DailyReportTemplate {
  final String hotelName;
  final String dayName;
  final String date;
  final bool isAdditional;

  final List<ReportTemplateLine> incomeLines;
  final double totalIncome;

  final List<ReportTemplateLine> expenseLines;
  final double totalExpenses;

  final List<ReportTemplateLine> netLines; // صافي النقد / صافي الشبكة / ... (بدون الإجمالي)
  final double netTotal;

  final List<UnwithdrawnTemplateLine> unwithdrawnLines;

  final List<OwnerWithdrawalTemplateLine> ownerWithdrawalLines;

  final List<InterHotelTransferTemplateLine> transferLines;

  final List<SharedExpenseTemplateLine> sharedExpenseLines;

  const DailyReportTemplate({
    required this.hotelName,
    required this.dayName,
    required this.date,
    required this.isAdditional,
    required this.incomeLines,
    required this.totalIncome,
    required this.expenseLines,
    required this.totalExpenses,
    required this.netLines,
    required this.netTotal,
    required this.unwithdrawnLines,
    this.ownerWithdrawalLines = const [],
    this.transferLines = const [],
    this.sharedExpenseLines = const [],
  });
}

/// يبني القالب من قيم جاهزة الحساب مسبقاً — يُستبعَد أي بند بمبلغ صفر (أو
/// قريب من الصفر) من كل قسم هنا فقط (عرض)، لا في أي مكان يحسب الأرقام.
DailyReportTemplate buildDailyReportTemplate({
  required String hotelName,
  required String dayName,
  required String date,
  required bool isAdditional,
  required List<ReportTemplateLine> rawIncomeLines,
  required double totalIncome,
  required List<ReportTemplateLine> rawExpenseLines,
  required double totalExpenses,
  required List<ReportTemplateLine> rawNetLines,
  required double netTotal,
  required List<UnwithdrawnTemplateLine> unwithdrawnLines,
  List<OwnerWithdrawalTemplateLine> ownerWithdrawalLines = const [],
  List<InterHotelTransferTemplateLine> transferLines = const [],
  List<SharedExpenseTemplateLine> sharedExpenseLines = const [],
}) {
  bool nonZero(ReportTemplateLine l) => l.amount.abs() >= 0.01;
  return DailyReportTemplate(
    hotelName: hotelName,
    dayName: dayName,
    date: date,
    isAdditional: isAdditional,
    incomeLines: rawIncomeLines.where(nonZero).toList(),
    totalIncome: totalIncome,
    expenseLines: rawExpenseLines.where(nonZero).toList(),
    totalExpenses: totalExpenses,
    netLines: rawNetLines.where(nonZero).toList(),
    netTotal: netTotal,
    unwithdrawnLines: unwithdrawnLines,
    ownerWithdrawalLines: ownerWithdrawalLines,
    transferLines: transferLines,
    sharedExpenseLines: sharedExpenseLines,
  );
}
