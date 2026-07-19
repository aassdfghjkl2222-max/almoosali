import 'dart:convert';
import 'dart:typed_data';

import '../models/extracted_invoice_data.dart';

/// يُرمى فقط عند فشل حقيقي في القراءة — Base64 غير صالح، أو بنية TLV تالفة
/// تماماً بحيث لا يمكن استخراج ولو حقل واحد منها. عدم وجود بعض الحقول
/// (رقم الفاتورة مثلاً، غير موجود أصلاً في معيار ZATCA المبسّط) ليس خطأ —
/// راجع [ExtractedInvoiceData] وتعليقها.
class ZatcaQrParseException implements Exception {
  final String message;
  const ZatcaQrParseException(this.message);
  @override
  String toString() => message;
}

const int _tagSellerName = 1;
const int _tagVatNumber = 2;
const int _tagTimestamp = 3;
const int _tagInvoiceTotal = 4;
const int _tagVatTotal = 5;

/// يحلّل محتوى رمز QR (نص Base64 خام كما تعطيه الكاميرا) إلى [ExtractedInvoiceData]
/// (بعلامة `source: zatcaQr`) عبر فك التشفير ثم قراءة بنية TLV (Tag-Length-Value:
/// بايت وسم، بايت طول، ثم عدد "الطول" من البايتات كقيمة UTF-8) بايتاً ببايت.
/// أي Tags خارج 1-5 (خاصة بالمرحلة الثانية: hash/توقيع رقمي) تُتجاوَز بأمان
/// دون التأثير على الحقول الخمسة الأساسية. ملاحظة: معيار ZATCA المبسّط **لا
/// يتضمّن رقم الفاتورة إطلاقاً** ولا وقتاً منفصلاً عن التاريخ (فقط طابع
/// زمني كامل) — timestamp يحمل التاريخ والوقت معاً.
ExtractedInvoiceData parseZatcaQr(String rawContent) {
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

  final result = ExtractedInvoiceData(
    sellerName: sellerName,
    vatNumber: vatNumber,
    timestamp: timestamp,
    invoiceTotal: invoiceTotal,
    vatTotal: vatTotal,
    source: InvoiceExtractionSource.zatcaQr,
  );

  if (!result.hasAnyField) {
    throw const ZatcaQrParseException("تعذّر التعرّف على أي بيانات فاتورة داخل هذا الرمز");
  }

  return result;
}
