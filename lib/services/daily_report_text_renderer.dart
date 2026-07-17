import 'package:intl/intl.dart';
import '../models/daily_report_template.dart';

final _currency = NumberFormat("#,##0.##");

// خط فاصل قصير عمداً (سطر واحد على كل عرض شاشة هاتف عملياً، بما فيها
// الشاشات الضيقة) — كان أطول بكثير سابقاً وينتقل لسطرين داخل واتساب.
const _separator = "――――――――――――";

/// نص التقرير الرسمي الموحّد (يُستخدم في المشاركة والنسخ معاً عبر دالة واحدة
/// بدل ازدواجية سابقة) — نفس ترتيب/محتوى قالب DailyReportView وPDF تماماً.
/// العناوين الكبيرة الأربعة فقط (التقرير المالي اليومي/الإيرادات اليومية/
/// المصروفات اليومية/صافي النقد) تُكتب بصيغة *نص عريض* (تنسيق واتساب القياسي)؛
/// كل ما عداها نص عادي — مطابقةً لتدرج الخطوط المعتمد داخل التطبيق أيضاً.
String renderDailyReportAsText(DailyReportTemplate t) {
  final buffer = StringBuffer()
    ..writeln("*📊 التقرير المالي اليومي*")
    ..writeln()
    ..writeln("🏨 ${t.hotelName}")
    ..writeln("📅 ${t.dayName} | 📆 ${t.date}");

  if (t.isAdditional) buffer.writeln("(تقرير إضافي)");

  if (t.incomeLines.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln("*💰 الإيرادات اليومية*");
    for (final l in t.incomeLines) {
      buffer.writeln("${l.label}: ${_currency.format(l.amount)}");
    }
    buffer
      ..writeln("✅ إجمالي الإيرادات: ${_currency.format(t.totalIncome)}")
      ..writeln(_separator);
  }

  if (t.expenseLines.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln("*💸 المصروفات اليومية*");
    for (final l in t.expenseLines) {
      buffer.writeln("${l.label}: ${_currency.format(l.amount)}");
    }
    buffer
      ..writeln("✅ إجمالي المصروفات: ${_currency.format(t.totalExpenses)}")
      ..writeln(_separator);
  }

  if (t.netLines.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln("*💵 صافي النقد*");
    for (final l in t.netLines) {
      buffer.writeln("${l.label}: ${_currency.format(l.amount)}");
    }
    buffer.writeln("🏁 الإجمالي الصافي: ${_currency.format(t.netTotal)}");
  }

  if (t.unwithdrawnLines.isNotEmpty) {
    buffer
      ..writeln(_separator)
      ..writeln()
      ..writeln("🏛️ المصروفات التي لم تُصرف من خزينة الفندق");
    for (final l in t.unwithdrawnLines) {
      buffer.writeln("${l.itemName}: ${l.icon} ${l.label}");
    }
  }

  return buffer.toString().trimRight();
}
