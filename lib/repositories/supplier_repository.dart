import '../core/database/database_service.dart';
import '../models/invoice.dart';
import '../models/pending_expense_debt.dart';
import '../models/supplier.dart';
import '../models/supplier_debt.dart';
import '../models/supplier_payment.dart';

/// عنصر واحد ضمن القائمة الزمنية المدمجة في كشف حساب المورد — إما فاتورة
/// (مدين) أو عملية سداد (دائن).
class SupplierStatementEntry {
  final bool isPayment;
  final String date;
  final double amount;
  final String label;
  final Invoice? invoice;
  final SupplierPayment? payment;

  const SupplierStatementEntry({
    required this.isPayment,
    required this.date,
    required this.amount,
    required this.label,
    this.invoice,
    this.payment,
  });
}

/// ملخص كشف حساب مورد واحد: إجماليات + قائمة العمليات كاملة مرتبة زمنياً
/// (الأحدث أولاً).
class SupplierStatement {
  final int invoiceCount;
  final double totalInvoiced;
  final double totalPaid;
  final double totalRemaining;
  final Invoice? lastInvoice;
  final SupplierPayment? lastPayment;
  final List<SupplierStatementEntry> operations;

  const SupplierStatement({
    required this.invoiceCount,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalRemaining,
    required this.lastInvoice,
    required this.lastPayment,
    required this.operations,
  });
}

class SupplierRepository {
  final _dbService = DatabaseService();

  Future<int> addSupplier(Supplier supplier) async {
    return await _dbService.insertSupplier(supplier.toMap());
  }

  Future<Supplier?> getSupplierByOfficialName(int hotelId, String name) async {
    final map = await _dbService.getSupplierByOfficialName(hotelId, name);
    if (map == null) return null;
    return Supplier.fromMap(map);
  }

  /// بحث بالرقم الضريبي — يُستخدم عند تعبئة فاتورة تلقائياً من قراءة تلقائية
  /// (QR غالباً يعطي الرقم الضريبي بدقة، بخلاف اسم المورد الذي قد يختلف شكلاً
  /// بسيطاً عن الاسم الرسمي المحفوظ). راجع QuickInvoiceReviewPage/AddInvoicePage.
  Future<Supplier?> getSupplierByTaxNumber(int hotelId, String taxNumber) async {
    final map = await _dbService.getSupplierByTaxNumber(hotelId, taxNumber);
    if (map == null) return null;
    return Supplier.fromMap(map);
  }

  /// يحدّث تصنيف المصروف الافتراضي لمورد — يُستدعى عند أول ربط لمورد جديد
  /// أو عند تغيير المستخدم للتصنيف يدوياً في شاشة المراجعة السريعة
  /// (QuickInvoiceReviewPage)، حتى تُطبَّق تلقائياً في الفواتير القادمة.
  Future<void> updateDefaultCategory(int supplierId, String category) async {
    await _dbService.updateSupplierCategory(supplierId, category);
  }

  Future<Supplier?> getSupplierById(int id) async {
    final map = await _dbService.getSupplierById(id);
    if (map == null) return null;
    return Supplier.fromMap(map);
  }

  Future<List<Supplier>> searchSuppliers(int hotelId, String query) async {
    final results = await _dbService.searchSuppliers(hotelId, query);
    return results.map((e) => Supplier.fromMap(e)).toList();
  }

  /// عبر كل الفنادق معاً — راجع تعليق DatabaseService.getAllSuppliersAcrossHotels
  /// (البحث الشامل GlobalSearch فقط).
  Future<List<Supplier>> getAllSuppliersAcrossHotels() async {
    final results = await _dbService.getAllSuppliersAcrossHotels();
    return results.map((e) => Supplier.fromMap(e)).toList();
  }

  // ---------------- مديونية "شراء آجل" ----------------

