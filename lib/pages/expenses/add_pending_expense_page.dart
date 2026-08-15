import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/financial_category.dart';
import '../../models/hotel.dart';
import '../../models/pending_expense.dart';
import '../../models/pending_expense_attachment.dart';
import '../../models/supplier.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/financial_category_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/attachment_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../widgets/financial/financial_category_picker.dart';
import '../../widgets/suppliers/supplier_picker_sheet.dart';
import '../common/transaction_review_page.dart';

class AddPendingExpensePage extends StatefulWidget {
  final Hotel hotel;
  final PendingExpense? editExpense;

  /// "مسحوبات المالك" — يُقفل مصدر التمويل على
  /// [PendingExpense.paymentMethodOwnerDrawing] ويُبسِّط الواجهة (بلا بطاقة
  /// مصدر تمويل كاملة). هذا هو مسار الإضافة الأساسي الآن (راجع دورة الحياة
  /// المحاسبية: معلّق ← تقرير يومي ← ترحيل — لم تعد مسحوبات المالك تُنفَّذ
  /// فوراً عبر AddOwnerWithdrawalPage، الذي بقي فقط لعرض/تعديل/حذف سحوبات
  /// قديمة نُفِّذت فوراً بالمسار السابق قبل هذا التغيير).
  final bool lockToOwnerDrawing;

  /// true عند الفتح من قسم "عهدة على الفندق" المخصَّص — يُقفل مصدر التمويل على
  /// [PendingExpense.paymentMethodHotelAdvance] ('شخصي': المالك يموِّل مصروف
  /// الفندق من ماله الخاص) ويُبسِّط الواجهة (بلا بطاقة مصدر تمويل كاملة ولا
  /// أي اختيار نقد/خزنة/شبكة — المالك هو مصدر التمويل الوحيد دائماً).
  final bool lockToHotelAdvance;

  const AddPendingExpensePage({super.key, required this.hotel, this.editExpense, this.lockToOwnerDrawing = false, this.lockToHotelAdvance = false});

  @override
  State<AddPendingExpensePage> createState() => _AddPendingExpensePageState();
}

class _AddPendingExpensePageState extends State<AddPendingExpensePage> {
  final _repository = ExpenseRepository();
  final _categoryRepository = FinancialCategoryRepository();
  final _hotelRepository = HotelRepository();
  final _supplierRepository = SupplierRepository();
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _statementController = TextEditingController();
  final _dueDateController = TextEditingController();

  List<Hotel> _allHotels = [];
  FinancialCategory? _selectedCategory;
  String? _paymentMethod;
  Supplier? _selectedSupplier;
  bool _isLoading = true;
  bool _showOtherHotels = false;

  /// null = هذا الفندق (الافتراضي). قيمة أخرى = معرّف فندق مموِّل فعلي —
  /// منفصل تماماً عن [_paymentMethod] (طريقة الدفع تبقى نقد/شبكة/... بلا
  /// تغيير)؛ راجع PendingExpense.isFundedByOtherHotel وتعليقها.
  int? _fundingSourceHotelId;

  List<PendingExpenseAttachment> _existingAttachments = [];
  final List<({String path, String name, String type})> _newAttachments = [];

  bool get _isLocked => widget.editExpense?.isTransferred == true;
  bool get _isDeferred => _paymentMethod == PendingExpense.fundingSourceDeferred;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _categoryRepository.getCategories(type: FinancialCategory.typeExpense);
    final hotels = await _hotelRepository.getAllHotels();
    final edit = widget.editExpense;
    List<PendingExpenseAttachment> attachments = [];
    if (edit != null) {
      _amountController.text = NumberFormat("#,##0.##").format(edit.amount);
      _statementController.text = edit.statement;
      _dueDateController.text = edit.dueDate ?? "";
      attachments = await _repository.getAttachments(edit.id!);
      _paymentMethod = edit.paymentMethod;
      _fundingSourceHotelId = edit.fundingSourceHotelId;
      if (edit.isDeferredDebt && edit.supplierId != null) {
        _selectedSupplier = await _supplierRepository.getSupplierById(edit.supplierId!);
      }
    } else if (widget.lockToOwnerDrawing) {
      _paymentMethod = PendingExpense.paymentMethodOwnerDrawing;
    } else if (widget.lockToHotelAdvance) {
      _paymentMethod = PendingExpense.paymentMethodHotelAdvance;
    }

