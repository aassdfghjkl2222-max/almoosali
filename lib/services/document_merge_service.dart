import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/document.dart';
import '../models/document_attachment.dart';
import '../repositories/document_repository.dart';

/// يدمج مرفقات عدة مستندات في ملف PDF واحد — **بترتيب المستندات كما اختارها
/// المستخدم بالضبط** (وليس بالاسم/التاريخ/أي ترتيب تلقائي). كل مرفق يصبح
/// صفحة كاملة صورة: مرفق صورة يُضاف كما هو، ومرفق PDF تُرقَّم كل صفحاته
/// (Printing.raster، نفس الأسلوب المستخدم لقراءة PDF الفواتير) وتُضاف كل
/// صفحة كصورة مستقلة. **حد واقعي مُفصَح عنه**: هذا ترقيم بصري وليس دمجاً
/// متجهياً حقيقياً — نص أي PDF مصدر داخل الملف الناتج لن يبقى قابلاً للنسخ،
/// لأن حزمة `pdf` المستخدمة في المشروع كاتبة فقط ولا تدعم نسخ صفحات PDF
/// موجودة كائناً حياً. لا يُنشئ أي سجل مستند جديد — الناتج مؤقت للمشاركة/الحفظ فقط.
class DocumentMergeService {
  DocumentMergeService._();

  static Future<Uint8List> mergeDocuments(List<Document> documentsInUserOrder, DocumentRepository repository) async {
    final pdf = pw.Document();

    for (final document in documentsInUserOrder) {
      if (document.id == null) continue;
      final attachments = await repository.getAttachments(document.id!);
      for (final attachment in attachments) {
        await _addAttachmentPages(pdf, attachment);
      }
    }

    return pdf.save();
  }

  static Future<void> _addAttachmentPages(pw.Document pdf, DocumentAttachment attachment) async {
    final file = File(attachment.filePath);
    if (!await file.exists()) return;

    if (attachment.isPdf) {
      final bytes = await file.readAsBytes();
      await for (final page in Printing.raster(bytes, dpi: 150)) {
        final pageBytes = await page.toPng();
        _addImagePage(pdf, pageBytes);
      }
    } else {
      final bytes = await file.readAsBytes();
      _addImagePage(pdf, bytes);
    }
  }

  static void _addImagePage(pw.Document pdf, Uint8List imageBytes) {
    final image = pw.MemoryImage(imageBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
}
