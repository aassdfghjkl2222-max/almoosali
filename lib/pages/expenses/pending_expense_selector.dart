import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/pending_expense.dart';
import '../../models/hotel.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../widgets/app_button.dart';
import 'add_pending_expense_page.dart';

class PendingExpenseSelector extends StatefulWidget {
  final Hotel currentHotel;
  final Set<int> initialSelected;
  const PendingExpenseSelector({super.key, required this.currentHotel, required this.initialSelected});

  @override
  State<PendingExpenseSelector> createState() => _PendingExpenseSelectorState();
}

class _PendingExpenseSelectorState extends State<PendingExpenseSelector> {
  final _repository = ExpenseRepository();
  final _hotelRepo = HotelRepository();
  List<PendingExpense> _expenses = [];
  List<Hotel> _allHotels = [];
  bool _isLoading = true;
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelected);
    _loadData();
  }

  Future<void> _loadData() async {
    final expenses = await _repository.getPendingExpenses(hotelId: widget.currentHotel.id!, isTransferred: false);
    final hotels = await _hotelRepo.getAllHotelsIncludingArchived();
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _allHotels = hotels;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildSelectAll(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _expenses.isEmpty 
                ? const Center(child: Text("لا توجد مصروفات معلقة"))
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) => _buildExpenseItem(_expenses[index]),
                  ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("المصروفات المعلقة", style: AppTextStyles.title.copyWith(fontSize: 18)),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _buildSelectAll() {
    if (_expenses.isEmpty) return const SizedBox.shrink();
    bool allSelected = _selectedIds.length == _expenses.length;
    return CheckboxListTile(
      title: const Text("تحديد الكل", style: AppTextStyles.bodyBold),
      value: allSelected,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            _selectedIds = _expenses.map((e) => e.id!).toSet();
          } else {
            _selectedIds.clear();
          }
        });
      },
    );
  }

  Widget _buildExpenseItem(PendingExpense exp) {
    bool isSelected = _selectedIds.contains(exp.id);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (val) {
            setState(() {
              if (val == true) _selectedIds.add(exp.id!);
              else _selectedIds.remove(exp.id!);
            });
          },
        ),
        title: Text(exp.statement, style: AppTextStyles.bodyBold),
        subtitle: Text(
          exp.isDeferredDebt && exp.supplierName != null
              ? "${exp.categoryName} • ${exp.paymentMethod} (${exp.supplierName}) • ${exp.amount}"
              : exp.isFundedByOtherHotel
                  ? "${exp.categoryName} • ${exp.paymentMethod} • ${exp.amount} • 🏨 ممول خارجياً"
                  : "${exp.categoryName} • ${exp.paymentMethod} • ${exp.amount}",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editExpense(exp)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteExpense(exp)),
          ],
        ),
      ),
    );
  }

  Future<void> _editExpense(PendingExpense exp) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPendingExpensePage(
          hotel: widget.currentHotel,
          editExpense: exp,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteExpense(PendingExpense exp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حذف مصروف"),
        content: const Text("هل أنت متأكد من حذف هذا المصروف المعلق؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _repository.deletePendingExpense(exp.id!);
      _loadData();
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
      child: AppButton(
        text: "تأكيد المختارة (${_selectedIds.length})",
        onPressed: () => Navigator.pop(context, _selectedIds),
      ),
    );
  }
}
