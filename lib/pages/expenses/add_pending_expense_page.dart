import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/expense_category.dart';
import '../../models/hotel.dart';
import '../../models/pending_expense.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../services/financial_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/hotel_identity_title.dart';
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
  final _financialEngine = FinancialEngine();
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _statementController = TextEditingController();
  final _notesController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<Hotel> _allHotels = [];
  ExpenseCategory? _selectedCategory;
  String _fundingSource = 'cash'; // cash, bank, personal, private, entity
  Hotel? _otherHotel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.editExpense != null) {
      _amountController.text = NumberFormat("#,##0.##").format(widget.editExpense!.amount);
      _statementController.text = widget.editExpense!.statement;
      _notesController.text = widget.editExpense!.notes ?? "";
      // Initialize other fields based on editExpense if needed
    }
  }

  Future<void> _loadData() async {
    final categories = await _repository.getCategories(widget.hotel.id!);
    final hotels = await _hotelRepository.getAllHotels();
    if (mounted) {
      setState(() {
        _categories = categories;
        _allHotels = hotels.where((h) => h.id != widget.hotel.id).toList();
        _isLoading = false;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار نوع المصروف")));
      return;
    }
    if (_fundingSource == 'entity' && _otherHotel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار المنشأة الأخرى")));
      return;
    }

    final now = DateTime.now();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    String sourceName = _fundingSource == 'cash' ? 'نقد' :
                        _fundingSource == 'bank' ? 'شبكة' :
                        _fundingSource == 'personal' ? 'شخصي' :
                        _fundingSource == 'private' ? 'مصروف خاص' : _otherHotel!.arabicName;

    final expense = PendingExpense(
      id: widget.editExpense?.id,
      hotelId: widget.hotel.id!,
      amount: amount,
      paymentMethod: sourceName,
      categoryId: _selectedCategory!.id!,
      categoryName: _selectedCategory!.name,
      statement: _statementController.text.trim(),
      notes: _notesController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('HH:mm:ss').format(now),
      createdAt: now.toIso8601String(),
    );

    // الانتقال للمراجعة النهائية
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: "مراجعة المصروف",
          items: [
            ReviewItem(label: "البيان", value: expense.statement),
            ReviewItem(label: "المبلغ", value: "${NumberFormat("#,##0.##").format(expense.amount)} ريال", color: AppColors.danger),
            ReviewItem(label: "النوع", value: expense.categoryName ?? ""),
            ReviewItem(label: "مصدر التمويل", value: expense.paymentMethod, color: Colors.blue),
          ],
          onConfirm: () async {
            if (widget.editExpense == null) {
              await _repository.addPendingExpense(expense);
            } else {
              await _repository.updatePendingExpense(expense);
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
      backgroundColor: AppColors.background,
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
                    _buildMainCard(),
                    const SizedBox(height: AppSizes.lg),
                    _buildFundingSourceCard(),
                    const SizedBox(height: AppSizes.xl),
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
          ),
          const SizedBox(height: AppSizes.md),
          _buildCategoryDropdown(),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _statementController,
            hint: "البيان (مثلاً: فواتير كهرباء شهر 5)",
            icon: Icons.description,
          ),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _notesController,
            hint: "الملاحظات (اختياري)",
            icon: Icons.note_alt_outlined,
            maxLines: 2,
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
          onChanged: (v) => setState(() => _selectedCategory = v),
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
          const SizedBox(height: AppSizes.md),
          _buildSourceRadio('cash', 'نقد (الخزنة)', Icons.money),
          _buildSourceRadio('bank', 'شبكة (البنك)', Icons.credit_card),
          _buildSourceRadio('entity', 'فندق آخر', Icons.business),
          if (_fundingSource == 'entity') _buildOtherHotelSelector(),
          _buildSourceRadio('personal', 'شخصي (من مال المالك)', Icons.person_add_alt),
          _buildSourceRadio('private', 'مصروف خاص (لصالح المالك)', Icons.person_off_outlined),
        ],
      ),
    );
  }

  Widget _buildSourceRadio(String value, String label, IconData icon) {
    return RadioListTile<String>(
      value: value,
      groupValue: _fundingSource,
      title: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.body),
        ],
      ),
      onChanged: (v) => setState(() => _fundingSource = v!),
      activeColor: Theme.of(context).colorScheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildOtherHotelSelector() {
    return Padding(
      padding: const EdgeInsets.only(right: 48, bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Hotel>(
            value: _otherHotel,
            hint: const Text("اختر الفندق الممول"),
            isExpanded: true,
            items: _allHotels.map((h) => DropdownMenuItem(value: h, child: Text(h.arabicName))).toList(),
            onChanged: (v) => setState(() => _otherHotel = v),
          ),
        ),
      ),
    );
  }
}
