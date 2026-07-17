import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/expense_category.dart';
import '../../models/hotel.dart';
import '../../models/pending_expense.dart';
import '../../models/pending_expense_attachment.dart';
import '../../models/supplier.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/attachment_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../widgets/financial/funding_source_picker.dart';
import '../common/transaction_review_page.dart';

class AddPendingExpensePage extends StatefulWidget {
  final Hotel hotel;
  final PendingExpense? editExpense;
  const AddPendingExpensePage({super.key, required this.hotel, this.editExpense});

  @override
  State<AddPendingExpensePage> createState() => _AddPendingExpensePageState();
}

class _AddPendingExpensePageState extends State<AddPendingExpensePage> {
  final _repository = ExpenseRepository();
  final _hotelRepository = HotelRepository();
  final _supplierRepository = SupplierRepository();
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _statementController = TextEditingController();
  final _notesController = TextEditingController();
  final _dueDateController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<Hotel> _allHotels = [];
  ExpenseCategory? _selectedCategory;
  String? _paymentMethod;
  Supplier? _selectedSupplier;
  bool _isLoading = true;

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
    final categories = await _repository.getCategories();
    final hotels = await _hotelRepository.getAllHotels();
    final edit = widget.editExpense;
    List<PendingExpenseAttachment> attachments = [];
    if (edit != null) {
      _amountController.text = NumberFormat("#,##0.##").format(edit.amount);
      _statementController.text = edit.statement;
      _notesController.text = edit.notes ?? "";
      _dueDateController.text = edit.dueDate ?? "";
      attachments = await _repository.getAttachments(edit.id!);
      _paymentMethod = edit.paymentMethod;
      if (edit.isDeferredDebt && edit.supplierId != null) {
        _selectedSupplier = await _supplierRepository.getSupplierById(edit.supplierId!);
      }
    }

    if (mounted) {
      setState(() {
        _categories = categories;
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

  Future<void> _pickFundingSource() async {
    if (_isLocked) return;
    final result = await showFundingSourcePicker(context, hotelId: widget.hotel.id!, otherHotels: _allHotels);
    if (result == null) return;
    Supplier? supplier;
    if (result.supplierId != null) {
      supplier = await _supplierRepository.getSupplierById(result.supplierId!);
    }
    setState(() {
      _paymentMethod = result.paymentMethod;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار مصدر التمويل")));
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
      notes: _notesController.text.trim(),
      date: widget.editExpense?.date ?? DateFormat('yyyy-MM-dd').format(now),
      time: widget.editExpense?.time ?? DateFormat('HH:mm:ss').format(now),
      createdAt: widget.editExpense?.createdAt ?? now.toIso8601String(),
      supplierId: _isDeferred ? _selectedSupplier!.id : null,
      dueDate: _isDeferred && _dueDateController.text.trim().isNotEmpty ? _dueDateController.text.trim() : null,
    );

    final reviewItems = [
      ReviewItem(label: "البيان", value: expense.statement),
      ReviewItem(label: "المبلغ", value: "${NumberFormat("#,##0.##").format(expense.amount)} ريال", color: AppColors.danger),
      ReviewItem(label: "النوع", value: expense.categoryName ?? ""),
      ReviewItem(label: "مصدر التمويل", value: expense.paymentMethod, color: Colors.blue),
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

            if (_isDeferred) {
              await _supplierRepository.ensureDebtForPendingExpense(
                hotelId: widget.hotel.id!,
                supplierId: _selectedSupplier!.id!,
                pendingExpenseId: expenseId,
                amount: expense.amount,
                statement: expense.statement,
                dueDate: expense.dueDate,
              );
            } else if (widget.editExpense != null) {
              // تغيير مصدر التمويل بعيداً عن "آجل" أثناء التعديل — يزيل أي دين قديم كان مرتبطاً بهذا المصروف.
              await _supplierRepository.deleteDebtForPendingExpense(expenseId);
            }

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
        title: HotelIdentityTitle(title: widget.editExpense == null ? "إضافة مصروف معلق" : "تعديل مصروف", hotel: widget.hotel),
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
                    _buildFundingSourceCard(),
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
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _notesController,
            hint: "الملاحظات (اختياري)",
            icon: Icons.note_alt_outlined,
            maxLines: 2,
            readOnly: _isLocked,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ExpenseCategory>(
          value: _selectedCategory,
          isExpanded: true,
          hint: const Text("اختر نوع المصروف"),
          items: _categories.map((c) => DropdownMenuItem(
            value: c,
            child: Row(
              children: [
                Icon(IconData(c.iconCode, fontFamily: 'MaterialIcons'), color: Color(c.colorValue), size: 20),
                const SizedBox(width: 12),
                Text(c.name),
              ],
            ),
          )).toList(),
          onChanged: _isLocked ? null : (v) => setState(() => _selectedCategory = v),
        ),
      ),
    );
  }

  Widget _buildFundingSourceCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("مصدر التمويل", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          InkWell(
            onTap: _isLocked ? null : _pickFundingSource,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _paymentMethod ?? "اختيار مصدر التمويل",
                      style: _paymentMethod == null ? AppTextStyles.caption : AppTextStyles.bodyBold.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (_isDeferred) _buildDeferredDebtSection(),
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
