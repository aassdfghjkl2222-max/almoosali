import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/expense_category.dart';
import '../../models/hotel.dart';
import '../../models/shared_expense_group.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/shared_expense_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../common/transaction_review_page.dart';

/// "المصروف المشترك": مصروف واحد تدفعه منشأة بالكامل من [_selectedPaymentMethod]،
/// ويُوزَّع أثره على عدة منشآت مشارِكة. القيود المحاسبية تُنفَّذ فوراً عند
/// الحفظ (راجع FinancialEngine.recordSharedExpense) — لا ترحيل لاحق.
class AddSharedExpensePage extends StatefulWidget {
  final Hotel? initialFundingHotel;
  const AddSharedExpensePage({super.key, this.initialFundingHotel});

  @override
  State<AddSharedExpensePage> createState() => _AddSharedExpensePageState();
}

class _AddSharedExpensePageState extends State<AddSharedExpensePage> {
  final _repository = SharedExpenseRepository();
  final _expenseRepository = ExpenseRepository();
  final _hotelRepository = HotelRepository();

  final _totalController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<Hotel> _allHotels = [];
  ExpenseCategory? _selectedCategory;
  Hotel? _fundingHotel;
  String? _paymentMethod;
  bool _isLoading = true;
  bool _isSaving = false;

  final Set<int> _selectedHotelIds = {};
  final Map<int, TextEditingController> _shareControllers = {};

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
  bool get _isBalanced => _amountEntered && (_remainingAmount.abs() <= 0.001);

