import 'dart:convert';
import '../models/advance_withdrawal.dart';
import '../models/daily_report_template.dart';
import '../models/financial_report.dart';
import '../models/pending_expense.dart';

/// يصنّف مصدر تمويل مصروف واحد لتحديد قسمه في التقرير: مدفوع من نقد إيراد
/// اليوم (raw"نقد" فقط)، سحب مالك (يُستبعَد من قسمي المصروفات كليهما، راجع
/// [OwnerWithdrawalTemplateLine])، أو "مصروف خارج إيراد اليوم" بمصدر/طريقة
/// دفع محدَّدين. مصدر وحيد يُستخدم من بناء القالب من الحالة الحيّة
/// (FinancialSummaryPage) وبنائه من تقرير محفوظ سابقاً (buildTemplateFromSavedReport)
/// — حتى لا يتكرر نفس المنطق في مكانين. لا علاقة له بحساب _calculateTotals
/// (تصنيف عرض/تقرير فقط، بلا أي أثر على أي رصيد).
///
/// [fundedByHotelName] له الأولوية دوماً — يُمرَّر فقط للمصروفات المعلقة ذات
/// funding_source_hotel_id حقيقي (اسم فندق مُستخرَج من قاعدة البيانات فعلياً،
/// وليس تحليلاً نصياً لِـ[method])، ويُنشئ ذمة تلقائية فعلية في المركز المالي
/// (راجع VaultRepository._postSpecialPendingExpenses).
class ExpenseFundingClassification {
  final bool isPaidFromTodayCash;
  final bool isOwnerWithdrawal;
  final String? fundingLabel;
  final String? methodLabel;
  const ExpenseFundingClassification({required this.isPaidFromTodayCash, required this.isOwnerWithdrawal, this.fundingLabel, this.methodLabel});
}

ExpenseFundingClassification classifyExpenseFunding(String method, String? supplierName, {String? fundedByHotelName}) {
  if (fundedByHotelName == null && method == PendingExpense.paymentMethodOwnerDrawing) {
    return const ExpenseFundingClassification(isPaidFromTodayCash: false, isOwnerWithdrawal: true);
  }
  if (fundedByHotelName != null) {
    return ExpenseFundingClassification(isPaidFromTodayCash: false, isOwnerWithdrawal: false, fundingLabel: fundedByHotelName, methodLabel: method == "شبكة" ? "بنك" : "نقد");
  }
  if (supplierName != null) {
    return ExpenseFundingClassification(isPaidFromTodayCash: false, isOwnerWithdrawal: false, fundingLabel: "دين - $supplierName");
  }
  if (method == PendingExpense.paymentMethodHotelAdvance) {
    return const ExpenseFundingClassification(isPaidFromTodayCash: false, isOwnerWithdrawal: false, fundingLabel: "المالك");
  }
  if (method == PendingExpense.paymentMethodSafe) {
    return const ExpenseFundingClassification(isPaidFromTodayCash: false, isOwnerWithdrawal: false, fundingLabel: "الخزنة", methodLabel: "نقد");
  }
  if (method == "شبكة") {
    return const ExpenseFundingClassification(isPaidFromTodayCash: false, isOwnerWithdrawal: false, fundingLabel: "شبكة");
  }
  // "مصروف خاص": قيمة تاريخية قديمة غير قابلة للإنشاء من أي شاشة حالية، كانت
  // تُعامَل كنقد إيراد اليوم دوماً — يبقى نفس السلوك لعرض تقارير قديمة بها.
  if (method == "نقد" || method == "مصروف خاص") {
    return const ExpenseFundingClassification(isPaidFromTodayCash: true, isOwnerWithdrawal: false);
  }
  // مسار قديم: بند تقرير حر بمصدر "نقد - اسم الفندق"/"شبكة - اسم الفندق"
  // مدمَج نصياً (بلا funding_source_hotel_id حقيقي — راجع تعليق showOtherHotelsFunding
  // في funding_source_picker.dart)، يبقى كما هو لعرض تقارير قديمة أُنشئت به فقط.
  if (method.contains(" - ")) {
    final parts = method.split(" - ");
    return ExpenseFundingClassification(isPaidFromTodayCash: false, isOwnerWithdrawal: false, fundingLabel: parts.sublist(1).join(' - '), methodLabel: parts.first == "شبكة" ? "بنك" : "نقد");
  }
  return ExpenseFundingClassification(isPaidFromTodayCash: false, isOwnerWithdrawal: false, fundingLabel: method);
}

