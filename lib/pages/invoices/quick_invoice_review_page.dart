import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/expense_category.dart';
import '../../models/extracted_invoice_data.dart';
import '../../models/hotel.dart';
import '../../models/invoice.dart';
import '../../models/invoice_audit_log_entry.dart';
import '../../models/supplier.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/hotel_identity_title.dart';
import 'add_invoice_page.dart';

/// شاشة مراجعة سريعة بعد نجاح القراءة (QR أو ذكاء اصطناعي أو OCR محلي) —
/// بديل فتح AddInvoicePage الكاملة مباشرة (لا يزال متاحاً عبر زر "تعديل").
/// تعرض فقط اسم المورد + المبلغ + اختيار مصدر التمويل والتصنيف (يُختار
/// تلقائياً للموردين المعروفين)، وزر تأكيد واحد يحفظ فوراً بلا أي حوار
/// تأكيد إضافي — الشاشة نفسها هي التأكيد.
class QuickInvoiceReviewPage extends StatefulWidget {
  final Hotel hotel;
  final ExtractedInvoiceData extractedData;
  const QuickInvoiceReviewPage({super.key, required this.hotel, required this.extractedData});

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

  DateTime get _invoiceDate => widget.extractedData.timestamp ?? DateTime.now();
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
      !_isLoading &&
      widget.extractedData.invoiceTotal != null &&
      widget.extractedData.vatNumber != null &&
      _selectedCategory != null &&
      _fundingSourceReady;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final allHotels = await _hotelRepository.getAllHotels();
    _otherHotels = allHotels.where((h) => h.id != widget.hotel.id).toList();
    _categories = await _expenseRepository.getCategories();

    final vatNumber = widget.extractedData.vatNumber;
    if (vatNumber != null) {
      _matchedSupplier = await _supplierRepository.getSupplierByTaxNumber(widget.hotel.id!, vatNumber);
      if (_matchedSupplier?.defaultExpenseCategory != null) {
        _selectedCategory = _matchedSupplier!.defaultExpenseCategory;
      }
    }

    if (mounted) setState(() => _isLoading = false);
    await _checkDuplicate();
  }

  /// يتحقق فور نجاح القراءة (قبل أي تفاعل) — يعتمد على أكثر من عنصر معاً:
  /// رقم الفاتورة (إن استُخرِج) + الرقم الضريبي، وأيضاً الرقم الضريبي +
  /// التاريخ + الإجمالي (بديل ضروري لأن QR لا يتضمّن رقم الفاتورة أصلاً).
  /// تطابق في أي من الفحصين يُظهر تحذيراً غير مانع: "متابعة" تُبقي الشاشة،
  /// "إلغاء" تُغلقها.
  Future<void> _checkDuplicate() async {
    final taxNumber = widget.extractedData.vatNumber;
    final total = widget.extractedData.invoiceTotal;
    final invoiceNumber = widget.extractedData.invoiceNumber;
    if (taxNumber == null || !mounted) return;

    Invoice? duplicate;
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      duplicate = await _invoiceRepository.findDuplicate(hotelId: widget.hotel.id!, taxNumber: taxNumber, invoiceNumber: invoiceNumber);
    }
    if (duplicate == null && total != null) {
      duplicate = await _invoiceRepository.findDuplicateByContent(
        hotelId: widget.hotel.id!,
        taxNumber: taxNumber,
        date: _invoiceDateStr,
        totalAmount: total,
      );
    }
    if (duplicate == null || !mounted) return;

    bool proceed = false;
    await AppDialog.confirmAction(
      context: context,
      title: "فاتورة مكرَّرة",
      message: "يبدو أن هذه الفاتورة موجودة مسبقاً.",
      confirmLabel: "متابعة رغم ذلك",
      cancelLabel: "إلغاء",
      onConfirm: () async => proceed = true,
    );
    if (!proceed && mounted) Navigator.pop(context);
  }

  /// Navigator.push (وليس pushReplacement) عمداً — راجع التعليق المطابق في
  /// InvoiceCaptureProcessingPage._finishWithResults لسبب أهمية هذا الفرق.
  Future<void> _openFullEdit() async {
    final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddInvoicePage(hotel: widget.hotel, extractedPrefill: widget.extractedData)));
    if (mounted) Navigator.pop(context, saved == true);
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _isSaving = true);
    try {
      final taxNumber = widget.extractedData.vatNumber!;
      final sellerName = widget.extractedData.sellerName ?? '';
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

      final total = widget.extractedData.invoiceTotal!;
      // مبلغ ضريبة تقريبي (15%) فقط إن غاب تحديداً عن القراءة رغم توفر
      // الإجمالي — نفس نسبة التقريب المستخدَمة في الإدخال اليدوي القياسي.
      final vat = widget.extractedData.vatTotal ?? double.parse((total - total / 1.15).toStringAsFixed(2));
      final beforeTax = double.parse((total - vat).toStringAsFixed(2));

      final invoice = Invoice(
        hotelId: widget.hotel.id!,
        invoiceNumber: widget.extractedData.invoiceNumber ?? '',
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
                  if (widget.extractedData.source == InvoiceExtractionSource.localOcr) _buildLowAccuracyNotice(),
                  if (widget.extractedData.invoiceTotal == null || widget.extractedData.vatNumber == null) _buildMissingDataNotice(),
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

  Widget _buildLowAccuracyNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "تعذّر الاتصال بالإنترنت — تمت القراءة محلياً وقد تكون دقتها أقل. راجع البيانات جيداً قبل التأكيد.",
              style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
              "الرقم الضريبي أو المبلغ غير موجودين — استخدم \"تعديل\" لإكمال البيانات يدوياً",
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
          _summaryRow("🏢", "المورد", _matchedSupplier?.officialName ?? widget.extractedData.sellerName ?? "—"),
          const Divider(height: 20),
          _summaryRow("💰", "المبلغ", widget.extractedData.invoiceTotal != null ? "${fmt.format(widget.extractedData.invoiceTotal)} ريال" : "—"),
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
