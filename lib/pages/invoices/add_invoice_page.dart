import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/formatters/thousands_separator_formatter.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/expense_category.dart';
import '../../models/hotel.dart';
import '../../models/invoice.dart';
import '../../models/pending_expense.dart';
import '../../models/supplier.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/vault_service.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../widgets/vault/amount_source_selector.dart';

class AddInvoicePage extends StatefulWidget {
  final Hotel hotel;
  final Invoice? invoice;
  const AddInvoicePage({super.key, required this.hotel, this.invoice});

  @override
  State<AddInvoicePage> createState() => _AddInvoicePageState();
}

class _AddInvoicePageState extends State<AddInvoicePage> {
  final _repository = InvoiceRepository();
  final _supplierRepository = SupplierRepository();
  final _expenseRepository = ExpenseRepository();
  final _vaultService = VaultService();

  final _invoiceNumberController = TextEditingController();
  final _dateController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _amountBeforeTaxController = TextEditingController();
  final _vatController = TextEditingController();
  final _totalAmountController = TextEditingController();

  final _saveButtonFocusNode = FocusNode();

  bool _isLoading = false;
  String? _taxNumberError;
  String _amountSource = "نقد";
  bool? _shouldTransfer = true;
  String? _paymentMethod = "نقد";

  List<Supplier> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (widget.invoice != null) {
      final inv = widget.invoice!;
      _invoiceNumberController.text = inv.invoiceNumber;
      _dateController.text = inv.date;
      _companyNameController.text = inv.companyName;
      _taxNumberController.text = inv.taxNumber;
      _amountBeforeTaxController.text = NumberFormat("#,##0.##").format(inv.amountBeforeTax);
      _vatController.text = NumberFormat("#,##0.00").format(inv.vat);
      _totalAmountController.text = NumberFormat("#,##0.00").format(inv.totalAmount);

      final supplier = await _supplierRepository.getSupplierByOfficialName(widget.hotel.id!, inv.companyName);
      if (supplier != null) {
        _shortNameController.text = supplier.shortName;
      }
      return;
    }

    final now = DateTime.now();
    _dateController.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final invoices = await _repository.getAllInvoices(widget.hotel.id!);
    _invoiceNumberController.text = (invoices.length + 1).toString();
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _dateController.dispose();
    _companyNameController.dispose();
    _shortNameController.dispose();
    _taxNumberController.dispose();
    _amountBeforeTaxController.dispose();
    _vatController.dispose();
    _totalAmountController.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final beforeTax = ThousandsSeparatorInputFormatter.parse(_amountBeforeTaxController.text) ?? 0;
    final vat = beforeTax * 0.15;
    final total = beforeTax + vat;

