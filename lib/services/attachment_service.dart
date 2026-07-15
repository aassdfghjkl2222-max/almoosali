import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// خدمة اختيار ونسخ مرفقات (صور/PDF) إلى تخزين دائم داخل التطبيق — عامة عبر
/// معامل [folder] (افتراضياً `invoice_attachments` للتوافق مع المستدعي
/// الأصلي)، تُستخدم أيضاً لمرفقات المستندات بتمرير `folder: 'document_attachments'`.
///
/// بخلاف النمط المستخدم سابقاً في قسم التسويات (يُخزَّن فيه مسار الملف
/// المؤقت من المنتقي مباشرة)، هذه الخدمة تنسخ كل ملف فعلياً إلى مجلد ثابت
/// داخل مساحة تخزين التطبيق (getApplicationDocumentsDirectory) قبل إرجاع
/// مساره — يضمن بقاء المرفق سليماً حتى لو أفرغ النظام أو تطبيق آخر مجلد
/// الملفات المؤقتة/ذاكرة التخزين المؤقت لاحقاً.
class AttachmentService {
  AttachmentService._();

  static Future<Directory> _attachmentsDir(String folder) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<({String path, String name})?> _copyToPermanentStorage(String sourcePath, String folder) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;
    final dir = await _attachmentsDir(folder);
    final originalName = sourcePath.split(Platform.pathSeparator).last;
    final storedName = '${DateTime.now().millisecondsSinceEpoch}_$originalName';
    final destFile = File('${dir.path}${Platform.pathSeparator}$storedName');
    await sourceFile.copy(destFile.path);
    return (path: destFile.path, name: originalName);
  }

  /// يفتح معرض الصور بوضع الاختيار المتعدد، وينسخ كل صورة مُختارة إلى
  /// تخزين دائم. يعيد قائمة فارغة إن أُلغيت العملية.
  static Future<List<({String path, String name})>> pickImages({String folder = 'invoice_attachments'}) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    final results = <({String path, String name})>[];
    for (final image in images) {
      final saved = await _copyToPermanentStorage(image.path, folder);
      if (saved != null) results.add(saved);
    }
    return results;
  }

  /// يفتح منتقي الملفات مقصوراً على PDF فقط، وينسخ الملف المُختار إلى
  /// تخزين دائم. يعيد null إن أُلغيت العملية.
  static Future<({String path, String name})?> pickPdf({String folder = 'invoice_attachments'}) async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = result?.files.single.path;
    if (path == null) return null;
    return await _copyToPermanentStorage(path, folder);
  }

  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
