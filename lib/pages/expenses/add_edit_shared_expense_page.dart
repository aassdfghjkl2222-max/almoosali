import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/expense_distribution_engine.dart';
import '../../models/expense_category.dart';
import '../../models/hotel.dart';
import '../../models/pending_expense.dart';
import '../../models/shared_expense.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/shared_expense_distribution_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../common/transaction_review_page.dart';

/// إنشاء/تعديل مصروف مشترك: مبلغ إجمالي واحد يُوزَّع تلقائياً (بالتساوي، مع
/// تعديل يدوي ذكي — راجع ExpenseDistributionEngine) كمصروفات معلَّقة مستقلة
/// على عدة منشآت نشطة. [editing]/[editingRows] للتعديل فقط.
class AddEditSharedExpensePage extends StatefulWidget {
  final SharedExpense? editing;
  final List<PendingExpense>? editingRows;
  /// عند الإنشاء فقط: منشأة تُختار مسبقاً (فُتحت الشاشة من داخل لوحة تحكم فندق معيّن).
  final int? initialHotelId;
  const AddEditSharedExpensePage({super.key, this.editing, this.editingRows, this.initialHotelId});

  @override
  State<AddEditSharedExpensePage> createState() => _AddEditSharedExpensePageState();
}

class _AddEditSharedExpensePageState extends State<AddEditSharedExpensePage> {
  final _repository = SharedExpenseDistributionRepository();
  final _expenseRepository = ExpenseRepository();
  final _hotelRepository = HotelRepository();

  final _totalController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<Hotel> _operationalHotels = [];
  ExpenseCategory? _selectedCategory;
  String? _fundingSource;
  DateTime _date = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  final Set<int> _selectedHotelIds = {};
  final Map<int, TextEditingController> _shareControllers = {};
  final Set<int> _manuallyEditedIds = {};
  bool _suppressAutoUpdate = false;

  bool get _isEditing => widget.editing != null;

  double get _totalAmount => double.tryParse(_totalController.text.replaceAll(',', '')) ?? 0;
  bool get _amountEntered => _totalAmount > 0;

  double get _distributedAmount {
    double sum = 0;
    for (final id in _selectedHotelIds) {
      sum += double.tryParse(_shareControllers[id]?.text.replaceAll(',', '') ?? '') ?? 0;
    }
    return sum;
  }

  double get _remainingAmount => _totalAmount - _distributedAmount;
  bool get _isBalanced => _amountEntered && (_remainingAmount.abs() <= 0.01);

