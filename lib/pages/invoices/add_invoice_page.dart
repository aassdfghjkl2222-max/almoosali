import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/formatters/thousands_separator_formatter.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/financial_category.dart';
import '../../models/extracted_invoice_data.dart';
import '../../models/hotel.dart';
import '../../models/invoice.dart';
import '../../models/invoice_audit_log_entry.dart';
import '../../models/supplier.dart';
import '../../repositories/financial_category_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/hotel_identity_title.dart';

/// وصف مصدر تمويل واحد ضمن الخمسة الأساسية. hasPaymentMethod=false تعني
/// عدم وجود طريقة دفع (حالة "شراء آجل" فقط — المبلغ لم يُدفع بعد).
class FundingSourceOption {
  final String label;
  final IconData icon;
  final Color color;
  final bool hasPaymentMethod;
  final bool needsHotel;
  const FundingSourceOption(this.label, this.icon, this.color, {this.hasPaymentMethod = true, this.needsHotel = false});
}

const List<FundingSourceOption> kInvoiceFundingSources = [
  FundingSourceOption('خزنة الفندق', Icons.account_balance_wallet_outlined, Color(0xFF2E7D32)),
  FundingSourceOption('المالك', Icons.person_outline, Color(0xFF1565C0)),
  FundingSourceOption('منشأة أخرى', Icons.apartment_outlined, Color(0xFFEF6C00), needsHotel: true),
  FundingSourceOption('مصروف خاص', Icons.card_giftcard_outlined, Color(0xFF6A1B9A)),
  FundingSourceOption('شراء آجل (مورد)', Icons.schedule_outlined, Color(0xFFC62828), hasPaymentMethod: false),
];

const List<String> kInvoicePaymentMethods = ['نقد', 'شبكة', 'دفع جزئي'];

/// شاشة إدخال فاتورة ضريبية سريعة جداً، مُحسَّنة لإدخال عشرات الفواتير
/// يومياً بأقل عدد لمسات ممكن: بحث فوري عن المورد → تعبئة تلقائية أو حفظ
/// مورد جديد → تصنيف المصروف ومصدر التمويل عبر أزرار سريعة → مبلغ إجمالي
/// واحد تُحسب منه الضريبة تلقائياً → حفظ وإعادة الاستعداد فوراً لإدخال
/// الفاتورة التالية، بالتنقل بين حقول النص عبر Enter/التالي بلا حاجة للمس
/// الشاشة.
///
/// مصدر التمويل هنا بنية بيانات أساسية فقط (يُحفَظ على الفاتورة) — لا يُنشئ
/// أي قيد فعلي في الخزنة (VaultService) ولا سجل دين/علاقة فعلي في
/// entity_loans عند اختيار "منشأة أخرى"؛ ذلك الربط المالي الكامل مؤجَّل
/// عمداً لمهمة قادمة. وضع "تعديل فاتورة" (القادم من تفاصيل الفاتورة) يبقى
/// مدعوماً بنفس الشاشة لتفادي إنشاء ملف مكرر.
class AddInvoicePage extends StatefulWidget {
  final Hotel hotel;
  final Invoice? invoice;

  /// بيانات مُستخرَجة (QR أو ذكاء اصطناعي سحابي أو OCR محلي — راجع
  /// InvoiceCaptureProcessingPage) — عند توفرها (ووضع الإضافة فقط، ليس
  /// التعديل) تُعبَّأ الحقول المتاحة تلقائياً في _bootstrap. لا تأثير لها
  /// إطلاقاً على مسار الإدخال اليدوي العادي عندما تكون null (الحالة الافتراضية).
  final ExtractedInvoiceData? extractedPrefill;

  const AddInvoicePage({super.key, required this.hotel, this.invoice, this.extractedPrefill});

  @override
  State<AddInvoicePage> createState() => _AddInvoicePageState();
}

