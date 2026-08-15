import 'invoice.dart';

/// اسم المستخدم الافتراضي عندما لا توجد جلسة مستخدم فعلية (وضع PIN وحده بلا
/// تفعيل تعدد المستخدمين — راجع SessionService/PermissionService). نقاط
/// التسجيل الحالية لا تقرأ SessionService.currentUser بعد؛ هذا الثابت يبقى
/// القيمة الافتراضية المعقولة حتى تُربط.
const String kInvoiceAuditDefaultUsername = 'مستخدم النظام';

/// قيد واحد في سجل تعديلات فاتورة — غير قابل للحذف عمداً (لا توجد أي دالة
/// حذف له في DatabaseService/InvoiceRepository ولا أي زر حذف في الواجهة).
/// يبقى موجوداً حتى بعد حذف الفاتورة نفسها.
class InvoiceAuditLogEntry {
  final int? id;
  final int invoiceId;
  final int hotelId;
  final String username;
  final String operationType; // 'create' | 'update' | 'delete'
  final String? changedFields;
  final String occurredAt;

  const InvoiceAuditLogEntry({
    this.id,
    required this.invoiceId,
    required this.hotelId,
    required this.username,
    required this.operationType,
    this.changedFields,
    required this.occurredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'hotel_id': hotelId,
      'username': username,
      'operation_type': operationType,
      'changed_fields': changedFields,
      'occurred_at': occurredAt,
    };
  }

  factory InvoiceAuditLogEntry.fromMap(Map<String, dynamic> map) {
    return InvoiceAuditLogEntry(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int,
      hotelId: map['hotel_id'] as int,
      username: map['username'] as String,
      operationType: map['operation_type'] as String,
      changedFields: map['changed_fields'] as String?,
      occurredAt: map['occurred_at'] as String,
    );
  }

  /// يقارن فاتورتين (قبل/بعد التعديل) ويبني وصفاً نصياً بالحقول التي
  /// تغيّرت فعلياً فقط — يعيد null إن لم يتغيّر شيء (لا يُسجَّل حينها أي
  /// قيد تعديل، تفادياً لتضخيم السجل بلا فائدة).
  static String? describeChanges(Invoice oldInvoice, Invoice newInvoice) {
    final changes = <String>[];
    void compare(String label, Object? oldValue, Object? newValue) {
      if (oldValue != newValue) changes.add("$label: ${oldValue ?? '—'} ← ${newValue ?? '—'}");
    }

    compare("رقم الفاتورة", oldInvoice.invoiceNumber, newInvoice.invoiceNumber);
    compare("التاريخ", oldInvoice.date, newInvoice.date);
    compare("اسم الشركة", oldInvoice.companyName, newInvoice.companyName);
    compare("الرقم الضريبي", oldInvoice.taxNumber, newInvoice.taxNumber);
    compare("المبلغ الإجمالي", oldInvoice.totalAmount, newInvoice.totalAmount);
    compare("تصنيف المصروف", oldInvoice.expenseCategory, newInvoice.expenseCategory);
    compare("مصدر التمويل", oldInvoice.amountSource, newInvoice.amountSource);
    compare("طريقة الدفع", oldInvoice.paymentMethod, newInvoice.paymentMethod);
    compare("الفندق المرتبط", oldInvoice.relatedHotelId, newInvoice.relatedHotelId);

    if (changes.isEmpty) return null;
    return changes.join('\n');
  }
}
