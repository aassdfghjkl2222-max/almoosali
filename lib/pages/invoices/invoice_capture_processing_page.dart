import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../core/hotel_visual_identity.dart';
import '../../models/extracted_invoice_data.dart';
import '../../models/hotel.dart';
import '../../services/image_enhancement_service.dart';
import '../../services/invoice_ai/invoice_ai_provider.dart';
import '../../services/invoice_ai/invoice_ai_service.dart';
import '../../services/invoice_local_ocr_service.dart';
import '../../services/zatca_qr_parser.dart';
import 'add_invoice_page.dart';
import 'invoice_capture_sheet.dart';
import 'multi_invoice_picker_page.dart';
import 'quick_invoice_review_page.dart';

/// شاشة معالجة موجزة تُشغَّل فور اختيار مصدر (كاميرا/معرض/PDF) — تُجري خط
/// الأنابيب الكامل تلقائياً بلا أي سؤال للمستخدم: محاولة قراءة QR على
/// الصورة الثابتة أولاً (بلا أي ذكاء اصطناعي إن كانت بياناته كاملة)، فإن
/// غاب أو كان ناقصاً تُحسَّن الصورة تلقائياً وتُستكمَل عبر ذكاء اصطناعي
/// سحابي ثم OCR محلي، مع دمج ما توفّر من QR مع نتيجة الاستكمال للحصول على
/// أفضل بيانات ممكنة — ثم تنتقل مباشرة لشاشة المراجعة السريعة (أو قائمة
/// اختيار عند تعدد الفواتير). لا مصطلحات تقنية ظاهرة ولا رسائل عن فشل/غياب
/// QR تحديداً؛ رسالة حالة عربية بسيطة فقط طوال الوقت.
class InvoiceCaptureProcessingPage extends StatefulWidget {
  final Hotel hotel;
  final InvoiceCaptureSource source;
  const InvoiceCaptureProcessingPage({super.key, required this.hotel, required this.source});

  @override
  State<InvoiceCaptureProcessingPage> createState() => _InvoiceCaptureProcessingPageState();
}

