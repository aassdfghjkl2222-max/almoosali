/// مرفق واحد (صورة أو PDF) مرتبط بمستند. filePath يشير إلى نسخة دائمة داخل
/// تخزين التطبيق (وليس المسار المؤقت الذي يعيده منتقي الصور/الملفات
/// مباشرة) حتى لا يفقد المرفق بعد إفراغ النظام لذاكرة التخزين المؤقت للجهاز.
///
/// [fileType] يُخزَّن كامتداد الملف الفعلي (jpg/jpeg/png/webp/pdf...) وليس
/// فئة عامة ثابتة — هذا ما يجعل دعم امتدادات جديدة مستقبلاً (مثلاً docx)
/// مجرد إضافة قيمة نصية جديدة، دون أي تعديل في قاعدة البيانات أو المعمارية.
/// [isImage]/[isPdf] تتعرّف أيضاً على القيم القديمة العامة ('image'/'pdf')
/// المخزَّنة من نسخة سابقة من التطبيق، فتبقى متوافقة رجوعاً.
class DocumentAttachment {
  static const _imageExtensions = {'image', 'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'};

  final int? id;
  final int documentId;
  final int hotelId;
  final String filePath;
  final String fileType;
  final String fileName;
  final String createdAt;

  const DocumentAttachment({
    this.id,
    required this.documentId,
    required this.hotelId,
    required this.filePath,
    required this.fileType,
    required this.fileName,
    required this.createdAt,
  });

  bool get isPdf => fileType.toLowerCase() == 'pdf';
  bool get isImage => _imageExtensions.contains(fileType.toLowerCase());

  /// يكتشف امتداد الملف الفعلي من مساره/اسمه — يُستخدم بدل تخمين النوع من
  /// زر الاختيار (صورة/PDF) وحده، حتى تُخزَّن قيمة دقيقة قابلة للتوسع.
  static String detectFileType(String pathOrName) {
    final ext = pathOrName.split('.').last.toLowerCase();
    return ext.isEmpty ? 'image' : ext;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_id': documentId,
      'hotel_id': hotelId,
      'file_path': filePath,
      'file_type': fileType,
      'file_name': fileName,
      'created_at': createdAt,
    };
  }

  factory DocumentAttachment.fromMap(Map<String, dynamic> map) {
    return DocumentAttachment(
      id: map['id'] as int?,
      documentId: map['document_id'] as int,
      hotelId: map['hotel_id'] as int,
      filePath: map['file_path'] as String,
      fileType: map['file_type'] as String,
      fileName: map['file_name'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