class _AddInvoicePageState extends State<AddInvoicePage> {
  final _invoiceRepository = InvoiceRepository();
  final _supplierRepository = SupplierRepository();
  final _hotelRepository = HotelRepository();
  final _categoryRepository = FinancialCategoryRepository();

  final _invoiceNumberController = TextEditingController();
  final _dateController = TextEditingController();
  final _companySearchController = TextEditingController();
  final _officialNameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();

  final _companySearchFocus = FocusNode();
  final _officialNameFocus = FocusNode();
  final _shortNameFocus = FocusNode();
  final _taxNumberFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _amountFocus = FocusNode();

  bool get _isEditMode => widget.invoice != null;
  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  DateTime _selectedDate = DateTime.now();

  List<Supplier> _searchResults = [];
  bool _isSearching = false;
  Supplier? _selectedSupplier;
  bool _isNewSupplierFlow = false;
  bool _supplierConfirmed = false;
  String? _taxNumberError;

  double? _computedVat;
  double? _computedBeforeTax;

  List<FinancialCategory> _categories = [];
  String? _selectedCategory;
  String? _fundingSource;
  String? _paymentMethod;
  int? _relatedHotelId;
  List<Hotel> _otherHotels = [];

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

  bool get _readyForAmount => _supplierConfirmed && _selectedCategory != null && _fundingSourceReady;