  bool get _canSave =>
      _amountEntered &&
      _selectedCategory != null &&
      _fundingHotel != null &&
      _paymentMethod != null &&
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
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final categories = await _expenseRepository.getCategories();
    final hotels = await _hotelRepository.getAllHotels();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _allHotels = hotels;
      _fundingHotel = widget.initialFundingHotel;
      if (_fundingHotel != null) _ensureFundingHotelSelected();
      _isLoading = false;
    });
  }

  TextEditingController _controllerFor(int hotelId) {
    return _shareControllers.putIfAbsent(hotelId, () => TextEditingController());
  }

  void _ensureFundingHotelSelected() {
    final funder = _fundingHotel;
    if (funder?.id == null) return;
    _selectedHotelIds.add(funder!.id!);
    _controllerFor(funder.id!);
  }

  void _pickFundingHotel() {
    showModalBottomSheet<Hotel>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
              child: Align(alignment: Alignment.centerRight, child: Text("مصدر التمويل (من دفع المبلغ كاملاً؟)", style: AppTextStyles.bodyBold)),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final h in _allHotels)
                    RadioListTile<int>(
                      title: Text(h.arabicName),
                      value: h.id!,
                      groupValue: _fundingHotel?.id,
                      onChanged: (_) => Navigator.pop(sheetContext, h),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((h) {
      if (h == null) return;
      setState(() {
        _fundingHotel = h;
        _ensureFundingHotelSelected();
      });
    });
  }

  void _toggleHotel(int hotelId, bool checked) {
    setState(() {
      if (checked) {
        _selectedHotelIds.add(hotelId);
        _controllerFor(hotelId);
      } else {
        if (hotelId == _fundingHotel?.id) return; // المموِّل لا يُستبعَد
        _selectedHotelIds.remove(hotelId);
      }
    });
  }

  void _save() {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    final funder = _fundingHotel!;
    final now = DateTime.now();
    final shares = <int, double>{
      for (final id in _selectedHotelIds) id: double.tryParse(_shareControllers[id]!.text.replaceAll(',', '')) ?? 0,
    };
    final otherHotelsCount = _selectedHotelIds.where((id) => id != funder.id).length;

    final group = SharedExpenseGroup(
      description: _descriptionController.text.trim(),
      categoryId: _selectedCategory!.id!,
      totalAmount: _totalAmount,
      paymentMethod: _paymentMethod!,
      fundingHotelId: funder.id!,
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('HH:mm:ss').format(now),
      createdAt: now.toIso8601String(),
    );

    final reviewItems = [
      ReviewItem(label: "البيان", value: group.description.isEmpty ? _selectedCategory!.name : group.description),
      ReviewItem(label: "النوع", value: _selectedCategory!.name),
      ReviewItem(label: "المبلغ الإجمالي", value: "${NumberFormat("#,##0.##").format(group.totalAmount)} ريال", color: AppColors.danger),
      ReviewItem(label: "مصدر التمويل", value: funder.arabicName, color: Colors.teal),
      ReviewItem(label: "طريقة الدفع", value: group.paymentMethod, color: Colors.blue),
      ReviewItem(label: "عدد المنشآت المشارِكة", value: "$otherHotelsCount + المموِّل"),
      for (final id in _selectedHotelIds)
        ReviewItem(
          label: _allHotels.firstWhere((h) => h.id == id).arabicName + (id == funder.id ? " (مموِّل)" : ""),
          value: "${NumberFormat("#,##0.##").format(shares[id])} ريال",
        ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: "مراجعة المصروف المشترك",
          items: reviewItems,
          onConfirm: () async {
            await _repository.createSharedExpense(group: group, shares: shares);
            if (mounted) {
              Navigator.pop(context); // Close Review
              Navigator.pop(context, true); // Close Add Page
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
      appBar: AppBar(title: const Text("مصروف مشترك"), centerTitle: true),
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
                          _buildParticipantsCard(),
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
          AppTextField(controller: _descriptionController, hint: "الوصف (مثلاً: صيانة نظام مشترك)", icon: Icons.description),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _totalController,
            hint: "المبلغ الإجمالي",
            icon: Icons.attach_money,
            formatThousands: true,
            onChanged: (_) => setState(() {}),
          ),
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
          const Text("مصدر التمويل وطريقة الدفع", style: AppTextStyles.bodyBold),
          const SizedBox(height: 4),
          const Text("المنشأة التي تدفع كامل المبلغ فعلياً — يُخصَم منها المبلغ الإجمالي كاملاً.", style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.sm),
          InkWell(
            onTap: _pickFundingHotel,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(children: [
                const Icon(Icons.apartment_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(_fundingHotel?.arabicName ?? "اختيار المنشأة المموِّلة", style: _fundingHotel == null ? AppTextStyles.caption : AppTextStyles.bodyBold.copyWith(fontSize: 13))),
                const Icon(Icons.arrow_drop_down),
              ]),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              _paymentMethodChip("نقد", Icons.money),
              const SizedBox(width: 8),
              _paymentMethodChip("شبكة", Icons.credit_card),
              const SizedBox(width: 8),
              _paymentMethodChip("تحويل بنكي", Icons.account_balance),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodChip(String label, IconData icon) {
    final selected = _paymentMethod == label;
    return Expanded(
      child: ChoiceChip(
        label: Text(label, textAlign: TextAlign.center),
        avatar: Icon(icon, size: 16),
        selected: selected,
        onSelected: (_) => setState(() => _paymentMethod = label),
      ),
    );
  }

  Widget _buildParticipantsCard() {
    if (_fundingHotel == null) {
      return const AppCard(child: Text("اختر مصدر التمويل أولاً لتحديد المنشآت المشارِكة.", style: AppTextStyles.caption));
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("المنشآت المشارِكة وحصة كل منها", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          for (final h in _allHotels) _participantRow(h),
        ],
      ),
    );
  }

  Widget _participantRow(Hotel h) {
    final isFunder = h.id == _fundingHotel?.id;
    final checked = _selectedHotelIds.contains(h.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: isFunder ? null : (v) => _toggleHotel(h.id!, v ?? false),
          ),
          Expanded(
            flex: 2,
            child: Text(
              h.arabicName + (isFunder ? " (مموِّل)" : ""),
              style: isFunder ? AppTextStyles.bodyBold.copyWith(fontSize: 13) : AppTextStyles.body.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (checked)
            Expanded(
              child: AppTextField(
                controller: _controllerFor(h.id!),
                hint: "الحصة",
                formatThousands: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveBalanceBar() {
    final over = _remainingAmount < -0.001;
    final numberFmt = NumberFormat("#,##0.##");
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
      color: over ? AppColors.danger.withOpacity(0.08) : Colors.grey.shade100,
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
