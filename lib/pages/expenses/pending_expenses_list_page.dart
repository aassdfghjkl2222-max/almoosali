import 'package:flutter/material.dart';
// ignore_for_file: non_const_argument_for_const_parameter
import 'package:intl/intl.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_radius.dart';
import '../../models/hotel.dart';
import '../../models/pending_expense.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';
import 'add_pending_expense_page.dart';
import 'expense_reports_page.dart';

class PendingExpensesListPage extends StatefulWidget {
  final Hotel hotel;
  const PendingExpensesListPage({super.key, required this.hotel});

  @override
  State<PendingExpensesListPage> createState() => _PendingExpensesListPageState();
}

class _PendingExpensesListPageState extends State<PendingExpensesListPage> {
  final _repository = ExpenseRepository();
  List<PendingExpense> _allExpenses = [];
  List<PendingExpense> _filteredExpenses = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _sortBy = 'date'; // 'date', 'amount', 'type'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final expenses = await _repository.getPendingExpenses(
      hotelId: widget.hotel.id!,
      isTransferred: false,
    );
    setState(() {
      _allExpenses = expenses;
      _filteredExpenses = expenses;
      _isLoading = false;
      _applySearchAndSort();
    });
  }

  void _applySearchAndSort() {
    List<PendingExpense> results = List.from(_allExpenses);

    // Search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      results = results.where((e) {
        return (e.statement.toLowerCase().contains(query)) ||
            (e.categoryName?.toLowerCase().contains(query) ?? false) ||
            (e.amount.toString().contains(query));
      }).toList();
    }

    // Sort
    if (_sortBy == 'date') {
      results.sort((a, b) => "${b.date} ${b.time}".compareTo("${a.date} ${a.time}"));
    } else if (_sortBy == 'amount') {
      results.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortBy == 'type') {
      results.sort((a, b) => (a.categoryName ?? "").compareTo(b.categoryName ?? ""));
    }

    setState(() {
      _filteredExpenses = results;
    });
  }

  Widget _buildSourceTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "المصروفات المعلقة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpenseReportsPage(hotel: widget.hotel),
                ),
              );
            },
            tooltip: "التقارير والإحصائيات",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _applySearchAndSort();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'date', child: Text("التاريخ (الأحدث)")),
              const PopupMenuItem(value: 'amount', child: Text("المبلغ (الأعلى)")),
              const PopupMenuItem(value: 'type', child: Text("النوع")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "بحث في المصروفات...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) => _applySearchAndSort(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExpenses.isEmpty
                    ? const Center(child: Text("لا توجد مصروفات معلقة"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                        itemCount: _filteredExpenses.length,
                        itemBuilder: (context, index) {
                          final expense = _filteredExpenses[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSizes.md),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSizes.sm),
                                    decoration: BoxDecoration(
                                      color: expense.categoryColor != null
                                        ? Color(expense.categoryColor!).withOpacity(0.1)
                                        : identityColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Icon(
                                      expense.categoryIcon != null
                                        ? IconData(expense.categoryIcon!, fontFamily: 'MaterialIcons')
                                        : Icons.payments,
                                      color: expense.categoryColor != null
                                        ? Color(expense.categoryColor!)
                                        : identityColor,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.statement,
                                          style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              "${expense.categoryName} • ${expense.paymentMethod}",
                                              style: AppTextStyles.caption,
                                            ),
                                            if (expense.amountSource == 'حساب شخصي') ...[
                                              const SizedBox(width: 8),
                                              _buildSourceTag("🟣 شخصي", Colors.purple),
                                            ],
                                            if (expense.amountSource == 'منشأة أخرى') ...[
                                              const SizedBox(width: 8),
                                              _buildSourceTag("🟠 دين", Colors.orange),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currencyFormat.format(expense.amount),
                                        style: AppTextStyles.subtitle.copyWith(
                                        color: identityColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      ),
                                      Text(
                                        "${expense.date} ${expense.time}",
                                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPendingExpensePage(hotel: widget.hotel),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        label: const Text("إضافة مصروف"),
        icon: const Icon(Icons.add),
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