  bool get _canSave =>
      _amountEntered &&
      _selectedCategory != null &&
      _fundingSource != null &&
      _descriptionController.text.trim().isNotEmpty &&
      _selectedHotelIds.isNotEmpty &&
      _isBalanced &&
      !_isSaving;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _totalController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final categories = await _expenseRepository.getCategories();
    final hotels = await _hotelRepository.getOperationalHotels();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _operationalHotels = hotels;
      _isLoading = false;
    });
    if (_isEditing) {
      _prefillForEdit();
    } else if (widget.initialHotelId != null) {
      _toggleHotel(widget.initialHotelId!, true);
    }
  }

  void _prefillForEdit() {
    final e = widget.editing!;
    final rows = widget.editingRows ?? [];
    _descriptionController.text = e.description ?? '';
    _notesController.text = e.notes ?? '';
    _totalController.text = NumberFormat("#,##0.##").format(e.totalAmount);
    _fundingSource = e.fundingSource;
    _date = DateTime.tryParse(e.date) ?? DateTime.now();
    for (final c in _categories) {
      if (c.id == e.categoryId) _selectedCategory = c;
    }
    for (final row in rows) {
      _selectedHotelIds.add(row.hotelId);
      _manuallyEditedIds.add(row.hotelId); // القيم المحفوظة تُعامَل كتحرير يدوي حتى لا تُعاد كتابتها فوراً
      _controllerFor(row.hotelId).text = NumberFormat("#,##0.##").format(row.amount);
    }
    setState(() {});
  }

  TextEditingController _controllerFor(int hotelId) {
    return _shareControllers.putIfAbsent(hotelId, () => TextEditingController());
  }

  void _recomputeDistribution() {
    final amounts = <int, double>{
      for (final id in _selectedHotelIds) id: double.tryParse(_shareControllers[id]?.text.replaceAll(',', '') ?? '') ?? 0,
    };
    final result = ExpenseDistributionEngine.distribute(
      total: _totalAmount,
      propertyIds: _selectedHotelIds.toList(),
      manuallyEditedIds: _manuallyEditedIds,
      currentAmounts: amounts,
    );
    _suppressAutoUpdate = true;
    for (final id in _selectedHotelIds) {
      if (_manuallyEditedIds.contains(id)) continue;
      final v = result[id] ?? 0;
      _controllerFor(id).text = v == 0 ? '' : NumberFormat("#,##0.##").format(v);
    }
    _suppressAutoUpdate = false;
  }

  void _onTotalChanged() {
    setState(_recomputeDistribution);
  }

  void _onShareFieldChanged(int hotelId) {
    if (_suppressAutoUpdate) return;
    _manuallyEditedIds.add(hotelId);
    setState(_recomputeDistribution);
  }

  void _toggleHotel(int hotelId, bool checked) {
    setState(() {
      if (checked) {
        _selectedHotelIds.add(hotelId);
        _controllerFor(hotelId);
      } else {
        _selectedHotelIds.remove(hotelId);
        _manuallyEditedIds.remove(hotelId);
        _shareControllers.remove(hotelId)?.dispose();
      }
      _recomputeDistribution();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    final amounts = <int, double>{
      for (final id in _selectedHotelIds) id: double.tryParse(_shareControllers[id]!.text.replaceAll(',', '')) ?? 0,
    };

    final header = SharedExpense(
      id: widget.editing?.id,
      categoryId: _selectedCategory!.id!,
      description: _descriptionController.text.trim(),
      totalAmount: _totalAmount,
      fundingSource: _fundingSource!,
      date: dateStr,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.editing?.createdAt ?? '',
    );

    final reviewItems = [
      ReviewItem(label: "الوصف", value: header.description!.isEmpty ? _selectedCategory!.name : header.description!),
      ReviewItem(label: "التصنيف", value: _selectedCategory!.name),
      ReviewItem(label: "المبلغ الإجمالي", value: "${NumberFormat("#,##0.##").format(header.totalAmount)} ريال", color: AppColors.danger),
      ReviewItem(label: "مصدر التمويل", value: header.fundingSource, color: Colors.blue),
      ReviewItem(label: "عدد المنشآت", value: "${_selectedHotelIds.length}"),
      for (final id in _selectedHotelIds)
        ReviewItem(
          label: _operationalHotels.firstWhere((h) => h.id == id).arabicName,
          value: "${NumberFormat("#,##0.##").format(amounts[id])} ريال",
        ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: _isEditing ? "مراجعة تعديل المصروف المشترك" : "مراجعة المصروف المشترك",
          items: reviewItems,
          onConfirm: () async {
            if (_isEditing) {
              await _repository.updateSharedExpense(header: header, hotelAmounts: amounts, date: dateStr);
            } else {
              await _repository.createSharedExpense(header: header, hotelAmounts: amounts, date: dateStr, time: timeStr);
            }
            if (mounted) {
              Navigator.pop(context); // إغلاق المراجعة
              Navigator.pop(context, true); // إغلاق شاشة الإنشاء/التعديل
            }
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _isSaving = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(_isEditing ? "تعديل مصروف مشترك" : "مصروف مشترك"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Column(
                      children: [
                        _buildMainCard(),
                        const SizedBox(height: AppSizes.lg),
                        if (_amountEntered) ...[
                          _buildFundingCard(),
                          const SizedBox(height: AppSizes.lg),
                          _buildPropertiesCard(),
                          const SizedBox(height: AppSizes.xl),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_amountEntered) _buildLiveBalanceBar(),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: AppButton(text: "مراجعة وحفظ", onPressed: _canSave ? _save : null),
                ),
              ],
            ),
    );
  }

  Widget _buildMainCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("تفاصيل المصروف المشترك", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.md),
          _buildCategoryDropdown(),
          const SizedBox(height: AppSizes.md),
          AppTextField(controller: _descriptionController, hint: "الوصف (مثلاً: صيانة نظام مشترك)", icon: Icons.description, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSizes.md),
          AppTextField(controller: _totalController, hint: "المبلغ الإجمالي", icon: Icons.attach_money, formatThousands: true, onChanged: (_) => _onTotalChanged()),
          const SizedBox(height: AppSizes.md),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(children: [
                const Icon(Icons.event_outlined),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy-MM-dd').format(_date), style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          AppTextField(controller: _notesController, hint: "ملاحظات (اختياري)", icon: Icons.notes_outlined, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: Colors.grey[300]!)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ExpenseCategory>(
          value: _selectedCategory,
          isExpanded: true,
          hint: const Text("اختر نوع المصروف"),
          items: _categories
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(children: [
                      Icon(IconData(c.iconCode, fontFamily: 'MaterialIcons'), color: Color(c.colorValue), size: 20),
                      const SizedBox(width: 12),
                      Text(c.name),
                    ]),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
        ),
      ),
    );
  }

  Widget _buildFundingCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("مصدر التمويل", style: AppTextStyles.bodyBold),
          const SizedBox(height: 4),
          const Text("كيف تُموَّل حصة كل منشأة — بنفس المصدر لكل المنشآت المختارة.", style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _fundingChip(SharedExpense.fundingCash, Icons.money),
              _fundingChip(SharedExpense.fundingTreasury, Icons.lock_outline),
              _fundingChip(SharedExpense.fundingNetwork, Icons.credit_card),
              _fundingChip(SharedExpense.fundingOwner, Icons.person_outline),
            ],
          ),
          if (_fundingSource == SharedExpense.fundingOwner) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: const Text(
                "المالك يموِّل حصة كل منشأة من ماله الخاص — لا يُخصَم أي مبلغ من نقد/شبكة/خزنة أي منشأة، وتُنشأ تلقائياً ذمة على كل منشأة لصالح المالك.",
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fundingChip(String label, IconData icon) {
    final selected = _fundingSource == label;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      selected: selected,
      onSelected: (_) => setState(() => _fundingSource = label),
    );
  }

  Widget _buildPropertiesCard() {
    if (_fundingSource == null) {
      return const AppCard(child: Text("اختر مصدر التمويل أولاً لتحديد المنشآت المشارِكة.", style: AppTextStyles.caption));
    }
    if (_operationalHotels.isEmpty) {
      return const AppCard(child: Text("لا توجد منشآت نشطة متاحة حالياً.", style: AppTextStyles.caption));
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("المنشآت وحصة كل منها", style: AppTextStyles.bodyBold),
          const SizedBox(height: 2),
          const Text("التوزيع تلقائي بالتساوي — عدّل أي حصة يدوياً وسيُعاد توزيع الباقي على البقية فوراً.", style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.sm),
          for (final h in _operationalHotels) _propertyRow(h),
        ],
      ),
    );
  }

  Widget _propertyRow(Hotel h) {
    final checked = _selectedHotelIds.contains(h.id);
    final isManual = _manuallyEditedIds.contains(h.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Checkbox(value: checked, onChanged: (v) => _toggleHotel(h.id!, v ?? false)),
          Expanded(
            flex: 2,
            child: Text(h.arabicName, style: AppTextStyles.body.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (checked)
            Expanded(
              child: AppTextField(
                controller: _controllerFor(h.id!),
                hint: isManual ? "الحصة" : "تلقائي",
                formatThousands: true,
                onChanged: (_) => _onShareFieldChanged(h.id!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveBalanceBar() {
    final over = _remainingAmount < -0.01;
    final numberFmt = NumberFormat("#,##0.##");
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
      color: over ? AppColors.danger.withValues(alpha: 0.08) : Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _balanceStat("الإجمالي", "${numberFmt.format(_totalAmount)} ريال"),
          _balanceStat("الموزَّع", "${numberFmt.format(_distributedAmount)} ريال"),
          _balanceStat(
            over ? "زيادة" : "المتبقي",
            "${numberFmt.format(_remainingAmount.abs())} ريال",
            color: over ? AppColors.danger : (_isBalanced ? Colors.green : null),
          ),
        ],
      ),
    );
  }

  Widget _balanceStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: color)),
      ],
    );
  }
}
