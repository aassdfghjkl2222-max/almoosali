/// مرفق واحد (صورة أو PDF) مرتبط بفاتورة ضريبية. filePath يشير إلى نسخة
/// دائمة داخل تخزين التطبيق (وليس المسار المؤقت الذي يعيده منتقي
/// الصور/الملفات مباشرة) حتى لا يفقد المرفق بعد إفراغ النظام لذاكرة التخزين
/// المؤقت للجهاز.
class InvoiceAttachment {
  final int? id;
  final int invoiceId;
  final int hotelId;
  final String filePath;
  final String fileType; // 'image' | 'pdf'
  final String fileName;
  final String createdAt;

  const InvoiceAttachment({
    this.id,
    required this.invoiceId,
    required this.hotelId,
    required this.filePath,
    required this.fileType,
    required this.fileName,
    required this.createdAt,
  });

  bool get isPdf => fileType == 'pdf';
  bool get isImage => fileType == 'image';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'hotel_id': hotelId,
      'file_path': filePath,
      'file_type': fileType,
      'file_name': fileName,
      'created_at': createdAt,
    };
  }

  factory InvoiceAttachment.fromMap(Map<String, dynamic> map) {
    return InvoiceAttachment(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int,
      hotelId: map['hotel_id'] as int,
      filePath: map['file_path'] as String,
      fileType: map['file_type'] as String,
      fileName: map['file_name'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
