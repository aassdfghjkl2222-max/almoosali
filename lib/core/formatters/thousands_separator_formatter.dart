import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// ينسّق أي حقل إدخال رقمي بفاصل آلاف (1,000) أثناء الكتابة مباشرة،
/// مع الحفاظ على القيمة الرقمية الحقيقية القابلة للتحليل (لا يحوّل الحقل
/// إلى نص عرض فقط). يُستخدم على كل حقول المبالغ في التطبيق.
///
/// ملاحظة: القيمة المعروضة تُنظَّف من الفواصل دائماً قبل التحليل عبر
/// `double.parse(text.replaceAll(',', ''))` في منطق الحفظ.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text.replaceAll(',', '');
    if (text == '.' || text == '-') return newValue;

    final value = double.tryParse(text);
    if (value == null) return oldValue;

    final formatter = NumberFormat("#,###.##");
    String newText = formatter.format(value);
    if (text.endsWith('.') && !newText.contains('.')) newText += '.';

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  /// يزيل فواصل الآلاف قبل تحويل نص الحقل إلى رقم — استخدمها دائماً بدل
  /// `double.tryParse` مباشرة على نص حقل يستخدم هذا المنسّق.
  static double? parse(String text) => double.tryParse(text.replaceAll(',', ''));
}
