/// بند واحد داخل أي قسم من التقرير (اسم + مبلغ) — بنود القيمة صفر تُستبعَد
/// دوماً قبل بناء القالب (راجع buildDailyReportTemplate)، وليس عند العرض.
class ReportTemplateLine {
  final String label;
  final double amount;
  const ReportTemplateLine({required this.label, required this.amount});
}

/// بند واحد داخل "مصروفات لم تخصم من خزنة الفندق" — [icon] رمز تعبيري ثابت
/// حسب نوع المصدر (🏦 شبكة، 📄 دين، 🏨 منشأة أخرى، 👤 مال المالك، ...)
/// و[label] النص الكامل شاملاً اسم المورد/المنشأة إن وُجد. [amount] المبلغ
/// الفعلي للبند — مطلوب لعرض بنود "مموَّل من فندق آخر" كاملة (المبلغ، البيان،
/// مصدر التمويل، طريقة الدفع) دون أي عنوان للقسم نفسه.
class UnwithdrawnTemplateLine {
  final String icon;
  final String itemName;
  final String label;
  final double amount;
  const UnwithdrawnTemplateLine({required this.icon, required this.itemName, required this.label, this.amount = 0});
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
  );
}
