import 'package:intl/intl.dart';
import '../models/daily_report_template.dart';

final _currency = NumberFormat("#,##0.##");

// خط فاصل قصير عمداً (سطر واحد على كل عرض شاشة هاتف عملياً، بما فيها
// الشاشات الضيقة) — كان أطول بكثير سابقاً وينتقل لسطرين داخل واتساب.
const _separator = "――――――――――――";

/// يفصل الأيقونة عن بقية التسمية في [ReportTemplateLine.label] المبنية دوماً
/// بصيغة "أيقونة نص" (عبر withItemIcon أو أيقونة ثابتة يدوياً) — يُستخدم فقط
/// لعرض "المصروفات اليومية" بصيغة [أيقونة] [مبلغ] — [نوع] المدمَجة (مطابقةً
/// لصيغة قسم "مصروفات خارج إيراد اليوم")، بلا أي تغيير على بنية
/// ReportTemplateLine العامة المستخدَمة أيضاً في الإيرادات وصافي النقد.
({String icon, String name}) _splitIconLabel(String label) {
  final spaceIndex = label.indexOf(' ');
  if (spaceIndex <= 0) return (icon: '', name: label);
  return (icon: label.substring(0, spaceIndex), name: label.substring(spaceIndex + 1));
}

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
      final s = _splitIconLabel(l.label);
      buffer.writeln("${s.icon} ${_currency.format(l.amount)} — ${s.name}".trim());
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
      ..writeln("*📤 مصروفات خارج إيراد اليوم*");
    for (final l in t.unwithdrawnLines) {
      final methodSuffix = l.methodLabel != null ? " — ${l.methodLabel}" : "";
      buffer.writeln("${l.icon} ${_currency.format(l.amount)} — ${l.itemName} — ${l.label}$methodSuffix");
    }
  }

  if (t.ownerWithdrawalLines.isNotEmpty) {
    buffer
      ..writeln(_separator)
      ..writeln()
      ..writeln("*👤 مسحوبات المالك*");
    for (final l in t.ownerWithdrawalLines) {
      buffer.writeln("💰 ${_currency.format(l.amount)} — ${l.methodLabel}");
    }
  }

  if (t.transferLines.isNotEmpty) {
    buffer
      ..writeln(_separator)
      ..writeln()
      ..writeln("*🔄 تحويل بين المنشآت*");
    for (final l in t.transferLines) {
      buffer.writeln("${_currency.format(l.amount)} — ${l.isOutgoing ? 'إلى' : 'من'} ${l.counterpartHotelName} (${l.statement})");
    }
  }

  if (t.sharedExpenseLines.isNotEmpty) {
    buffer
      ..writeln(_separator)
      ..writeln("🤝 مصروفات مشترَكة (نُفِّذت فوراً، للعرض فقط)");
    for (final l in t.sharedExpenseLines) {
      buffer.writeln("${l.description}: ${_currency.format(l.amount)} — ${l.isFundingHotel ? 'مموِّل' : 'مموَّل من ${l.fundingHotelName}'}");
    }
  }

  return buffer.toString().trimRight();
}
