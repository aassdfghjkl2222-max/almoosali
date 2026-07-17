import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/expense_category.dart';
import '../../models/hotel.dart';
import '../../models/invoice.dart';
import '../../models/invoice_audit_log_entry.dart';
import '../../models/supplier.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/zatca_qr_parser.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/hotel_identity_title.dart';
import 'add_invoice_page.dart';

/// شاشة مراجعة سريعة بعد نجاح مسح رمز QR — بديل فتح AddInvoicePage الكاملة
/// مباشرة (لا يزال متاحاً عبر زر "تعديل"). تعرض فقط البيانات المستخرَجة
/// للقراءة + اختيار مصدر التمويل والتصنيف (يُختار تلقائياً للموردين
/// المعروفين)، وزر تأكيد واحد يحفظ فوراً بلا أي حوار تأكيد إضافي — الشاشة
/// نفسها هي التأكيد.
class QuickInvoiceReviewPage extends StatefulWidget {
  final Hotel hotel;
  final ZatcaInvoiceData qrData;
  const QuickInvoiceReviewPage({super.key, required this.hotel, required this.qrData});

  @override
  State<QuickInvoiceReviewPage> createState() => _QuickInvoiceReviewPageState();
}

class _QuickInvoiceReviewPageState extends State<QuickInvoiceReviewPage> {
  final _supplierRepository = SupplierRepository();
  final _invoiceRepository = InvoiceRepository();
  final _expenseRepository = ExpenseRepository();
  final _hotelRepository = HotelRepository();

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  bool _isLoading = true;
  bool _isSaving = false;

  Supplier? _matchedSupplier;
  List<ExpenseCategory> _categories = [];
  String? _selectedCategory;

  String? _fundingSource;
  String? _paymentMethod;
  int? _relatedHotelId;
  List<Hotel> _otherHotels = [];

  DateTime get _invoiceDate => widget.qrData.timestamp ?? DateTime.now();
  String get _invoiceDateStr => DateFormat('yyyy-MM-dd').format(_invoiceDate);

  FundingSourceOption? get _selectedFundingOption {
    if (_fundingSource == null) return null;
    for (final option in kInvoiceFundingSources) {
      if (option.label == _fundingSource) return option;
    }
    return null;
  }

  bool get _fundingSourceReady {
    final option = _selectedFundingOption;
    if (option == null) return false;
    if (option.needsHotel && _relatedHotelId == null) return false;
    if (option.hasPaymentMethod && _paymentMethod == null) return false;
    return true;
  }

  bool get _canConfirm =>
      !_isLoading && widget.qrData.invoiceTotal != null && widget.qrData.vatNumber != null && _selectedCategory != null && _fundingSourceReady;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final allHotels = await _hotelRepository.getAllHotels();
    _otherHotels = allHotels.where((h) => h.id != widget.hotel.id).toList();
    _categories = await _expenseRepository.getCategories();

    final vatNumber = widget.qrData.vatNumber;
    if (vatNumber != null) {
      _matchedSupplier = await _supplierRepository.getSupplierByTaxNumber(widget.hotel.id!, vatNumber);
      if (_matchedSupplier?.defaultExpenseCategory != null) {
        _selectedCategory = _matchedSupplier!.defaultExpenseCategory;
      }
    }