/// يبني بنود قسم "مسحوبات المالك" المستقل من مصدرين: مبالغ سُحبت داخل هذا
/// التقرير نفسه بمصدر [PendingExpense.paymentMethodOwnerDrawing] القديم
/// (مسار مُستبدَل، يبقى معروضاً فقط لتقرير أُنشئ به سابقاً)، وسحوبات المالك
/// الفعلية المسجَّلة عبر AddOwnerWithdrawalPage/VaultRepository لنفس الفندق
/// والتاريخ (النظام الحالي المستقل تماماً عن التقرير اليومي). عرض معلوماتي
/// بحت — لا يدخل أي مبلغ هنا ضمن أي مجموع بهذا التقرير.
List<OwnerWithdrawalTemplateLine> buildOwnerWithdrawalLines({
  required List<double> legacyReportAmounts,
  required List<AdvanceWithdrawal> vaultWithdrawalsForDate,
}) {
  return [
    for (final a in legacyReportAmounts)
      if (a.abs() >= 0.01) OwnerWithdrawalTemplateLine(methodLabel: "نقد", amount: a),
    for (final w in vaultWithdrawalsForDate)
      if (w.amount.abs() >= 0.01) OwnerWithdrawalTemplateLine(methodLabel: w.method == "شبكة" ? "بنك" : "نقد", amount: w.amount),
  ];
}

/// أيقونة تعبيرية مناسبة لاسم بند حر (مصروف/إيراد مخصَّص أو بند من مصروف
/// معلّق) — مطابقة بكلمات مفتاحية شائعة، مع رمز عام (📦) لأي اسم آخر غير
/// مطابق. تحسين بصري بحت (لا علاقة له بأي تصنيف حسابي، خلافاً لِـ
/// classifyExpenseFunding الذي يصنّف حسب طريقة الدفع لا اسم البند) —
/// مصدر وحيد يُستخدم من بناء القالب الحيّ ومن التقارير المحفوظة معاً.
const _itemKeywordIcons = <String, String>{
  'ثلاج': '🧊',
  'كهرباء': '💡',
  'مياه': '🚰',
  'ماء': '🚰',
  'نظاف': '🧹',
  'صيان': '🔧',
  'نقل': '🚗',
};

