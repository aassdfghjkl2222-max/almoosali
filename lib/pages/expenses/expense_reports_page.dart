import 'package:flutter/material.dart';
// ignore_for_file: non_const_argument_for_const_parameter
import 'package:intl/intl.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/pending_expense.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';

class ExpenseReportsPage extends StatefulWidget {
  final Hotel hotel;
  const ExpenseReportsPage({super.key, required this.hotel});

  @override
  State<ExpenseReportsPage> createState() => _ExpenseReportsPageState();
}

class _ExpenseReportsPageState extends State<ExpenseReportsPage> {
  final _repository = ExpenseRepository();
  List<PendingExpense> _expenses = [];
  bool _isLoading = true;
  String _period = 'month'; // 'day', 'week', 'month', 'year', 'custom'
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // For simplicity, we fetch all expenses for this hotel and filter in memory
    // In a real app, this should be done in SQL
    final expenses = await _repository.getPendingExpenses(
      hotelId: widget.hotel.id!,
      // We want both pending and transferred for statistics
    );

    // Filter by period
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_period == 'day') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_period == 'week') {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
    } else if (_period == 'month') {
      start = DateTime(now.year, now.month, 1);
    } else if (_period == 'year') {
      start = DateTime(now.year, 1, 1);
    } else if (_period == 'custom' && _customRange != null) {
      start = _customRange!.start;
      end = _customRange!.end.add(const Duration(hours: 23, minutes: 59));
    } else {
      start = DateTime(now.year, now.month, 1);
    }

    final filtered = expenses.where((e) {
      final date = DateTime.tryParse(e.date) ?? DateTime.now();
      return date.isAfter(start.subtract(const Duration(seconds: 1))) && 
             date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    setState(() {
      _expenses = filtered;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "تقارير وإحصائيات المصروفات", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? const Center(child: Text("لا توجد بيانات لهذه الفترة"))
                    : ListView(
                        padding: const EdgeInsets.all(AppSizes.md),
                        children: [
                          _buildSummaryCard(identityColor),
                          const SizedBox(height: AppSizes.lg),
                          _buildBreakdownSection(),
                          const SizedBox(height: AppSizes.lg),
                          _buildRecentExpensesSection(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        child: Row(
          children: [
            _buildPeriodTab("اليوم", 'day'),
            _buildPeriodTab("الأسبوع", 'week'),
            _buildPeriodTab("الشهر", 'month'),
            _buildPeriodTab("السنة", 'year'),
            _buildPeriodTab("مخصص", 'custom'),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String label, String value) {
    final isSelected = _period == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) async {
          if (value == 'custom') {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _period = value;
                _customRange = picked;
              });
              _loadData();
            }
          } else {
            setState(() => _period = value);
            _loadData();
          }
        },
        selectedColor: HotelVisualIdentity.colorForHotel(widget.hotel),
        labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  Widget _buildSummaryCard(Color identityColor) {
    final total = _expenses.fold(0.0, (sum, e) => sum + e.amount);
    final cash = _expenses.where((e) => e.paymentMethod == 'نقد').fold(0.0, (sum, e) => sum + e.amount);
    final network = _expenses.where((e) => e.paymentMethod == 'شبكة').fold(0.0, (sum, e) => sum + e.amount);

    return AppCard(
      color: identityColor,
      child: Column(
        children: [
          const Text("إجمالي المصروفات", style: TextStyle(color: Colors.white70)),
          Text(
            "${NumberFormat.currency(symbol: '', decimalDigits: 2).format(total)} ر.س",
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem("نقد", cash),
              _buildSummaryItem("شبكة", network),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(
          NumberFormat("#,##0.00").format(amount),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBreakdownSection() {
    final Map<String, _CategoryStats> categories = {};
    for (var e in _expenses) {
      final name = e.categoryName ?? "أخرى";
      if (!categories.containsKey(name)) {
        categories[name] = _CategoryStats(
          name: name,
          amount: 0,
          color: e.categoryColor != null ? Color(e.categoryColor!) : HotelVisualIdentity.colorForHotel(widget.hotel),
          icon: e.categoryIcon != null
            ? IconData(e.categoryIcon!, fontFamily: 'MaterialIcons') 
            : Icons.category,
        );
      }
      categories[name]!.amount += e.amount;
    }

    final sorted = categories.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
    final total = _expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("تحليل الفئات", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSizes.md),
        AppCard(
          child: Column(
            children: sorted.map((stats) {
              final percentage = total > 0 ? stats.amount / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(stats.icon, size: 16, color: stats.color),
                        const SizedBox(width: 8),
                        Text(stats.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text("${NumberFormat("#,##0.00").format(stats.amount)} ر.س (${(percentage * 100).toStringAsFixed(1)}%)"),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: stats.color.withOpacity(0.1),
                        color: stats.color,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentExpensesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("قائمة المصروفات", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSizes.md),
        ..._expenses.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
          child: AppCard(
            padding: const EdgeInsets.all(AppSizes.sm),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: e.categoryColor != null ? Color(e.categoryColor!).withOpacity(0.1) : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  e.categoryIcon != null ? IconData(e.categoryIcon!, fontFamily: 'MaterialIcons') : Icons.payments,
                  color: e.categoryColor != null ? Color(e.categoryColor!) : HotelVisualIdentity.colorForHotel(widget.hotel),
                  size: 20,
                ),
              ),
              title: Text(e.statement),
              subtitle: Text("${e.categoryName} • ${e.date}"),
              trailing: Text(
                NumberFormat("#,##0.00").format(e.amount),
                style: TextStyle(fontWeight: FontWeight.bold, color: HotelVisualIdentity.colorForHotel(widget.hotel)),
              ),
              dense: true,
            ),
          ),
        )),
      ],
    );
  }
}

class _CategoryStats {
  final String name;
  double amount;
  final Color color;
  final IconData icon;

  _CategoryStats({required this.name, required this.amount, required this.color, required this.icon});
}