  /// يقفز بالمؤشر تلقائياً إلى حقل المبلغ فور اكتمال التصنيف ومصدر
  /// التمويل — يُستدعى بعد أي اختيار قد يُكمل الجاهزية (تصنيف/طريقة دفع/
  /// فندق)، فيوفّر لمسة يدوية إضافية على المستخدم في الحالة الشائعة.
  void _maybeFocusAmount() {
    if (!_readyForAmount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_amountFocus);
    });
  }

  bool _isSaving = false;
  int _savedCount = 0;

  /// true فقط عندما جاءت هذه الفاتورة من قراءة تلقائية (widget.extractedPrefill:
  /// QR أو ذكاء اصطناعي أو OCR محلي) — يفعّل التحقق من التكرار عند الحفظ
  /// ودقة الضريبة القادمة من القراءة مباشرة. يبقى false دوماً لمسار الإدخال
  /// اليدوي فلا يتأثر بأي منهما.
  bool _isFromExtraction = false;
  ExtractedInvoiceData? _extractedData;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final allHotels = await _hotelRepository.getAllHotels();
    _otherHotels = allHotels.where((h) => h.id != widget.hotel.id).toList();
    _categories = await _categoryRepository.getCategories(type: FinancialCategory.typeExpense);

    if (_isEditMode) {
      final inv = widget.invoice!;
      _invoiceNumberController.text = inv.invoiceNumber;
      _selectedDate = DateTime.tryParse(inv.date) ?? DateTime.now();
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _amountController.text = NumberFormat("#,##0.##").format(inv.totalAmount);
      _computedVat = inv.vat;
      _computedBeforeTax = inv.amountBeforeTax;
      _selectedCategory = inv.expenseCategory;
      // تُقبَل قيمة amountSource القديمة فقط إن كانت مطابقة لأحد مصادر
      // التمويل الخمسة الحالية — الفواتير القديمة (قبل هذه المهمة) تبقى
      // بلا مصدر مُحدَّد مسبقاً، فيُطلب من المستخدم اختياره عند التعديل.
      if (kInvoiceFundingSources.any((o) => o.label == inv.amountSource)) {
        _fundingSource = inv.amountSource;
        _paymentMethod = inv.paymentMethod;
        _relatedHotelId = inv.relatedHotelId;
      }

      final existing = await _supplierRepository.getSupplierByOfficialName(widget.hotel.id!, inv.companyName);
      _selectedSupplier = existing ??
          Supplier(hotelId: widget.hotel.id!, officialName: inv.companyName, shortName: '', taxNumber: inv.taxNumber);
      _supplierConfirmed = true;
      if (mounted) setState(() {});
      return;
    }

    final extracted = widget.extractedPrefill;
    _selectedDate = extracted?.timestamp ?? DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);

    if (extracted != null) {
      _isFromExtraction = true;
      _extractedData = extracted;
      // رقم الفاتورة: يُعبَّأ إن استُخرِج فعلياً (ممكن من الذكاء الاصطناعي/OCR،
      // غير ممكن أبداً من QR — ليس جزءاً من معيار ZATCA المبسّط)، وإلا يبقى
      // فارغاً عمداً (بدل الرقم التسلسلي الافتراضي) ليكتبه المستخدم يدوياً.
      _invoiceNumberController.text = extracted.invoiceNumber ?? '';

      if (extracted.invoiceTotal != null) {
        _amountController.text = NumberFormat("#,##0.##").format(extracted.invoiceTotal);
      }

      if (extracted.vatNumber != null) {
        final existingSupplier = await _supplierRepository.getSupplierByTaxNumber(widget.hotel.id!, extracted.vatNumber!);
        if (existingSupplier != null) {
          _selectedSupplier = existingSupplier;
          _supplierConfirmed = true;
        } else {
          _isNewSupplierFlow = true;
          _officialNameController.text = extracted.sellerName ?? '';
          _taxNumberController.text = extracted.vatNumber!;
        }
      } else if (extracted.sellerName != null) {
        _companySearchController.text = extracted.sellerName!;
      }
    } else {
      final count = await _invoiceRepository.getAllInvoices(widget.hotel.id!);
      _invoiceNumberController.text = (count.length + 1).toString();
    }

    final defaultCategory = _categories.where((c) => c.isDefault).toList();
    if (defaultCategory.isNotEmpty) _selectedCategory = defaultCategory.first.name;
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_supplierConfirmed) _companySearchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _dateController.dispose();
    _companySearchController.dispose();
    _officialNameController.dispose();
    _shortNameController.dispose();
    _taxNumberController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    _companySearchFocus.dispose();
    _officialNameFocus.dispose();
    _shortNameFocus.dispose();
    _taxNumberFocus.dispose();
    _noteFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  // ---------------- بحث المورد ----------------

  Future<void> _onCompanySearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    final results = await _supplierRepository.searchSuppliers(widget.hotel.id!, query.trim());
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = true;
    });
  }

  void _onCompanySearchSubmitted(String value) {
    if (_searchResults.isNotEmpty) {
      _selectSupplier(_searchResults.first);
    } else if (value.trim().isNotEmpty) {
      _startNewSupplierFlow(value.trim());
    }
  }

  void _selectSupplier(Supplier supplier) {
    // بعد تأكيد المورد تصبح الخطوة التالية اختيار تصنيف/مصدر تمويل عبر
    // لمس الشاشة (أزرار) لا حقل نصي، لذا لا نقفز بالمؤشر لأي حقل هنا.
    setState(() {
      _selectedSupplier = supplier;
      _supplierConfirmed = true;
      _isNewSupplierFlow = false;
      _searchResults = [];
      _isSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _startNewSupplierFlow(String initialName) {
    setState(() {
      _isNewSupplierFlow = true;
      _searchResults = [];
      _isSearching = false;
      _officialNameController.text = initialName;
      _shortNameController.clear();
      _taxNumberController.clear();
      _noteController.clear();
      _taxNumberError = null;
    });
    FocusScope.of(context).requestFocus(_officialNameFocus);
  }

  void _changeSupplier() {
    setState(() {
      _supplierConfirmed = false;
      _isNewSupplierFlow = false;
      _selectedSupplier = null;
      _companySearchController.clear();
    });
    FocusScope.of(context).requestFocus(_companySearchFocus);
  }

  void _validateTaxNumber(String value) {
    setState(() {
      _taxNumberError = value.length == 15 || value.isEmpty ? null : "الرقم الضريبي يجب أن يكون 15 رقماً بالضبط";
    });
  }

  Future<void> _saveNewSupplierAndContinue() async {
    final officialName = _officialNameController.text.trim();
    final shortName = _shortNameController.text.trim();
    final taxNumber = _taxNumberController.text.trim();

    if (officialName.isEmpty) {
      FocusScope.of(context).requestFocus(_officialNameFocus);
      return;
    }
    if (shortName.isEmpty) {
      FocusScope.of(context).requestFocus(_shortNameFocus);
      return;
    }
    if (taxNumber.length != 15) {
      setState(() => _taxNumberError = "الرقم الضريبي يجب أن يكون 15 رقماً بالضبط");
      FocusScope.of(context).requestFocus(_taxNumberFocus);
      return;
    }

    final newSupplier = Supplier(
      hotelId: widget.hotel.id!,
      officialName: officialName,
      shortName: shortName,
      taxNumber: taxNumber,
      notes: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );
    final id = await _supplierRepository.addSupplier(newSupplier);
    if (!mounted) return;

    setState(() {
      _selectedSupplier = Supplier(
        id: id,
        hotelId: newSupplier.hotelId,
        officialName: newSupplier.officialName,
        shortName: newSupplier.shortName,
        taxNumber: newSupplier.taxNumber,
        notes: newSupplier.notes,
      );
      _supplierConfirmed = true;
      _isNewSupplierFlow = false;
    });
    FocusScope.of(context).unfocus();
  }

  // ---------------- المبلغ ----------------

  void _onAmountSubmitted(String value) {
    final total = ThousandsSeparatorInputFormatter.parse(value) ?? 0;
    if (total <= 0 || _selectedSupplier == null || !_readyForAmount) return;

    double beforeTax;
    double vat;
    // إن كان المبلغ المُدخَل مطابقاً للإجمالي القادم من القراءة التلقائية
    // (لم يُعدِّله المستخدم يدوياً)، تُستخدم قيمة الضريبة الفعلية منها
    // مباشرة — أدق من افتراض 15%. أي تعديل يدوي على المبلغ يُعيد الحساب
    // بالطريقة القياسية القديمة نفسها بلا أي تغيير.
    final extracted = _extractedData;
    if (extracted != null && extracted.invoiceTotal != null && extracted.vatTotal != null && (extracted.invoiceTotal! - total).abs() < 0.01) {
      vat = double.parse(extracted.vatTotal!.toStringAsFixed(2));
      beforeTax = double.parse((total - vat).toStringAsFixed(2));
    } else {
      beforeTax = double.parse((total / 1.15).toStringAsFixed(2));
      vat = double.parse((total - beforeTax).toStringAsFixed(2));
    }
    setState(() {
      _computedBeforeTax = beforeTax;
      _computedVat = vat;
    });
    _confirmAndSave(total, beforeTax, vat);
  }

  Future<void> _confirmAndSave(double total, double beforeTax, double vat) async {
    final fmt = NumberFormat("#,##0.00");
    await AppDialog.confirmAction(
      context: context,
      title: _isEditMode ? "تأكيد حفظ التعديلات" : "تأكيد حفظ الفاتورة",
      message: "${_selectedSupplier!.officialName}\n"
          "الإجمالي: ${fmt.format(total)} ريال\n"
          "الضريبة: ${fmt.format(vat)} ريال — قبل الضريبة: ${fmt.format(beforeTax)} ريال",
      onConfirm: () => _performSave(total, beforeTax, vat),
    );
  }

  Future<void> _performSave(double total, double beforeTax, double vat) async {
    setState(() => _isSaving = true);
    try {
      if (_isFromExtraction && !_isEditMode) {
        final invoiceNumber = _invoiceNumberController.text.trim();
        // يعتمد على أكثر من عنصر معاً (البند سابعاً): رقم الفاتورة + الرقم
        // الضريبي إن توفّر رقم الفاتورة، وأيضاً الرقم الضريبي + التاريخ +
        // المبلغ دوماً (بديل ضروري إذ QR لا يتضمّن رقم الفاتورة أصلاً).
        Invoice? duplicate;
        if (invoiceNumber.isNotEmpty) {
          duplicate = await _invoiceRepository.findDuplicate(
            hotelId: widget.hotel.id!,
            taxNumber: _selectedSupplier!.taxNumber,
            invoiceNumber: invoiceNumber,
          );
        }
        duplicate ??= await _invoiceRepository.findDuplicateByContent(
          hotelId: widget.hotel.id!,
          taxNumber: _selectedSupplier!.taxNumber,
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
          totalAmount: total,
        );
        if (duplicate != null && mounted) {
          bool proceed = false;
          await AppDialog.confirmAction(
            context: context,
            title: "فاتورة مكرَّرة",
            message: "يبدو أن هذه الفاتورة موجودة مسبقاً.",
            confirmLabel: "متابعة رغم ذلك",
            cancelLabel: "إلغاء",
            onConfirm: () async => proceed = true,
          );
          if (!proceed) return;
        }
      }

      final invoice = Invoice(
        id: widget.invoice?.id,
        hotelId: widget.hotel.id!,
        invoiceNumber: _invoiceNumberController.text.trim(),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        companyName: _selectedSupplier!.officialName,
        taxNumber: _selectedSupplier!.taxNumber,
        amountBeforeTax: beforeTax,
        vat: vat,
        totalAmount: total,
        facilityName: widget.hotel.arabicName,
        expenseCategory: _selectedCategory,
        amountSource: _fundingSource ?? 'خارج النظام',
        paymentMethod: _paymentMethod,
        relatedHotelId: _relatedHotelId,
      );

      if (_isEditMode) {
        await _invoiceRepository.updateInvoice(invoice);
        await _ensureDeferredPurchaseDebt(invoiceId: widget.invoice!.id!, amount: total);
        final changes = InvoiceAuditLogEntry.describeChanges(widget.invoice!, invoice);
        if (changes != null) {
          await _invoiceRepository.logAudit(InvoiceAuditLogEntry(
            invoiceId: widget.invoice!.id!,
            hotelId: widget.hotel.id!,
            username: kInvoiceAuditDefaultUsername,
            operationType: 'update',
            changedFields: changes,
            occurredAt: DateTime.now().toIso8601String(),
          ));
        }
        if (mounted) Navigator.pop(context, true);
        return;
      }

      final newInvoiceId = await _invoiceRepository.addInvoice(invoice);
      await _ensureDeferredPurchaseDebt(invoiceId: newInvoiceId, amount: total);
      await _invoiceRepository.logAudit(InvoiceAuditLogEntry(
        invoiceId: newInvoiceId,
        hotelId: widget.hotel.id!,
        username: kInvoiceAuditDefaultUsername,
        operationType: 'create',
        changedFields: null,
        occurredAt: DateTime.now().toIso8601String(),
      ));
      if (!mounted) return;
      _savedCount++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم حفظ الفاتورة رقم ${invoice.invoiceNumber} — جاهز للفاتورة التالية"), duration: const Duration(seconds: 2)),
      );
      await _resetForNextInvoice();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// عند مصدر التمويل "شراء آجل" فقط: ينشئ مديونية للمورد مرتبطة بهذه
  /// الفاتورة تحديداً (invoice_id فريد في قاعدة البيانات، فلا يمكن أبداً
  /// إنشاء مديونية مكرَّرة لنفس الفاتورة — عند التعديل يُحدَّث مبلغ
  /// المديونية القائمة بدل إنشاء أخرى). لا تنفيذ لأي مصدر تمويل آخر.
  Future<void> _ensureDeferredPurchaseDebt({required int invoiceId, required double amount}) async {
    final option = _selectedFundingOption;
    if (option == null || option.hasPaymentMethod) return;
    final supplierId = _selectedSupplier?.id;
    if (supplierId == null) return;
    await _supplierRepository.ensureDebtForInvoice(
      hotelId: widget.hotel.id!,
      supplierId: supplierId,
      invoiceId: invoiceId,
      amount: amount,
    );
  }

  /// إعادة تصفير لفاتورة تالية: يُبقي عمداً على تصنيف المصروف ومصدر
  /// التمويل كما هما (الغالب أن دفعة فواتير اليوم من نفس النوع ونفس جهة
  /// الصرف)، ولا يُصفِّر إلا المورد والمبلغ — أسرع لإدخال دفعة فواتير
  /// متشابهة، مع بقاء إمكانية تغييرهما يدوياً بضغطة واحدة إن لزم.
  Future<void> _resetForNextInvoice() async {
    final count = await _invoiceRepository.getAllInvoices(widget.hotel.id!);
    if (!mounted) return;
    setState(() {
      _invoiceNumberController.text = (count.length + 1).toString();
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _companySearchController.clear();
      _officialNameController.clear();
      _shortNameController.clear();
      _taxNumberController.clear();
      _noteController.clear();
      _amountController.clear();
      _selectedSupplier = null;
      _supplierConfirmed = false;
      _isNewSupplierFlow = false;
      _searchResults = [];
      _isSearching = false;
      _computedVat = null;
      _computedBeforeTax = null;
      // الفاتورة التالية في نفس جلسة الإدخال السريع تعود دائماً لمسار
      // الإدخال اليدوي العادي (لا تحمل بيانات مستخرَجة سابقة ولا تخضع لتحقق التكرار).
      _isFromExtraction = false;
      _extractedData = null;
    });
    FocusScope.of(context).requestFocus(_companySearchFocus);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _identityColor)),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: _isEditMode ? "تعديل الفاتورة" : "إضافة فاتورة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isEditMode && _savedCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: AppSizes.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text("تم إدخال $_savedCount", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInvoiceMetaRow(),
            const SizedBox(height: AppSizes.md),
            if (!_supplierConfirmed) _buildSupplierSearchSection(),
            if (_supplierConfirmed) _buildSupplierConfirmedSection(),
            if (_supplierConfirmed) ...[
              const SizedBox(height: AppSizes.md),
              _buildCategorySection(),
              const SizedBox(height: AppSizes.md),
              _buildFundingSourceSection(),
            ],
            const SizedBox(height: AppSizes.md),
            if (_readyForAmount) _buildAmountSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceMetaRow() {
    return Row(
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
            onTap: _pickDate,
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierSearchSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isNewSupplierFlow) ...[
            Text("المورد", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            AppTextField(
              controller: _companySearchController,
              hint: "اكتب اسم الشركة أو الاسم المختصر...",
              icon: Icons.search,
              focusNode: _companySearchFocus,
              textInputAction: TextInputAction.next,
              onChanged: _onCompanySearchChanged,
              onSubmitted: _onCompanySearchSubmitted,
            ),
            if (_isSearching) ...[
              const SizedBox(height: AppSizes.sm),
              if (_searchResults.isEmpty)
                InkWell(
                  onTap: () => _startNewSupplierFlow(_companySearchController.text.trim()),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: _identityColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: _identityColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text("لا يوجد مورد مطابق — إضافة \"${_companySearchController.text.trim()}\" كمورد جديد", style: TextStyle(color: _identityColor, fontSize: 13))),
                      ],
                    ),
                  ),
                )
              else
                ..._searchResults.map((s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.business, color: _identityColor),
                      title: Text(s.officialName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                      subtitle: Text("${s.shortName} · ${s.taxNumber}", style: AppTextStyles.caption),
                      onTap: () => _selectSupplier(s),
                    )),
            ],
          ] else
            _buildNewSupplierForm(),
        ],
      ),
    );
  }

  Widget _buildNewSupplierForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("مورد جديد", style: AppTextStyles.bodyBold),
            const Spacer(),
            TextButton(onPressed: _changeSupplier, child: const Text("إلغاء")),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        AppTextField(
          controller: _officialNameController,
          hint: "الاسم الرسمي",
          icon: Icons.business,
          focusNode: _officialNameFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_shortNameFocus),
        ),
        const SizedBox(height: AppSizes.md),
        AppTextField(
          controller: _shortNameController,
          hint: "الاسم المختصر (للبحث فقط، لا يظهر بالفاتورة)",
          icon: Icons.short_text,
          focusNode: _shortNameFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_taxNumberFocus),
        ),
        const SizedBox(height: AppSizes.md),
        AppTextField(
          controller: _taxNumberController,
          hint: "الرقم الضريبي (15 رقماً)",
          icon: Icons.receipt,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)],
          focusNode: _taxNumberFocus,
          textInputAction: TextInputAction.next,
          errorText: _taxNumberError,
          onChanged: _validateTaxNumber,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_noteFocus),
        ),
        const SizedBox(height: AppSizes.md),
        AppTextField(
          controller: _noteController,
          hint: "ملاحظة (اختياري)",
          icon: Icons.note_outlined,
          focusNode: _noteFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveNewSupplierAndContinue(),
        ),
        const SizedBox(height: AppSizes.md),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: _saveNewSupplierAndContinue,
            icon: const Icon(Icons.check),
            label: const Text("حفظ المورد ومتابعة"),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierConfirmedSection() {
    final s = _selectedSupplier!;
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: _identityColor),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.officialName, style: AppTextStyles.bodyBold),
                Text("الرقم الضريبي: ${s.taxNumber}", style: AppTextStyles.caption),
              ],
            ),
          ),
          TextButton(onPressed: _changeSupplier, child: const Text("تغيير")),
        ],
      ),
    );
  }

  // ---------------- تصنيف المصروف ----------------

  Widget _buildCategorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("تصنيف المصروف", style: AppTextStyles.bodyBold),
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
                onSelected: (_) {
                  setState(() => _selectedCategory = category.name);
                  _maybeFocusAmount();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------- مصدر التمويل ----------------

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
                onSelected: (_) {
                  setState(() {
                    _fundingSource = option.label;
                    _paymentMethod = null;
                    _relatedHotelId = null;
                  });
                  _maybeFocusAmount();
                },
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
                        onSelected: (_) {
                          setState(() => _relatedHotelId = h.id);
                          _maybeFocusAmount();
                        },
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
                  onSelected: (_) {
                    setState(() => _paymentMethod = method);
                    _maybeFocusAmount();
                  },
                );
              }).toList(),
            ),
          ],
          if (_selectedFundingOption != null && !_selectedFundingOption!.hasPaymentMethod) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: _selectedFundingOption!.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
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

  Widget _buildAmountSection() {
    final fmt = NumberFormat("#,##0.00");
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("المبلغ الإجمالي (شامل الضريبة)", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          AppTextField(
            controller: _amountController,
            hint: "0.00",
            icon: Icons.payments_outlined,
            formatThousands: true,
            focusNode: _amountFocus,
            textInputAction: TextInputAction.done,
            onSubmitted: _isSaving ? null : _onAmountSubmitted,
          ),
          if (_computedVat != null && _computedBeforeTax != null) ...[
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(child: _buildComputedChip("قبل الضريبة", "${fmt.format(_computedBeforeTax)} ريال")),
                const SizedBox(width: AppSizes.sm),
                Expanded(child: _buildComputedChip("الضريبة (15%)", "${fmt.format(_computedVat)} ريال")),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.md),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : () => _onAmountSubmitted(_amountController.text),
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditMode ? "حفظ التعديلات" : "حفظ الفاتورة"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComputedChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