    if (mounted) setState(() => _isLoading = false);
    await _checkDuplicate();
  }

  /// يتحقق فور نجاح المسح (قبل أي تفاعل) بتوقيع محتوى الفاتورة — رقم
  /// الفاتورة غائب عن معيار QR أصلاً، فالمطابقة تتم بالرقم الضريبي + التاريخ
  /// + الإجمالي معاً. تحذير غير مانع: "متابعة" تُبقي الشاشة، "إلغاء" تُغلقها.
  Future<void> _checkDuplicate() async {
    final taxNumber = widget.qrData.vatNumber;
    final total = widget.qrData.invoiceTotal;
    if (taxNumber == null || total == null || !mounted) return;

    final duplicate = await _invoiceRepository.findDuplicateByContent(
      hotelId: widget.hotel.id!,
      taxNumber: taxNumber,
      date: _invoiceDateStr,
      totalAmount: total,
    );
    if (duplicate == null || !mounted) return;

    bool proceed = false;
    await AppDialog.confirmAction(
      context: context,
      title: "فاتورة مكرَّرة",
      message: "هذه الفاتورة مسجلة مسبقاً، هل تريد المتابعة؟",
      confirmLabel: "متابعة",
      onConfirm: () async => proceed = true,
    );
    if (!proceed && mounted) Navigator.pop(context);
  }

  void _openFullEdit() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AddInvoicePage(hotel: widget.hotel, qrPrefill: widget.qrData)));
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _isSaving = true);
    try {
      final taxNumber = widget.qrData.vatNumber!;
      final sellerName = widget.qrData.sellerName ?? '';
      final selectedCategory = _selectedCategory!;

      int supplierId;
      if (_matchedSupplier != null) {
        supplierId = _matchedSupplier!.id!;
        if (_matchedSupplier!.defaultExpenseCategory != selectedCategory) {
          await _supplierRepository.updateDefaultCategory(supplierId, selectedCategory);
        }
      } else {
        supplierId = await _supplierRepository.addSupplier(Supplier(
          hotelId: widget.hotel.id!,
          officialName: sellerName,
          shortName: '',
          taxNumber: taxNumber,
          defaultExpenseCategory: selectedCategory,
        ));
      }

      final total = widget.qrData.invoiceTotal!;
      // مبلغ ضريبة تقريبي (15%) فقط إن غاب تحديداً عن الرمز رغم توفر الإجمالي —
      // نفس نسبة التقريب المستخدَمة في الإدخال اليدوي القياسي.
      final vat = widget.qrData.vatTotal ?? double.parse((total - total / 1.15).toStringAsFixed(2));
      final beforeTax = double.parse((total - vat).toStringAsFixed(2));

      final invoice = Invoice(
        hotelId: widget.hotel.id!,
        invoiceNumber: '',
        date: _invoiceDateStr,
        companyName: sellerName,
        taxNumber: taxNumber,
        amountBeforeTax: beforeTax,
        vat: vat,
        totalAmount: total,
        facilityName: widget.hotel.arabicName,
        expenseCategory: selectedCategory,
        amountSource: _fundingSource!,
        paymentMethod: _paymentMethod,
        relatedHotelId: _relatedHotelId,
      );

      final invoiceId = await _invoiceRepository.addInvoice(invoice);

      if (_selectedFundingOption != null && !_selectedFundingOption!.hasPaymentMethod) {
        await _supplierRepository.ensureDebtForInvoice(
          hotelId: widget.hotel.id!,
          supplierId: supplierId,
          invoiceId: invoiceId,
          amount: total,
        );
      }

      await _invoiceRepository.logAudit(InvoiceAuditLogEntry(
        invoiceId: invoiceId,
        hotelId: widget.hotel.id!,
        username: kInvoiceAuditDefaultUsername,
        operationType: 'create',
        changedFields: null,
        occurredAt: DateTime.now().toIso8601String(),
      ));

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "مراجعة الفاتورة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.qrData.invoiceTotal == null || widget.qrData.vatNumber == null) _buildMissingDataNotice(),
                  _buildSummaryCard(),
                  const SizedBox(height: AppSizes.md),
                  _buildCategorySection(),
                  const SizedBox(height: AppSizes.md),
                  _buildFundingSourceSection(),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading ? null : _buildActionButtons(),
    );
  }

  Widget _buildMissingDataNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "الرقم الضريبي أو المبلغ غير موجودين داخل هذا الرمز — استخدم \"تعديل\" لإكمال البيانات يدوياً",
              style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final fmt = NumberFormat("#,##0.00");
    return AppCard(
      child: Column(
        children: [
          _summaryRow("🏢", "المورد", _matchedSupplier?.officialName ?? widget.qrData.sellerName ?? "—"),
          const Divider(height: 20),
          _summaryRow("🧾", "الرقم الضريبي", widget.qrData.vatNumber ?? "—"),
          const Divider(height: 20),
          _summaryRow("📅", "تاريخ الفاتورة", _invoiceDateStr),
          const Divider(height: 20),
          _summaryRow("💰", "الإجمالي", widget.qrData.invoiceTotal != null ? "${fmt.format(widget.qrData.invoiceTotal)} ريال" : "—"),
        ],
      ),
    );
  }

  Widget _summaryRow(String icon, String label, String value) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyles.caption)),
        Flexible(
          child: Text(value, style: AppTextStyles.bodyBold, textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("تصنيف المصروف", style: AppTextStyles.bodyBold),
          if (_matchedSupplier?.defaultExpenseCategory != null) ...[
            const SizedBox(height: 4),
            Text("اختير تلقائياً حسب هذا المورد — يمكنك تغييره", style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category.name;
              return ChoiceChip(
                label: Text(category.name, style: const TextStyle(fontSize: 12)),
                avatar: Icon(IconData(category.iconCode, fontFamily: 'MaterialIcons'), size: 16, color: isSelected ? Colors.white : _identityColor),
                selected: isSelected,
                selectedColor: _identityColor,
                labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.bold : null),
                onSelected: (_) => setState(() => _selectedCategory = category.name),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFundingSourceSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("مصدر التمويل", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kInvoiceFundingSources.map((option) {
              final isSelected = _fundingSource == option.label;
              return ChoiceChip(
                label: Text(option.label, style: const TextStyle(fontSize: 12)),
                avatar: Icon(option.icon, size: 16, color: isSelected ? Colors.white : option.color),
                selected: isSelected,
                selectedColor: option.color,
                labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.bold : null),
                onSelected: (_) => setState(() {
                  _fundingSource = option.label;
                  _paymentMethod = null;
                  _relatedHotelId = null;
                }),
              );
            }).toList(),
          ),
          if (_selectedFundingOption?.needsHotel == true) ...[
            const SizedBox(height: AppSizes.md),
            Text("اختر الفندق", style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSizes.sm),
            _otherHotels.isEmpty
                ? const Text("لا يوجد فندق آخر مسجَّل في النظام", style: AppTextStyles.caption)
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _otherHotels.map((h) {
                      final isSelected = _relatedHotelId == h.id;
                      return ChoiceChip(
                        label: Text(h.arabicName, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: _selectedFundingOption!.color,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.bold : null),
                        onSelected: (_) => setState(() => _relatedHotelId = h.id),
                      );
                    }).toList(),
                  ),
          ],
          if (_selectedFundingOption?.hasPaymentMethod == true) ...[
            const SizedBox(height: AppSizes.md),
            Text("طريقة الدفع", style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kInvoicePaymentMethods.map((method) {
                final isSelected = _paymentMethod == method;
                return ChoiceChip(
                  label: Text(method, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  selectedColor: _selectedFundingOption!.color,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.bold : null),
                  onSelected: (_) => setState(() => _paymentMethod = method),
                );
              }).toList(),
            ),
          ],
          if (_selectedFundingOption != null && !_selectedFundingOption!.hasPaymentMethod) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(color: _selectedFundingOption!.color.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: _selectedFundingOption!.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "سيُسجَّل هذا المبلغ ديناً على الفندق لصالح المورد (لم يُدفع بعد).",
                      style: TextStyle(fontSize: 11, color: _selectedFundingOption!.color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _openFullEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text("✏️ تعديل"),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: (_isSaving || !_canConfirm) ? null : _confirm,
                style: FilledButton.styleFrom(backgroundColor: _identityColor),
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: const Text("✅ تأكيد"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