  /// ينشئ مديونية جديدة مرتبطة بالفاتورة إن لم توجد مسبقاً، أو يحدّث مبلغ
  /// المديونية القائمة إن كانت الفاتورة قد عُدِّلت — لا يُنشئ أبداً مديونية
  /// مكرَّرة لنفس invoiceId (invoice_id فريد في قاعدة البيانات).
  Future<void> ensureDebtForInvoice({
    required int hotelId,
    required int supplierId,
    required int invoiceId,
    required double amount,
  }) async {
    final existing = await _dbService.getSupplierDebtByInvoiceId(invoiceId);
    if (existing != null) {
      final existingAmount = (existing['amount'] as num).toDouble();
      if (existingAmount != amount) {
        await _dbService.updateSupplierDebtAmount(existing['id'] as int, amount);
      }
      return;
    }
    await _dbService.insertSupplierDebt(SupplierDebt(
      hotelId: hotelId,
      supplierId: supplierId,
      invoiceId: invoiceId,
      amount: amount,
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());
  }

  /// هل توجد مديونية "شراء آجل" مرتبطة بهذه الفاتورة تحديداً؟ تُستخدم في
  /// معاينة أثر الحذف قبل حذف الفاتورة.
  Future<bool> hasDebtForInvoice(int invoiceId) async {
    final existing = await _dbService.getSupplierDebtByInvoiceId(invoiceId);
    return existing != null;
  }

  Future<List<SupplierDebt>> getDebts(int supplierId) async {
    final rows = await _dbService.getSupplierDebts(supplierId);
    return rows.map((e) => SupplierDebt.fromMap(e)).toList();
  }

  Future<double> getDebtsTotal(int supplierId) async {
    return await _dbService.getSupplierDebtsTotal(supplierId);
  }

  // ---------------- المدفوعات (بنية جاهزة، لا شاشة سداد بعد) ----------------

  Future<List<SupplierPayment>> getPayments(int supplierId) async {
    final rows = await _dbService.getSupplierPayments(supplierId);
    return rows.map((e) => SupplierPayment.fromMap(e)).toList();
  }

  Future<double> getPaymentsTotal(int supplierId) async {
    return await _dbService.getSupplierPaymentsTotal(supplierId);
  }

  // ---------------- مديونية "مصروف معلق آجل" ----------------

  /// ينشئ مديونية جديدة مرتبطة بمصروف معلق إن لم توجد مسبقاً، أو يحدّث
  /// بياناتها (المبلغ/المورد/البيان/تاريخ الاستحقاق) إن كان المصروف قد
  /// عُدِّل قبل ترحيله — لا يُنشئ أبداً مديونية مكرَّرة لنفس pendingExpenseId
  /// (فريد في قاعدة البيانات).
  Future<void> ensureDebtForPendingExpense({
    required int hotelId,
    required int supplierId,
    required int pendingExpenseId,
    required double amount,
    required String statement,
    String? dueDate,
  }) async {
    final existing = await _dbService.getPendingExpenseDebtByPendingExpenseId(pendingExpenseId);
    if (existing != null) {
      await _dbService.updatePendingExpenseDebt(existing['id'] as int, {
        'supplier_id': supplierId,
        'amount': amount,
        'statement': statement,
        'due_date': dueDate,
      });
      return;
    }
    await _dbService.insertPendingExpenseDebt(PendingExpenseDebt(
      hotelId: hotelId,
      supplierId: supplierId,
      pendingExpenseId: pendingExpenseId,
      amount: amount,
      statement: statement,
      dueDate: dueDate,
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());
  }

  /// يحذف مديونية "مصروف معلق آجل" — تُستدعى عند تغيير مصدر تمويل المصروف
  /// بعيداً عن "آجل (دين)" أثناء تعديله قبل الترحيل (حذف المصروف نفسه يكفي
  /// وحده بفضل ON DELETE CASCADE، هذه فقط لحالة التعديل بلا حذف).
  Future<void> deleteDebtForPendingExpense(int pendingExpenseId) async {
    await _dbService.deletePendingExpenseDebtByPendingExpenseId(pendingExpenseId);
  }

  /// إجمالي "الذمم الدائنة" (ديون على المنشأة) لفندق واحد — يجمع مديونيات
  /// الفواتير الآجلة والمصروفات المعلقة الآجلة معاً، ناقص ما سُدِّد. يُستخدم
  /// في بطاقة "الذمم الدائنة" بالمركز المالي.
  Future<double> getAccountsPayableTotal(int hotelId) async {
    return await _dbService.getAccountsPayableTotalForHotel(hotelId);
  }

  /// كل الموردين ذوي رصيد مستحق لفندق معيّن — تفصيل بطاقة "الذمم الدائنة".
  Future<List<Map<String, dynamic>>> getSuppliersWithOutstandingDebt(int hotelId) async {
    return await _dbService.getSuppliersWithOutstandingDebt(hotelId);
  }

  // ---------------- كشف الحساب ----------------

  /// يبني كشف حساب كامل لمورد: الإجماليات المطلوبة + قائمة زمنية مدمجة من
  /// فواتيره وعمليات سداده. [invoices] تُمرَّر من الاستدعاء (عبر
  /// InvoiceRepository.getInvoicesBySupplier) بدل استيراد اعتمادية دائرية هنا.
  Future<SupplierStatement> buildStatement({
    required int supplierId,
    required List<Invoice> invoices,
  }) async {
    final payments = await getPayments(supplierId);
    final totalDebt = await getDebtsTotal(supplierId);
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);

    final operations = <SupplierStatementEntry>[
      ...invoices.map((inv) => SupplierStatementEntry(
            isPayment: false,
            date: inv.date,
            amount: inv.totalAmount,
            label: "فاتورة رقم ${inv.invoiceNumber}",
            invoice: inv,
          )),
      ...payments.map((p) => SupplierStatementEntry(
            isPayment: true,
            date: p.date,
            amount: p.amount,
            label: "سداد",
            payment: p,
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));

    Invoice? lastInvoice;
    for (final inv in invoices) {
      if (lastInvoice == null || inv.date.compareTo(lastInvoice.date) > 0) lastInvoice = inv;
    }
    SupplierPayment? lastPayment = payments.isEmpty ? null : payments.first;

    return SupplierStatement(
      invoiceCount: invoices.length,
      totalInvoiced: invoices.fold<double>(0, (sum, inv) => sum + inv.totalAmount),
      totalPaid: totalPaid,
      totalRemaining: totalDebt - totalPaid,
      lastInvoice: lastInvoice,
      lastPayment: lastPayment,
      operations: operations,
    );
  }
}