String iconForItemName(String name) {
  for (final entry in _itemKeywordIcons.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return '📦';
}

String withItemIcon(String name) => name.isEmpty ? name : "${iconForItemName(name)} $name";

const _dayNames = ["", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"];

String _dayNameForDate(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return "";
  return _dayNames[d.weekday];
}

/// يُعيد بناء القالب الرسمي من تقرير محفوظ سابقاً (details_json) — تُستخدم
/// في "التقارير السابقة" لعرض/مشاركة/تصدير أي تقرير قديم بنفس القالب
/// المعتمد تماماً، دون الحاجة لإعادة تحميله داخل شاشة التعديل الحيّة.
DailyReportTemplate buildTemplateFromSavedReport({
  required FinancialReport report,
  required String hotelName,
  List<SharedExpenseTemplateLine> sharedExpenseLines = const [],
  List<AdvanceWithdrawal> vaultWithdrawalsForDate = const [],
  List<InterHotelTransferTemplateLine> transferLines = const [],
}) {
  final details = report.detailsJson != null ? jsonDecode(report.detailsJson!) as Map<String, dynamic> : <String, dynamic>{};
  final inc = (details['income_details'] as Map?) ?? {};
  final exp = (details['expense_details'] as Map?) ?? {};

  double asDouble(dynamic v) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);

  final incomeLines = <ReportTemplateLine>[
    ReportTemplateLine(label: "💵 النقد", amount: asDouble(inc['cash'])),
    ReportTemplateLine(label: "💳 الشبكة", amount: asDouble(inc['pos'])),
    ReportTemplateLine(label: "🏦 التحويل البنكي", amount: asDouble(inc['transfer'])),
    ReportTemplateLine(label: "مواقف (نقد)", amount: asDouble(inc['parking_cash'])),
    ReportTemplateLine(label: "مواقف (شبكة)", amount: asDouble(inc['parking_pos'])),
    for (final item in (inc['other_income'] as List? ?? []))
      ReportTemplateLine(label: withItemIcon(item['name']?.toString() ?? ''), amount: asDouble(item['amount'])),
  ];

  final otherExpenses = (exp['other'] as List? ?? []);
  final subsistenceAmount = asDouble(exp['subsistence']);
  final subsistenceMethod = exp['subsistence_method']?.toString() ?? "نقد";
  final subsistenceClass = classifyExpenseFunding(subsistenceMethod, null);
  final refundAmount = asDouble(exp['refund']);
  final refundMethod = exp['refund_method']?.toString() ?? "نقد";
  final refundClass = classifyExpenseFunding(refundMethod, null);

  final expenseLines = <ReportTemplateLine>[
    if (subsistenceClass.isPaidFromTodayCash) ReportTemplateLine(label: "🍽️ الإعاشة", amount: subsistenceAmount),
    if (refundClass.isPaidFromTodayCash) ReportTemplateLine(label: "↩️ الاسترداد", amount: refundAmount),
    for (final item in otherExpenses)
      if (item['funding_source_hotel_name'] == null && classifyExpenseFunding(item['method']?.toString() ?? '', item['supplier_name']?.toString()).isPaidFromTodayCash)
        ReportTemplateLine(label: withItemIcon(item['name']?.toString() ?? ''), amount: asDouble(item['amount'])),
  ];
  final totalDailyExpenses = expenseLines.fold(0.0, (sum, l) => sum + l.amount);

  final netCash = asDouble(details['net_cash']);
  final netPos = asDouble(details['net_pos']);
  final transfer = asDouble(inc['transfer']);
  double incTransfer = 0;
  for (final item in (inc['other_income'] as List? ?? [])) {
    final method = item['method']?.toString() ?? '';
    if (method != "نقد" && method != "شبكة") incTransfer += asDouble(item['amount']);
  }

  final netLines = <ReportTemplateLine>[
    ReportTemplateLine(label: "💼 صافي النقد", amount: netCash),
    ReportTemplateLine(label: "📊 صافي الشبكة", amount: netPos),
    ReportTemplateLine(label: "🏦 صافي التحويل البنكي", amount: transfer + incTransfer),
  ];

  final unwithdrawnLines = <UnwithdrawnTemplateLine>[];
  if (!subsistenceClass.isPaidFromTodayCash && subsistenceAmount.abs() >= 0.01) {
    unwithdrawnLines.add(UnwithdrawnTemplateLine(icon: "🍽️", itemName: "الإعاشة", label: subsistenceClass.fundingLabel ?? subsistenceMethod, methodLabel: subsistenceClass.methodLabel, amount: subsistenceAmount));
  }
  if (!refundClass.isPaidFromTodayCash && refundAmount.abs() >= 0.01) {
    unwithdrawnLines.add(UnwithdrawnTemplateLine(icon: "↩️", itemName: "الاسترداد", label: refundClass.fundingLabel ?? refundMethod, methodLabel: refundClass.methodLabel, amount: refundAmount));
  }
  final legacyOwnerWithdrawalAmounts = <double>[];
  for (final item in otherExpenses) {
    final method = item['method']?.toString() ?? '';
    final fundedByHotelName = item['funding_source_hotel_name']?.toString();
    final supplierName = item['supplier_name']?.toString();
    final itemAmount = asDouble(item['amount']);
    final c = classifyExpenseFunding(method, supplierName, fundedByHotelName: fundedByHotelName);
    if (c.isPaidFromTodayCash) continue;
    if (c.isOwnerWithdrawal) {
      legacyOwnerWithdrawalAmounts.add(itemAmount);
      continue;
    }
    unwithdrawnLines.add(UnwithdrawnTemplateLine(
      icon: iconForItemName(item['name']?.toString() ?? ''),
      itemName: item['name']?.toString() ?? '',
      label: c.fundingLabel ?? method,
      methodLabel: c.methodLabel,
      amount: itemAmount,
    ));
  }

  return buildDailyReportTemplate(
    hotelName: hotelName,
    dayName: _dayNameForDate(report.date),
    date: report.date,
    isAdditional: report.reportType == 'additional',
    rawIncomeLines: incomeLines,
    totalIncome: report.income,
    rawExpenseLines: expenseLines,
    totalExpenses: totalDailyExpenses,
    rawNetLines: netLines,
    netTotal: netCash + netPos + transfer + incTransfer,
    unwithdrawnLines: unwithdrawnLines,
    ownerWithdrawalLines: buildOwnerWithdrawalLines(legacyReportAmounts: legacyOwnerWithdrawalAmounts, vaultWithdrawalsForDate: vaultWithdrawalsForDate),
    transferLines: transferLines,
    sharedExpenseLines: sharedExpenseLines,
  );
}
