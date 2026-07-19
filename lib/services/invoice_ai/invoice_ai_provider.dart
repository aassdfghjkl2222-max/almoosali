import 'dart:convert';
import 'dart:typed_data';

import '../../models/extracted_invoice_data.dart';

/// يُرمى عند فشل أي مزوّد ذكاء اصطناعي (ميزة معطَّلة، لا مفتاح محفوظ، لا
/// اتصال إنترنت، خطأ استجابة) — المستدعي (خط أنابيب الالتقاط) يلتقطه
/// ويسقط تلقائياً نحو OCR المحلي.
class InvoiceAiException implements Exception {
  final String message;
  const InvoiceAiException(this.message);
  @override
  String toString() => message;
}

/// واجهة موحّدة لأي مزوّد ذكاء اصطناعي قادر على قراءة صور فواتير — إضافة
/// مزوّد رابع مستقبلاً تعني تطبيق واحد جديد لهذه الواجهة + تسجيله في
/// InvoiceAiService.availableProviders، بلا أي تعديل آخر في التطبيق.
abstract class InvoiceAiProvider {
  String get id;
  String get displayName;

  /// يستخرج بيانات فاتورة واحدة أو أكثر من صور جاهزة (PNG/JPEG بايتات خام،
  /// صفحة واحدة أو أكثر لنفس الفاتورة أو فواتير مستقلة معاً) عبر [apiKey]
  /// الخاص بهذا المزوّد. يرمي [InvoiceAiException] عند فشل الاتصال أو رد
  /// غير صالح.
  Future<List<ExtractedInvoiceData>> extractFromImages(List<Uint8List> images, {required String apiKey});
}

/// موجّه الاستخراج المشترك بين المزوّدين الثلاثة — يطلب JSON بمصفوفة
/// فواتير بصيغة موحّدة، بحيث يبقى تحليل الرد (parseInvoiceExtractionJson)
/// مصدراً واحداً بلا تكرار منطق لكل مزوّد.
const String kInvoiceExtractionPrompt = '''
أنت مساعد متخصص في قراءة الفواتير الضريبية السعودية. استخرج بيانات كل فاتورة ضريبية موجودة في الصور المرفقة (قد تكون صورة واحدة، أو عدة صفحات لنفس الفاتورة، أو أكثر من فاتورة مستقلة في نفس الصورة). أرجع النتيجة بصيغة JSON فقط بلا أي نص إضافي قبلها أو بعدها، بالضبط بهذا الشكل:

{"invoices": [{"seller_name": string|null, "tax_number": string|null, "invoice_number": string|null, "date": string|null, "time": string|null, "currency": string|null, "total_amount": number|null, "vat_amount": number|null}]}

قواعد:
- date بصيغة yyyy-MM-dd، time بصيغة HH:mm إن وُجد.
- الرقم الضريبي السعودي يتكوّن من 15 رقماً.
- استنتج القيم غير الواضحة من سياق الفاتورة نفسها قدر الإمكان، لكن لا تختلق بيانات غير موجودة فعلياً — استخدم null لأي حقل غير متأكد منه.
- إن كانت الصور صفحات متعددة لنفس الفاتورة، اجمعها في عنصر واحد بالمصفوفة.
- إن وجدت أكثر من فاتورة مستقلة، أضف كل واحدة كعنصر منفصل بالمصفوفة.
- إن لم تجد أي فاتورة إطلاقاً، أرجع "invoices": [].
''';

/// يحلّل رد أي مزوّد (نص JSON، قد يكون ملفوفاً بحدود ```json عرَضاً) إلى
/// قائمة [ExtractedInvoiceData] بعلامة [source] المُمرَّرة — مصدر تحليل
/// واحد تستدعيه المزوّدات الثلاثة بعد استخراج النص الخام من مغلَّف
/// استجابة كل واحد منها.
List<ExtractedInvoiceData> parseInvoiceExtractionJson(String rawText, InvoiceExtractionSource source) {
  final cleaned = _stripJsonFences(rawText);
  if (cleaned.isEmpty) return [];

  dynamic decoded;
  try {
    decoded = jsonDecode(cleaned);
  } catch (_) {
    throw const InvoiceAiException('تعذّر فهم رد خدمة الذكاء الاصطناعي');
  }

  final list = decoded is Map ? decoded['invoices'] : (decoded is List ? decoded : null);
  if (list is! List) return [];

  double? asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  return list
      .whereType<Map>()
      .map((item) {
        final map = Map<String, dynamic>.from(item);
        final date = map['date']?.toString();
        final time = map['time']?.toString();
        DateTime? timestamp;
        if (date != null && date.isNotEmpty) {
          final combined = time != null && time.isNotEmpty ? '${date}T$time:00' : date;
          timestamp = DateTime.tryParse(combined);
        }
        return ExtractedInvoiceData(
          sellerName: map['seller_name']?.toString(),
          vatNumber: map['tax_number']?.toString(),
          invoiceNumber: map['invoice_number']?.toString(),
          timestamp: timestamp,
          invoiceTotal: asDouble(map['total_amount']),
          vatTotal: asDouble(map['vat_amount']),
          currency: map['currency']?.toString(),
          source: source,
        );
      })
      .where((e) => e.hasAnyField)
      .toList();
}

String _stripJsonFences(String text) {
  var t = text.trim();
  if (t.startsWith('```')) {
    t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
    final fenceEnd = t.lastIndexOf('```');
    if (fenceEnd != -1) t = t.substring(0, fenceEnd);
  }
  return t.trim();
}
