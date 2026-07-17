import 'dart:convert';
import 'dart:typed_data';

/// يُرمى فقط عند فشل حقيقي في القراءة — Base64 غير صالح، أو بنية TLV تالفة
/// تماماً بحيث لا يمكن استخراج ولو حقل واحد منها. عدم وجود بعض الحقول
/// (رقم الفاتورة مثلاً، غير موجود أصلاً في معيار ZATCA المبسّط) ليس خطأ —
/// راجع [ZatcaInvoiceData] وتعليقها.
class ZatcaQrParseException implements Exception {
  final String message;
  const ZatcaQrParseException(this.message);
  @override
  String toString() => message;
}

/// البيانات المستخرَجة من رمز QR لفاتورة ضريبية سعودية مبسّطة (ZATCA Phase 1)
/// — كل حقل Nullable لأن أياً منها قد يكون غائباً من الرمز نفسه (لا خطأ في
/// ذلك). ملاحظة: معيار ZATCA المبسّط **لا يتضمّن رقم الفاتورة إطلاقاً** ولا
/// وقتاً منفصلاً عن التاريخ (فقط طابع زمني كامل) — [timestamp] يحمل
/// التاريخ والوقت معاً، لكن نموذج Invoice الحالي يخزّن التاريخ فقط.
class ZatcaInvoiceData {
  final String? sellerName;
  final String? vatNumber;
  final DateTime? timestamp;
  final double? invoiceTotal;
  final double? vatTotal;

  const ZatcaInvoiceData({
    this.sellerName,
    this.vatNumber,
    this.timestamp,
    this.invoiceTotal,
    this.vatTotal,
  });

  /// الإجمالي قبل الضريبة = الإجمالي − الضريبة الفعليان القادمان من الرمز
  /// مباشرة (أدق من أي تقريب بنسبة 15% مفترضة) — null إن غاب أحدهما.
  double? get amountBeforeTax {
    if (invoiceTotal == null || vatTotal == null) return null;
    return double.parse((invoiceTotal! - vatTotal!).toStringAsFixed(2));
  }

  bool get hasAnyField => sellerName != null || vatNumber != null || timestamp != null || invoiceTotal != null || vatTotal != null;
}

const int _tagSellerName = 1;
const int _tagVatNumber = 2;
const int _tagTimestamp = 3;
const int _tagInvoiceTotal = 4;
const int _tagVatTotal = 5;

/// يحلّل محتوى رمز QR (نص Base64 خام كما تعطيه الكاميرا) إلى [ZatcaInvoiceData]
/// عبر فك التشفير ثم قراءة بنية TLV (Tag-Length-Value: بايت وسم، بايت طول،
/// ثم عدد "الطول" من البايتات كقيمة UTF-8) بايتاً ببايت. أي Tags خارج 1-5
/// (خاصة بالمرحلة الثانية: hash/توقيع رقمي) تُتجاوَز بأمان دون التأثير على
/// الحقول الخمسة الأساسية.
ZatcaInvoiceData parseZatcaQr(String rawContent) {
  final Uint8List bytes;
  try {
    bytes = base64.decode(rawContent.trim());
  } catch (_) {
    throw const ZatcaQrParseException("الرمز الممسوح ليس مُشفَّراً بصيغة Base64 صالحة");
  }

  String? sellerName;
  String? vatNumber;
  DateTime? timestamp;
  double? invoiceTotal;
  double? vatTotal;

  var offset = 0;
  while (offset + 2 <= bytes.length) {
    final tag = bytes[offset];
    final length = bytes[offset + 1];
    final valueStart = offset + 2;
    final valueEnd = valueStart + length;
    if (valueEnd > bytes.length) break; // بنية تالفة من هذه النقطة — نتوقف بما استُخرِج حتى الآن.

    final valueBytes = bytes.sublist(valueStart, valueEnd);
    String? value;
    try {
      value = utf8.decode(valueBytes);
    } catch (_) {
      value = null;
    }

    if (value != null && value.isNotEmpty) {
      switch (tag) {
        case _tagSellerName:
          sellerName = value;
          break;
        case _tagVatNumber:
          vatNumber = value;
          break;
        case _tagTimestamp:
          timestamp = DateTime.tryParse(value);
          break;
        case _tagInvoiceTotal:
          invoiceTotal = double.tryParse(value);
          break;
        case _tagVatTotal:
          vatTotal = double.tryParse(value);
          break;
      }
    }

    offset = valueEnd;
  }

  final result = ZatcaInvoiceData(
    sellerName: sellerName,
    vatNumber: vatNumber,
    timestamp: timestamp,
    invoiceTotal: invoiceTotal,
    vatTotal: vatTotal,
  );

  if (!result.hasAnyField) {
    throw const ZatcaQrParseException("تعذّر التعرّف على أي بيانات فاتورة داخل هذا الرمز");
  }

  return result;
}