    final fmt = NumberFormat("#,##0.00");
    _vatController.text = fmt.format(vat);
    _totalAmountController.text = fmt.format(total);
  }

  void _validateTaxNumber(String value) {
    if (value.isNotEmpty && value.length != 15) {
      setState(() => _taxNumberError = "الرقم الضريبي يجب أن يكون 15 رقماً");
    } else {
      setState(() => _taxNumberError = null);
    }
  }

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final results = await _supplierRepository.searchSuppliers(widget.hotel.id!, query);
    setState(() {
      _searchResults = results;
      _showSearchResults = results.isNotEmpty;
    });
  }

  Future<void> _saveInvoice() async {
    _validateTaxNumber(_taxNumberController.text);

    if (_invoiceNumberController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _companyNameController.text.isEmpty ||
        _taxNumberController.text.isEmpty ||
        _taxNumberError != null ||
        _amountBeforeTaxController.text.isEmpty ||
        _vatController.text.isEmpty ||
        _totalAmountController.text.isEmpty ||
        _paymentMethod == null ||
        _shouldTransfer == null) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يرجى ملء جميع الحقول المطلوبة"),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: widget.invoice != null ? "تأكيد التعديل" : "تأكيد الحفظ",
      message: widget.invoice != null
          ? "هل تريد حفظ التعديلات على هذه الفاتورة؟"
          : "هل تريد حفظ هذه الفاتورة؟",
      onConfirm: _performSaveInvoice,
    );
  }

  Future<void> _performSaveInvoice() async {
    setState(() => _isLoading = true);

    try {
      final officialName = _companyNameController.text.trim();
      final existingSupplier = await _supplierRepository.getSupplierByOfficialName(widget.hotel.id!, officialName);
      
      if (existingSupplier == null) {
        final newSupplier = Supplier(
          hotelId: widget.hotel.id!,
          officialName: officialName,
          shortName: _shortNameController.text.trim().isEmpty 
              ? officialName 
              : _shortNameController.text.trim(),
          taxNumber: _taxNumberController.text.trim(),
        );
        await _supplierRepository.addSupplier(newSupplier);
      }

      final totalAmount = ThousandsSeparatorInputFormatter.parse(_totalAmountController.text) ?? 0;

      final invoice = Invoice(
        id: widget.invoice?.id,
        hotelId: widget.hotel.id!,
        invoiceNumber: _invoiceNumberController.text,
        date: _dateController.text,
        companyName: _companyNameController.text,
        taxNumber: _taxNumberController.text,
        amountBeforeTax: ThousandsSeparatorInputFormatter.parse(_amountBeforeTaxController.text) ?? 0,
        vat: ThousandsSeparatorInputFormatter.parse(_vatController.text) ?? 0,
        totalAmount: totalAmount,
        facilityName: widget.hotel.arabicName,
        amountSource: _amountSource,
      );

      if (!mounted) return;
      final confirmed = await _vaultService.checkBalanceAndConfirm(
        context: context,
        hotelId: widget.hotel.id!,
        amount: invoice.totalAmount,
        source: _amountSource,
      );

      if (!confirmed) {
        setState(() => _isLoading = false);
        return;
      }

      if (widget.invoice != null) {
        await _repository.updateInvoice(invoice);
      } else {
        await _repository.addInvoice(invoice);
        
        if (mounted) {
          await _vaultService.processVaultTransaction(
            context: context,
            hotelId: widget.hotel.id!,
            amount: invoice.totalAmount,
            source: _amountSource,
            type: "فاتورة: ${invoice.companyName}",
            reference: "رقم الفاتورة: ${invoice.invoiceNumber}",
          );
        }

        if (_shouldTransfer == true) {
          final categories = await _expenseRepository.getCategories(widget.hotel.id!);
          final purchaseCategory = categories.firstWhere(
            (c) => c.name == "مشتريات",
            orElse: () => categories.isNotEmpty ? categories.first : ExpenseCategory(
              name: "مشتريات",
              iconCode: Icons.shopping_cart.codePoint,
              colorValue: Colors.blue.value,
              createdAt: DateTime.now().toIso8601String(),
            ),
          );

          await _expenseRepository.addPendingExpense(PendingExpense(
            hotelId: widget.hotel.id!,
            amount: invoice.totalAmount,
            paymentMethod: _paymentMethod!,
            categoryId: purchaseCategory.id ?? 1,
            statement: "فاتورة مشتريات من ${invoice.companyName}",
            date: invoice.date,
            time: DateFormat('HH:mm').format(DateTime.now()),
            amountSource: _amountSource,
            createdAt: DateTime.now().toIso8601String(),
          ));
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ أثناء الحفظ: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(
          title: widget.invoice != null ? "تعديل الفاتورة" : "إضافة فاتورة",
          hotel: widget.hotel,
        ),
        centerTitle: true,
        backgroundColor: identityColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            _buildGeneralInfoSection(identityColor),
            const SizedBox(height: AppSizes.md),
            _buildAmountSection(identityColor),
            const SizedBox(height: AppSizes.md),
            _buildTransferSection(identityColor),
            const SizedBox(height: AppSizes.xl),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: identityColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("حفظ الفاتورة", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralInfoSection(Color identityColor) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _invoiceNumberController,
                  hint: "رقم الفاتورة",
                  icon: Icons.tag,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: AppTextField(
                  controller: _dateController,
                  hint: "التاريخ",
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _dateController.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Stack(
            children: [
              AppTextField(
                controller: _companyNameController,
                hint: "اسم الشركة / المورد",
                icon: Icons.business,
                onChanged: _onSearchChanged,
              ),
              if (_showSearchResults)
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _searchResults.map((s) => ListTile(
                        title: Text(s.officialName),
                        subtitle: Text(s.taxNumber),
                        onTap: () {
                          setState(() {
                            _companyNameController.text = s.officialName;
                            _shortNameController.text = s.shortName;
                            _taxNumberController.text = s.taxNumber;
                            _showSearchResults = false;
                          });
                        },
                      )).toList(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _taxNumberController,
            hint: "الرقم الضريبي",
            icon: Icons.receipt,
            keyboardType: TextInputType.number,
            onChanged: _validateTaxNumber,
          ),
          if (_taxNumberError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 12),
              child: Text(_taxNumberError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountSection(Color identityColor) {
    return AppCard(
      child: Column(
        children: [
          AppTextField(
            controller: _amountBeforeTaxController,
            hint: "المبلغ قبل الضريبة",
            icon: Icons.attach_money,
            formatThousands: true,
            onChanged: (_) => _calculateTotal(),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _vatController,
                  hint: "الضريبة (15%)",
                  icon: Icons.percent,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: AppTextField(
                  controller: _totalAmountController,
                  hint: "الإجمالي",
                  icon: Icons.account_balance_wallet,
                  readOnly: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferSection(Color identityColor) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("جهة الصرف", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          AmountSourceSelector(
            selectedSource: _amountSource,
            onSourceChanged: (val) => setState(() => _amountSource = val),
          ),
          const Divider(height: AppSizes.lg),
          Row(
            children: [
              Checkbox(
                value: _shouldTransfer,
                activeColor: identityColor,
                onChanged: (val) => setState(() => _shouldTransfer = val),
              ),
              const Expanded(
                child: Text("ترحيل الفاتورة تلقائياً إلى المصروفات المعلقة"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
