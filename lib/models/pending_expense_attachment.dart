/// مرفق واحد (صورة أو PDF) مرتبط بمصروف معلق — نفس بنية [InvoiceAttachment]
/// حرفياً، بمفتاح مصروف معلق بدل فاتورة.
class PendingExpenseAttachment {
  final int? id;
  final int pendingExpenseId;
  final int hotelId;
  final String filePath;
  final String fileType; // 'image' | 'pdf'
  final String fileName;
  final String createdAt;

  const PendingExpenseAttachment({
    this.id,
    required this.pendingExpenseId,
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
      'pending_expense_id': pendingExpenseId,
      'hotel_id': hotelId,
      'file_path': filePath,
      'file_type': fileType,
      'file_name': fileName,
      'created_at': createdAt,
    };
  }

  factory PendingExpenseAttachment.fromMap(Map<String, dynamic> map) {
    return PendingExpenseAttachment(
      id: map['id'] as int?,
      pendingExpenseId: map['pending_expense_id'] as int,
      hotelId: map['hotel_id'] as int,
      filePath: map['file_path'] as String,
      fileType: map['file_type'] as String,
      fileName: map['file_name'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