    if (mounted) {
      setState(() {
        _allHotels = hotels.where((h) => h.id != widget.hotel.id).toList();
        _existingAttachments = attachments;
        if (edit != null) {
          for (final c in categories) {
            if (c.id == edit.categoryId) _selectedCategory = c;
          }
        }
        _isLoading = false;
      });
    }
  }

  /// يضبط نقد/شبكة/المالك لهذا الفندق نفسه (مصدر التمويل = الفندق الحالي) —
  /// يمسح أي اختيار سابق لفندق آخر أو دين مؤجَّل.
  void _selectOwnFunding(String paymentMethod) {
    if (_isLocked) return;
    setState(() {
      _paymentMethod = paymentMethod;
      _fundingSourceHotelId = null;
      _selectedSupplier = null;
    });
  }

  /// اختيار فندق آخر كمصدر تمويل فعلي (عبر "مصدر آخر") بطريقة دفع محدَّدة —
  /// يحدِّد عند الترحيل عدم الخصم من خزنة هذا الفندق وإنشاء ذمة تلقائية بين
  /// الفندقين بدلاً من ذلك. راجع PendingExpense.isFundedByOtherHotel.
  void _selectOtherHotelFunding(Hotel hotel, String paymentMethod) {
    if (_isLocked) return;
    setState(() {
      _paymentMethod = paymentMethod;
      _fundingSourceHotelId = hotel.id;
      _selectedSupplier = null;
    });
  }

  Future<void> _pickDeferredSupplier() async {
    if (_isLocked) return;
    final supplier = await showSupplierPicker(context, hotelId: widget.hotel.id!);
    if (supplier == null || !mounted) return;
    setState(() {
      _paymentMethod = PendingExpense.fundingSourceDeferred;
      _fundingSourceHotelId = null;
      _selectedSupplier = supplier;
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dueDateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _pickImageAttachment() async {
    final picked = await AttachmentService.pickImages(folder: 'pending_expense_attachments');
    if (picked.isEmpty) return;
    setState(() {
      for (final p in picked) {
        _newAttachments.add((path: p.path, name: p.name, type: 'image'));
      }
    });
  }

  Future<void> _pickPdfAttachment() async {
    final picked = await AttachmentService.pickPdf(folder: 'pending_expense_attachments');
    if (picked == null) return;
    setState(() => _newAttachments.add((path: picked.path, name: picked.name, type: 'pdf')));
  }

  Future<void> _deleteExistingAttachment(PendingExpenseAttachment a) async {
    await _repository.deleteAttachment(a.id!);
    setState(() => _existingAttachments.removeWhere((e) => e.id == a.id));
  }

  void _save() {
    if (_isLocked) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار نوع المصروف")));
      return;
    }
    if (_paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار طريقة الدفع")));
      return;
    }
    if (_isDeferred && _selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار المورد")));
      return;
    }

    final now = DateTime.now();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    final expense = PendingExpense(
      id: widget.editExpense?.id,
      hotelId: widget.hotel.id!,
      amount: amount,
      paymentMethod: _paymentMethod!,
      categoryId: _selectedCategory!.id!,
      categoryName: _selectedCategory!.name,
      statement: _statementController.text.trim(),
      notes: null,
      date: widget.editExpense?.date ?? DateFormat('yyyy-MM-dd').format(now),
      time: widget.editExpense?.time ?? DateFormat('HH:mm:ss').format(now),
      createdAt: widget.editExpense?.createdAt ?? now.toIso8601String(),
      supplierId: _isDeferred ? _selectedSupplier!.id : null,
      dueDate: _isDeferred && _dueDateController.text.trim().isNotEmpty ? _dueDateController.text.trim() : null,
      fundingSourceHotelId: _fundingSourceHotelId,
    );

    final reviewItems = [
      ReviewItem(label: "البيان", value: expense.statement),
      ReviewItem(label: "المبلغ", value: "${NumberFormat("#,##0.##").format(expense.amount)} ريال", color: AppColors.danger),
      ReviewItem(label: "النوع", value: expense.categoryName ?? ""),
      ReviewItem(label: "طريقة الدفع", value: expense.paymentMethod, color: Colors.blue),
      if (expense.isFundedByOtherHotel)
        ReviewItem(
          label: "مصدر التمويل",
          value: _allHotels.firstWhere((h) => h.id == _fundingSourceHotelId, orElse: () => widget.hotel).arabicName,
          color: Colors.teal,
        ),
      if (_isDeferred) ReviewItem(label: "المورد", value: _selectedSupplier!.officialName, color: Colors.orange),
      if (_isDeferred && expense.dueDate != null) ReviewItem(label: "تاريخ الاستحقاق", value: expense.dueDate!),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: "مراجعة المصروف",
          items: reviewItems,
          onConfirm: () async {
            int expenseId;
            if (widget.editExpense == null) {
              expenseId = await _repository.addPendingExpense(expense);
            } else {
              expenseId = widget.editExpense!.id!;
              await _repository.updatePendingExpense(expense);
            }

            // لا يُنشأ أي دين على المورد هنا — المصروف المعلَّق "آجل" مجرد سجل
            // مؤقت غير معتمَد، بلا أي أثر على المركز المالي حتى يُرحَّل تقرير
            // يومه فعلياً (راجع VaultRepository._postSpecialPendingExpenses
            // وتعليقها — الدين يُنشأ هناك فقط، عند الترحيل).

            for (final a in _newAttachments) {
              await _repository.addAttachment(PendingExpenseAttachment(
                pendingExpenseId: expenseId,
                hotelId: widget.hotel.id!,
                filePath: a.path,
                fileType: a.type,
                fileName: a.name,
                createdAt: DateTime.now().toIso8601String(),
              ));
            }

            if (mounted) {
              Navigator.pop(context); // Close Review
              Navigator.pop(context, true); // Close Add Page
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(
          title: widget.lockToHotelAdvance
              ? (widget.editExpense == null ? "إضافة عهدة على الفندق" : "تعديل عهدة على الفندق")
              : widget.lockToOwnerDrawing
                  ? (widget.editExpense == null ? "إضافة مسحوب مالك" : "تعديل مسحوب مالك")
                  : (widget.editExpense == null ? "إضافة مصروف معلق" : "تعديل مصروف"),
          hotel: widget.hotel,
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_isLocked) _buildLockedBanner(),
                    _buildMainCard(),
                    const SizedBox(height: AppSizes.lg),
                    widget.lockToHotelAdvance
                        ? _buildHotelAdvanceFundingCard()
                        : widget.lockToOwnerDrawing
                            ? _buildOwnerDrawingFundingCard()
                            : _buildFundingRow(),
                    const SizedBox(height: AppSizes.lg),
                    _buildAttachmentsCard(),
                    const SizedBox(height: AppSizes.xl),
                    if (!_isLocked)
                      AppButton(
                        text: "مراجعة وحفظ",
                        onPressed: _save,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(child: Text("هذا المصروف مرحَّل ومقفل — لتعديله استخدم خيار \"إلغاء ترحيل المصروف\" من التقرير اليومي أولاً.", style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("تفاصيل المصروف", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _amountController,
            hint: "المبلغ",
            icon: Icons.attach_money,
            formatThousands: true,
            readOnly: _isLocked,
          ),
          const SizedBox(height: AppSizes.md),
          _buildCategoryDropdown(),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _statementController,
            hint: "البيان (مثلاً: فواتير كهرباء شهر 5)",
            icon: Icons.description,
            readOnly: _isLocked,
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory() async {
    if (_isLocked) return;
    final picked = await showFinancialCategoryPicker(context, type: FinancialCategory.typeExpense, current: _selectedCategory);
    if (picked != null && mounted) setState(() => _selectedCategory = picked);
  }

  Widget _buildCategoryDropdown() {
    final selected = _selectedCategory;
    return InkWell(
      onTap: _isLocked ? null : _pickCategory,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            if (selected != null) ...[
              Icon(IconData(selected.iconCode, fontFamily: 'MaterialIcons'), color: Color(selected.colorValue), size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                selected?.name ?? "اختر نوع المصروف",
                style: TextStyle(color: selected == null ? Colors.grey[600] : null),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  /// بطاقة "مصدر التمويل" الموحَّدة — صف [نقد (Cash) | الخزنة (Safe) | شبكة
  /// (Network)] لتمويل هذا الفندق نفسه (كل خيار أثر محاسبي مختلف تماماً —
  /// راجع VaultRepository._postSpecialPendingExpenses وتعليقها)، زر "مصدر
  /// آخر" يوسِّع قائمة كل الفنادق، ثم رابط "دين على مورد (آجل)". "عهدة
  /// الفندق" و"مسحوبات المالك" لم يعودا خيارَي تمويل هنا — لكل منهما قسمه
  /// المستقل الآن (راجع lockToHotelAdvance وقسم "مسحوبات المالك" الفوري).
  Widget _buildFundingRow() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("مصدر التمويل", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(child: _fundingChip("نقد", Icons.money, "نقد")),
              const SizedBox(width: 8),
              Expanded(child: _fundingChip("الخزنة", Icons.lock_outline, PendingExpense.paymentMethodSafe)),
              const SizedBox(width: 8),
              Expanded(child: _fundingChip("شبكة", Icons.credit_card, "شبكة")),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isLocked ? null : () => setState(() => _showOtherHotels = !_showOtherHotels),
              icon: Icon(_showOtherHotels ? Icons.expand_less : Icons.expand_more, size: 18),
              label: const Text("مصدر آخر"),
            ),
          ),
          if (_showOtherHotels) ...[
            const Divider(height: 1),
            for (final h in _allHotels) _buildOtherHotelRow(h),
          ],
          const Divider(height: 20),
          Wrap(
            spacing: 4,
            children: [
              TextButton(onPressed: _isLocked ? null : _pickDeferredSupplier, child: const Text("دين على مورد (آجل)")),
            ],
          ),
          _buildCurrentSelectionSummary(),
          if (_isDeferred) _buildDeferredDebtSection(),
        ],
      ),
    );
  }

  /// بطاقة مبسَّطة تحل محل [_buildFundingRow] الكاملة عند [AddPendingExpensePage.lockToOwnerDrawing]
  /// — مصدر التمويل هو "مسحوبات المالك" دائماً، فلا معنى لعرض أي اختيار آخر.
  Widget _buildOwnerDrawingFundingCard() {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Colors.amber),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Text(
              "مصدر التمويل: مسحوبات المالك — سجل مؤقت بلا أي أثر على المركز المالي الآن؛ يُخصَم من خزنة الفندق وتُنشأ ذمة على المالك تلقائياً فقط عند ترحيل تقرير هذا اليوم.",
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة مبسَّطة تحل محل [_buildFundingRow] الكاملة عند [AddPendingExpensePage.lockToHotelAdvance]
  /// — "عهدة على الفندق": المالك هو مصدر التمويل الوحيد دائماً، فلا معنى لعرض
  /// أي اختيار نقد/خزنة/شبكة (راجع البند 4 من متطلبات إعادة التصميم).
  Widget _buildHotelAdvanceFundingCard() {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.teal),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Text(
              "مصدر التمويل: المالك شخصياً — مصروف تشغيلي حقيقي للفندق، بلا خصم أي نقد/خزنة/شبكة من الفندق، وتُنشأ ذمة (التزام) على الفندق لصالح المالك تلقائياً عند الترحيل.",
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fundingChip(String label, IconData icon, String value) {
    final selected = _paymentMethod == value && _fundingSourceHotelId == null;
    return ChoiceChip(
      label: Text(label, textAlign: TextAlign.center),
      avatar: Icon(icon, size: 16),
      selected: selected,
      onSelected: _isLocked ? null : (_) => _selectOwnFunding(value),
    );
  }

  Widget _buildOtherHotelRow(Hotel h) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(h.arabicName, style: AppTextStyles.body.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          _hotelMethodChip(h, "نقد"),
          const SizedBox(width: 6),
          _hotelMethodChip(h, "شبكة"),
        ],
      ),
    );
  }

  Widget _hotelMethodChip(Hotel h, String method) {
    final selected = _paymentMethod == method && _fundingSourceHotelId == h.id;
    return ChoiceChip(
      label: Text(method, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: _isLocked ? null : (_) => _selectOtherHotelFunding(h, method),
    );
  }

  Widget _buildCurrentSelectionSummary() {
    if (_paymentMethod == null) return const SizedBox.shrink();
    String label;
    Color color;
    if (_fundingSourceHotelId != null) {
      final hotelName = _allHotels.firstWhere((h) => h.id == _fundingSourceHotelId, orElse: () => widget.hotel).arabicName;
      label = "مموَّل من $hotelName ($_paymentMethod) — لا يُخصَم من خزنة هذا الفندق";
      color = Colors.teal;
    } else if (_isDeferred) {
      label = "آجل (دين)${_selectedSupplier != null ? ' — ${_selectedSupplier!.officialName}' : ''}";
      color = Colors.orange;
    } else {
      label = "طريقة الدفع: $_paymentMethod (من هذا الفندق)";
      color = Colors.blueGrey;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildDeferredDebtSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Expanded(child: Text(_selectedSupplier?.officialName ?? "—", style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isLocked ? null : _pickDueDate,
            child: AbsorbPointer(
              child: AppTextField(controller: _dueDateController, hint: "تاريخ الاستحقاق (اختياري)", icon: Icons.event_outlined, readOnly: _isLocked),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("المرفقات (اختياري)", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          if (!_isLocked)
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _pickImageAttachment, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text("صورة"))),
                const SizedBox(width: AppSizes.sm),
                Expanded(child: OutlinedButton.icon(onPressed: _pickPdfAttachment, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text("PDF"))),
              ],
            ),
          if (_existingAttachments.isNotEmpty || _newAttachments.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            ..._existingAttachments.map((a) => _attachmentTile(
                  name: a.fileName,
                  isPdf: a.isPdf,
                  onDelete: _isLocked ? null : () => _deleteExistingAttachment(a),
                )),
            ..._newAttachments.map((a) => _attachmentTile(
                  name: a.name,
                  isPdf: a.type == 'pdf',
                  onDelete: () => setState(() => _newAttachments.remove(a)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _attachmentTile({required String name, required bool isPdf, VoidCallback? onDelete}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(isPdf ? Icons.picture_as_pdf : Icons.image, size: 20),
          const SizedBox(width: AppSizes.sm),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption)),
          if (onDelete != null) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onDelete),
        ],
      ),
    );
  }
}