class _InvoiceCaptureProcessingPageState extends State<InvoiceCaptureProcessingPage> {
  String _statusText = "جارٍ القراءة...";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _process());
  }

  Future<void> _process() async {
    try {
      late final List<Uint8List> images;
      late final String firstImagePath;

      if (widget.source.imagePath != null) {
        final bytes = await File(widget.source.imagePath!).readAsBytes();
        images = [bytes];
        firstImagePath = widget.source.imagePath!;
      } else {
        final pdfBytes = await File(widget.source.pdfPath!).readAsBytes();
        final pages = <Uint8List>[];
        await for (final page in Printing.raster(pdfBytes, dpi: 150)) {
          pages.add(await page.toPng());
        }
        if (pages.isEmpty) {
          _finishWithError("تعذّرت قراءة ملف PDF المحدَّد.");
          return;
        }
        images = pages;
        final tempDir = await getTemporaryDirectory();
        firstImagePath = "${tempDir.path}/invoice_capture_page1_${DateTime.now().millisecondsSinceEpoch}.png";
        await File(firstImagePath).writeAsBytes(images.first);
      }

      // 1) محاولة QR على الصورة/الصفحة الأولى فقط. إن كانت بياناته كاملة
      //    (رقم ضريبي + إجمالي) فهذا يكفي وحده — بلا أي ذكاء اصطناعي. إن
      //    كان ناقصاً أو غائباً بالكامل، نكمل تلقائياً لاستكماله دون أي سؤال
      //    للمستخدم ودون إظهار أي رسالة عن فشل/غياب QR (بصمت تام).
      final qrResult = await _tryReadQr(firstImagePath);
      if (qrResult != null && qrResult.isComplete) {
        _finishWithResults([qrResult]);
        return;
      }
      if (!mounted) return;

      // 2) تحسين تلقائي للصور (تصحيح دوران، تباين/سطوع، تقليل تشويش) قبل أي
      //    قراءة نصية — لا يُطبَّق قبل QR عمداً (قارئات الباركود تتعامل مع
      //    الميلان/الإضاءة أصلاً، وقد يضرّها التنعيم).
      setState(() => _statusText = qrResult != null ? "جارٍ استكمال البيانات..." : "جارٍ التحليل...");
      final enhancedImages = await ImageEnhancementService.enhanceAll(images);

      // 3) ذكاء اصطناعي سحابي (إن كان مفعَّلاً ومتوفراً له مفتاح واتصال إنترنت)
      //    — نتائجه تُدمَج مع بيانات QR الجزئية إن وُجدت (القيم من QR تبقى
      //    الأدق فتُفضَّل، والذكاء الاصطناعي يستكمل الناقص منها فقط).
      List<ExtractedInvoiceData> aiResults = const [];
      try {
        aiResults = await InvoiceAiService.extractFromImages(enhancedImages);
      } on InvoiceAiException catch (_) {
        // نتابع بصمت لمسار OCR المحلي — لا نعرض تفاصيل تقنية للمستخدم.
      }
      if (aiResults.isNotEmpty) {
        final merged = mergeExtractedInvoiceData(qrResult ?? aiResults.first, qrResult != null ? aiResults.first : null);
        _finishWithResults([merged, ...aiResults.skip(1)]);
        return;
      }
      if (!mounted) return;

      // 4) OCR محلي احتياطي (صورة واحدة فقط — أول صورة/صفحة بعد تحسينها)،
      //    ويُدمَج بدوره مع بيانات QR الجزئية إن وُجدت لأفضل نتيجة ممكنة.
      setState(() => _statusText = "جارٍ القراءة محلياً...");
      final enhancedFirstPath = await _writeTempPng(enhancedImages.first);
      final ocrResult = await InvoiceLocalOcrService.extractFromImage(enhancedFirstPath);
      final merged = mergeExtractedInvoiceData(qrResult ?? ocrResult, qrResult != null ? ocrResult : null);
      if (merged.hasAnyField) {
        _finishWithResults([merged]);
        return;
      }

      _finishWithError("تعذّرت قراءة أي بيانات من هذه الفاتورة. جرّب صورة أوضح، أو أدخل البيانات يدوياً.");
    } catch (_) {
      _finishWithError("حدث خطأ أثناء قراءة الفاتورة. حاول مرة أخرى.");
    }
  }

  Future<String> _writeTempPng(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final path = "${tempDir.path}/invoice_capture_enhanced_${DateTime.now().millisecondsSinceEpoch}.png";
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<ExtractedInvoiceData?> _tryReadQr(String imagePath) async {
    final controller = MobileScannerController();
    try {
      final capture = await controller.analyzeImage(imagePath);
      final raw = (capture?.barcodes.isNotEmpty ?? false) ? capture!.barcodes.first.rawValue : null;
      if (raw == null) return null;
      return parseZatcaQr(raw);
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  /// يستخدم Navigator.push (وليس pushReplacement) عمداً ثم يُعيد ربط نتيجة
  /// الحفظ (true/false) عبر Navigator.pop بنفسه — pushReplacement كان يُنهي
  /// مستقبَل "await Navigator.push" الذي بدأ منه المستخدم في InvoicesPage
  /// فوراً بقيمة null بمجرد استبدال هذه الشاشة، قبل أن يضغط المستخدم
  /// "تأكيد" أصلاً؛ هذا كان يمنع تحديث قائمة الفواتير رغم نجاح الحفظ الفعلي
  /// في قاعدة البيانات (الفاتورة كانت موجودة فعلاً، فقط القائمة المعروضة
  /// لم تُحدَّث حتى إعادة فتح الشاشة).
  Future<void> _finishWithResults(List<ExtractedInvoiceData> results) async {
    if (!mounted) return;
    if (results.length == 1) {
      final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => QuickInvoiceReviewPage(hotel: widget.hotel, extractedData: results.first)));
      if (mounted) Navigator.pop(context, saved == true);
      return;
    }
    final selected = await Navigator.push(context, MaterialPageRoute(builder: (_) => MultiInvoicePickerPage(hotel: widget.hotel, invoices: results)));
    if (!mounted) return;
    if (selected is ExtractedInvoiceData) {
      final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => QuickInvoiceReviewPage(hotel: widget.hotel, extractedData: selected)));
      if (mounted) Navigator.pop(context, saved == true);
    } else {
      Navigator.pop(context, false);
    }
  }

  void _finishWithError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  Future<void> _enterManually() async {
    final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddInvoicePage(hotel: widget.hotel)));
    if (mounted) Navigator.pop(context, saved == true);
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _errorMessage == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: identityColor),
                    const SizedBox(height: 24),
                    Text(_statusText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("رجوع")),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _enterManually,
                          style: FilledButton.styleFrom(backgroundColor: identityColor),
                          child: const Text("إدخال يدوي"),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
