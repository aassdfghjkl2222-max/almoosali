import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/extracted_invoice_data.dart';

/// OCR محلي احتياطي (يُستخدَم فقط عند غياب الإنترنت) — Google ML Kit Text
/// Recognition، نص لاتيني فقط. **لا يدعم اللغة العربية إطلاقاً** (ML Kit
/// المحلي يدعم Latin/صيني/يابياني/كوري/Devanagari فقط) — لن يُستخرَج اسم
/// مورد عربي بشكل موثوق. يستخرج فقط ما يمكن التعرّف عليه بأنماط عامة
/// (أرقام): الرقم الضريبي (15 رقماً)، مبالغ عشرية، تاريخ. نتيجة أقل دقة
/// عمداً — تُعاد بعلامة source: localOcr لتُظهر شاشة المراجعة تحذيراً واضحاً.
class InvoiceLocalOcrService {
  InvoiceLocalOcrService._();

  static final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<ExtractedInvoiceData> extractFromImage(String imagePath) async {
    final correctedPath = await _deskewIfNeeded(imagePath);
    final inputImage = InputImage.fromFilePath(correctedPath);
    final recognized = await _recognizer.processImage(inputImage);
    return _parseText(recognized.text);
  }

  /// تصحيح ميلان الصورة اعتماداً على زاوية الأسطر التي يكتشفها ML Kit نفسه
  /// (لا حاجة لمكتبة رؤية حاسوبية إضافية): تمريرة أولى للقياس فقط، وإن كان
  /// متوسط الميلان محسوساً (بين درجة وحتى 15 درجة — خارج هذا النطاق إما
  /// ميلان مهمَل أو قياس غير موثوق) تُدار الصورة وتُعاد كتابتها لملف مؤقت
  /// جديد يُستخدم للتمريرة الفعلية. أي فشل يُبقي الصورة الأصلية بلا توقف.
  static Future<String> _deskewIfNeeded(String imagePath) async {
    try {
      final measurement = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
      final angles = <double>[
        for (final block in measurement.blocks)
          for (final line in block.lines)
            if (line.angle != null) line.angle!,
      ];
      if (angles.isEmpty) return imagePath;

      final avgAngle = angles.reduce((a, b) => a + b) / angles.length;
      if (avgAngle.abs() < 1 || avgAngle.abs() > 15) return imagePath;

      final bytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return imagePath;
      image = img.copyRotate(image, angle: -avgAngle, interpolation: img.Interpolation.linear);

      final tempDir = await getTemporaryDirectory();
      final correctedPath = "${tempDir.path}/invoice_ocr_deskewed_${DateTime.now().millisecondsSinceEpoch}.png";
      await File(correctedPath).writeAsBytes(img.encodePng(image));
      return correctedPath;
    } catch (_) {
      return imagePath;
    }
  }

  static ExtractedInvoiceData _parseText(String text) {
    final taxNumber = _extractTaxNumber(text);
    final amounts = _extractAmounts(text);
    final date = _extractDate(text);

    double? total;
    double? vat;
    if (amounts.isNotEmpty) {
      amounts.sort();
      total = amounts.last;
      // مبلغ الضريبة المحتمل: أي رقم آخر يقارب 15% من الإجمالي (الأكبر) —
      // تخمين تقريبي فقط، لا يُفترض أنه دقيق دوماً (نفس تحذير الدقة الأقل).
      for (final candidate in amounts) {
        if (candidate <= 0 || candidate >= total) continue;
        final expectedVat = double.parse((total - total / 1.15).toStringAsFixed(2));
        if ((candidate - expectedVat).abs() < 1) {
          vat = candidate;
          break;
        }
      }
    }

    return ExtractedInvoiceData(
      vatNumber: taxNumber,
      timestamp: date,
      invoiceTotal: total,
      vatTotal: vat,
      source: InvoiceExtractionSource.localOcr,
    );
  }

  static String? _extractTaxNumber(String text) {
    // الرقم الضريبي السعودي يبدأ عادة بـ3 — يُفضَّل إن وُجد، وإلا أي تسلسل 15 رقماً.
    final preferred = RegExp(r'\b3\d{14}\b').firstMatch(text);
    if (preferred != null) return preferred.group(0);
    final any = RegExp(r'\b\d{15}\b').firstMatch(text);
    return any?.group(0);
  }

  static List<double> _extractAmounts(String text) {
    final matches = RegExp(r'\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?').allMatches(text);
    final amounts = <double>[];
    for (final m in matches) {
      final raw = m.group(0)!;
      if (raw.length >= 14) continue; // على الأرجح رقم ضريبي، ليس مبلغاً
      final value = double.tryParse(raw.replaceAll(',', ''));
      if (value != null && value > 0 && value < 10000000) amounts.add(value);
    }
    return amounts;
  }

  static DateTime? _extractDate(String text) {
    final iso = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(text);
    if (iso != null) return DateTime.tryParse(iso.group(0)!);

    final slash = RegExp(r'\b(\d{2})/(\d{2})/(\d{4})\b').firstMatch(text);
    if (slash != null) {
      final day = int.tryParse(slash.group(1)!);
      final month = int.tryParse(slash.group(2)!);
      final year = int.tryParse(slash.group(3)!);
      if (day != null && month != null && year != null) {
        try {
          return DateTime(year, month, day);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  static Future<void> dispose() => _recognizer.close();
}
