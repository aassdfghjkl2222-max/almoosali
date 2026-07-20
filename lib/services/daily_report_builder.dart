import 'dart:convert';
import '../models/daily_report_template.dart';
import '../models/financial_report.dart';

/// يصنّف مصدر تمويل واحداً إلى (رمز تعبيري + تسمية) لقسم "مصروفات لم تخصم
/// من خزنة الفندق" — "الخزنة" تعني النقد الفعلي حصراً، لذلك "شبكة" تظهر هنا
/// أيضاً (لم تُسحب من صندوق النقد، وإن كانت محتسَبة ضمن صافي الشبكة أصلاً —
/// تصنيف عرض فقط، بلا أي أثر على أي حساب). مصدر وحيد يُستخدم من كل من بناء
/// القالب من الحالة الحيّة (FinancialSummaryPage) وبنائه من تقرير محفوظ سابقاً
/// (buildTemplateFromSavedReport) — حتى لا يتكرر نفس المنطق في مكانين.
///
/// [fundedByHotelName] له الأولوية دوماً — يُمرَّر فقط للمصروفات المعلقة ذات
/// funding_source_hotel_id حقيقي (اسم فندق مُستخرَج من قاعدة البيانات فعلياً،
/// وليس تحليلاً نصياً لِـ[method] كما كان سابقاً)، ويُنشئ ذمة تلقائية فعلية
/// في المركز المالي (راجع VaultRepository._postSpecialPendingExpenses).
({String icon, String label}) classifyUnwithdrawnSource(String method, String? supplierName, {String? fundedByHotelName}) {
  if (fundedByHotelName != null) return (icon: "🏨", label: fundedByHotelName);
  if (supplierName != null) return (icon: "🤝", label: "دين - $supplierName");
  if (method == "شبكة") return (icon: "💳", label: "شبكة");
  if (method == "تحويل بنكي") return (icon: "🏦", label: "تحويل بنكي");
  if (method == "شخصي") return (icon: "👤", label: "مال المالك");
  if (method.contains(" - ")) {
    final parts = method.split(" - ");
    return (icon: "🏨", label: "منشأة أخرى (${parts.first}) - ${parts.sublist(1).join(' - ')}");
  }
  return (icon: "📄", label: method);
}

/// أيقونة تعبيرية مناسبة لاسم بند حر (مصروف/إيراد مخصَّص أو بند من مصروف
/// معلّق) — مطابقة بكلمات مفتاحية شائعة، مع رمز عام (📦) لأي اسم آخر غير
/// مطابق. تحسين بصري بحت (لا علاقة له بأي تصنيف حسابي، خلافاً لِـ
/// classifyUnwithdrawnSource الذي يصنّف حسب طريقة الدفع لا اسم البند) —
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
  final expenseLines = <ReportTemplateLine>[
    ReportTemplateLine(label: "🍽️ الإعاشة", amount: asDouble(exp['subsistence'])),
    ReportTemplateLine(label: "↩️ الاسترداد", amount: asDouble(exp['refund'])),
    for (final item in otherExpenses) ReportTemplateLine(label: withItemIcon(item['name']?.toString() ?? ''), amount: asDouble(item['amount'])),
  ];

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
  for (final item in otherExpenses) {
    final method = item['method']?.toString() ?? '';
    final fundedByHotelName = item['funding_source_hotel_name']?.toString();
    if (fundedByHotelName == null && (method == "نقد" || method == "مصروف خاص" || method == "مسحوبات المالك")) continue;
    final supplierName = item['supplier_name']?.toString();
    final c = classifyUnwithdrawnSource(method, supplierName, fundedByHotelName: fundedByHotelName);
    unwithdrawnLines.add(UnwithdrawnTemplateLine(icon: c.icon, itemName: item['name']?.toString() ?? '', label: c.label, amount: asDouble(item['amount'])));
  }

  return buildDailyReportTemplate(
    hotelName: hotelName,
    dayName: _dayNameForDate(report.date),
    date: report.date,
    isAdditional: report.reportType == 'additional',
    rawIncomeLines: incomeLines,
    totalIncome: report.income,
    rawExpenseLines: expenseLines,
    totalExpenses: report.expenses,
    rawNetLines: netLines,
    netTotal: netCash + netPos + transfer + incTransfer,
    unwithdrawnLines: unwithdrawnLines,
    sharedExpenseLines: sharedExpenseLines,
  );
}
