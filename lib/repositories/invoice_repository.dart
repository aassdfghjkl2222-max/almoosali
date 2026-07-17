import '../core/database/database_service.dart';
import '../models/invoice.dart';
import '../models/invoice_attachment.dart';
import '../models/invoice_audit_log_entry.dart';

/// نصّ خاص يُستخدم كقيمة فلتر "غير مصنَّف" لتصنيف المصروف — لأن null لا
/// يمكن تمريره كقيمة داخل مجموعة Set لاختيار الفلتر في الواجهة.
const String kUnclassifiedInvoiceCategory = '__unclassified__';

/// ملخص إجمالي لمجموعة فواتير (بعد تطبيق الفلاتر الحالية) — يُستخدم في
/// بطاقات الملخص أعلى صفحة الفواتير الضريبية.
class InvoicesSummary {
  final int invoiceCount;
  final double totalAmount;
  final double totalVat;
  final double totalBeforeTax;
  final int supplierCount;
  final Invoice? lastInvoice;

  const InvoicesSummary({
    required this.invoiceCount,
    required this.totalAmount,
    required this.totalVat,
    required this.totalBeforeTax,
    required this.supplierCount,
    required this.lastInvoice,
  });

  factory InvoicesSummary.fromMap(Map<String, dynamic> map) {
    final lastInvoiceMap = map['last_invoice'];
    return InvoicesSummary(
      invoiceCount: (map['invoice_count'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      totalVat: (map['total_vat'] as num?)?.toDouble() ?? 0,
      totalBeforeTax: (map['total_before_tax'] as num?)?.toDouble() ?? 0,
      supplierCount: (map['supplier_count'] as num?)?.toInt() ?? 0,
      lastInvoice: lastInvoiceMap != null ? Invoice.fromMap(Map<String, dynamic>.from(lastInvoiceMap as Map)) : null,
    );
  }
}

class InvoiceRepository {
  final _dbService = DatabaseService();

  Future<List<Invoice>> getAllInvoices(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getInvoices(hotelId);
    return data.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<int> addInvoice(Invoice invoice) async {
    return await _dbService.insertInvoice(invoice.toMap());
  }

  /// يبحث عن فاتورة موجودة مسبقاً لنفس المورد (بالرقم الضريبي) بنفس رقم
  /// الفاتورة — يُستخدم حصراً في مسار الفاتورة القادمة من مسح رمز QR
  /// (ScanInvoiceQrPage) تفادياً لتسجيل نفس الفاتورة مرتين عن طريق الخطأ؛
  /// لا يُستدعى من مسار الإدخال اليدوي العادي.
  Future<Invoice?> findDuplicate({required int hotelId, required String taxNumber, required String invoiceNumber}) async {
    final map = await _dbService.findDuplicateInvoice(hotelId, taxNumber, invoiceNumber);
    if (map == null) return null;
    return Invoice.fromMap(map);
  }

  /// بديل التحقق من التكرار عند غياب رقم الفاتورة (شائع في مسار QR — المعيار
  /// لا يتضمّن رقم الفاتورة أصلاً) — يطابق بالرقم الضريبي + التاريخ + الإجمالي
  /// معاً، وهي البيانات الوحيدة المضمونة من مسح نفس الفاتورة الورقية مرتين.
  Future<Invoice?> findDuplicateByContent({required int hotelId, required String taxNumber, required String date, required double totalAmount}) async {
    final map = await _dbService.findDuplicateInvoiceByContent(hotelId, taxNumber, date, totalAmount);
    if (map == null) return null;
    return Invoice.fromMap(map);
  }

  Future<int> deleteInvoice(int id) async {
    return await _dbService.deleteById('invoices', id);
  }

  Future<int> updateInvoice(Invoice invoice) async {
    if (invoice.id == null) return 0;
    return await _dbService.updateById('invoices', invoice.toMap(), invoice.id!);
  }

  Future<List<Invoice>> getInvoicesBySupplier({
    required int? hotelId,
    required String companyName,
    String? startDate,
    String? endDate,
  }) async {
    if (hotelId == null) return [];
    final data = await _dbService.getInvoicesBySupplier(
      hotelId: hotelId,
      companyName: companyName,
      startDate: startDate,
      endDate: endDate,
    );
    return data.map((map) => Invoice.fromMap(map)).toList();
  }

  /// صفحة واحدة من الفواتير بعد تطبيق كل فلاتر مركز الفواتير الضريبية —
  /// [hotelIds] فارغة/null تعني كل الفنادق. تحميل تدريجي (limit/offset) بدل
  /// تحميل آلاف الفواتير دفعة واحدة.
  Future<List<Invoice>> getInvoicesPagedFiltered({
    List<int>? hotelIds,
    String? startDate,
    String? endDate,
    String? supplierName,
    String? category,
    String? amountSource,
    String? searchQuery,
    String sortKey = 'date_desc',
    required int limit,
    required int offset,
  }) async {
    final data = await _dbService.getInvoicesPagedFiltered(
      hotelIds: hotelIds,
      startDate: startDate,
      endDate: endDate,
      supplierName: supplierName,
      category: category,
      amountSource: amountSource,
      searchQuery: searchQuery,
      sortKey: sortKey,
      limit: limit,
      offset: offset,
    );
    return data.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<InvoicesSummary> getInvoicesSummary({
    List<int>? hotelIds,
    String? startDate,
    String? endDate,
    String? supplierName,
    String? category,
    String? amountSource,
    String? searchQuery,
  }) async {
    final map = await _dbService.getInvoicesSummary(
      hotelIds: hotelIds,
      startDate: startDate,
      endDate: endDate,
      supplierName: supplierName,
      category: category,
      amountSource: amountSource,
      searchQuery: searchQuery,
    );
    return InvoicesSummary.fromMap(map);
  }

  Future<List<String>> getDistinctSuppliers(List<int>? hotelIds) async {
    return await _dbService.getDistinctInvoiceSuppliers(hotelIds);
  }

  Future<List<String>> getDistinctCategories(List<int>? hotelIds) async {
    return await _dbService.getDistinctInvoiceCategories(hotelIds);
  }

  Future<List<String>> getDistinctAmountSources(List<int>? hotelIds) async {
    return await _dbService.getDistinctInvoiceAmountSources(hotelIds);
  }

  /// كل الفواتير المطابقة للفلاتر دفعة واحدة بلا ترقيم صفحات — لأغراض
  /// التقارير/التصدير فقط (حيث يحتاج الملف الناتج كل السجلات معاً)، وليس
  /// لعرضها في قائمة تدريجية.
  Future<List<Invoice>> getAllFilteredInvoicesForReport({
    List<int>? hotelIds,
    String? startDate,
    String? endDate,
    String? supplierName,
    String? category,
    String? amountSource,
  }) async {
    final data = await _dbService.getInvoicesPagedFiltered(
      hotelIds: hotelIds,
      startDate: startDate,
      endDate: endDate,
      supplierName: supplierName,
      category: category,
      amountSource: amountSource,
      sortKey: 'date_desc',
      limit: 100000,
      offset: 0,
    );
    return data.map((map) => Invoice.fromMap(map)).toList();
  }

  // ---------------- المرفقات ----------------

  Future<int> addAttachment(InvoiceAttachment attachment) async {
    return await _dbService.insertInvoiceAttachment(attachment.toMap());
  }

  Future<List<InvoiceAttachment>> getAttachments(int invoiceId) async {
    final data = await _dbService.getInvoiceAttachments(invoiceId);
    return data.map((map) => InvoiceAttachment.fromMap(map)).toList();
  }

  Future<InvoiceAttachment?> getAttachmentById(int id) async {
    final map = await _dbService.getInvoiceAttachmentById(id);
    return map != null ? InvoiceAttachment.fromMap(map) : null;
  }

  Future<int> deleteAttachment(int id) async {
    return await _dbService.deleteById('invoice_attachments', id);
  }

  // ---------------- سجل التعديلات (بلا حذف عمداً) ----------------

  Future<int> logAudit(InvoiceAuditLogEntry entry) async {
    return await _dbService.insertInvoiceAuditLog(entry.toMap());
  }

  Future<List<InvoiceAuditLogEntry>> getAuditLog(int invoiceId) async {
    final data = await _dbService.getInvoiceAuditLog(invoiceId);
    return data.map((map) => InvoiceAuditLogEntry.fromMap(map)).toList();
  }
}
