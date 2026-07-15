import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../models/pending_expense.dart';
import '../../../repositories/expense_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import 'analysis_charts.dart';

/// تحليل بند مصروف واحد (مثال: كهرباء) — قراءة فقط بالكامل. يجلب كل عمليات
/// هذا البند (بلا حدود زمنية) ثم يحسب إجمالي السنة/الشهر والمتوسط والأعلى
/// والأقل ونسبة التغيّر من بيانات pending_expenses الحقيقية.
class ExpenseCategoryDetailPage extends StatefulWidget {
  final Hotel hotel;
  final List<int> hotelIds;
  final String categoryName;
  final Color color;

  const ExpenseCategoryDetailPage({
    super.key,
    required this.hotel,
    required this.hotelIds,
    required this.categoryName,
    required this.color,
  });

  @override
  State<ExpenseCategoryDetailPage> createState() => _ExpenseCategoryDetailPageState();
}

class _ExpenseCategoryDetailPageState extends State<ExpenseCategoryDetailPage> {
  final _repo = ExpenseRepository();
  bool _isLoading = true;
  List<PendingExpense> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.getExpenseTransactionsByCategory(hotelIds: widget.hotelIds, categoryName: widget.categoryName);
    if (!mounted) return;
    setState(() {
      _all = data;
      _isLoading = false;
    });
  }

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  double get _yearTotal {
    final now = DateTime.now();
    return _all.where((e) => e.date.startsWith("${now.year}")).fold(0.0, (s, e) => s + e.amount);
  }

  double get _monthTotal {
    final now = DateTime.now();
    final prefix = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    return _all.where((e) => e.date.startsWith(prefix)).fold(0.0, (s, e) => s + e.amount);
  }

  double get _previousMonthTotal {
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final prefix = "${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}";
    return _all.where((e) => e.date.startsWith(prefix)).fold(0.0, (s, e) => s + e.amount);
  }

  double get _average => _all.isEmpty ? 0 : _all.fold(0.0, (s, e) => s + e.amount) / _all.length;
  double get _maxAmount => _all.isEmpty ? 0 : _all.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
  double get _minAmount => _all.isEmpty ? 0 : _all.map((e) => e.amount).reduce((a, b) => a < b ? a : b);

  double? get _monthChangePercent {
    if (_previousMonthTotal <= 0) return null;
    return ((_monthTotal - _previousMonthTotal) / _previousMonthTotal) * 100;
  }

  List<LinePoint> get _monthlyTrend {
    final now = DateTime.now();
    final points = <LinePoint>[];
    for (int i = 11; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final prefix = "${m.year}-${m.month.toString().padLeft(2, '0')}";
      final total = _all.where((e) => e.date.startsWith(prefix)).fold(0.0, (s, e) => s + e.amount);
      points.add(LinePoint(DateFormat('MM/yy').format(m), total));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    final change = _monthChangePercent;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "تحليل: ${widget.categoryName}", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildStatsGrid(),
                const SizedBox(height: AppSizes.lg),
                if (change != null) _buildChangeCard(change),
                if (change != null) const SizedBox(height: AppSizes.lg),
                AppCard(
                  identityAccent: widget.color,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("الاتجاه خلال ١٢ شهراً", style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                      const SizedBox(height: AppSizes.sm),
                      AnalysisLineChart(points: _monthlyTrend, color: widget.color),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Text("جميع العمليات (${_all.length})", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSizes.sm),
                if (_all.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("لا توجد عمليات مسجلة لهذا البند", style: TextStyle(color: Colors.grey))))
                else
                  ..._all.map((e) => _buildTransactionRow(e)),
              ],
            ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      ("إجمالي السنة", _format(_yearTotal)),
      ("إجمالي الشهر", _format(_monthTotal)),
      ("المتوسط", _format(_average)),
      ("أعلى قيمة", _format(_maxAmount)),
      ("أقل قيمة", _format(_minAmount)),
      ("عدد العمليات", "${_all.length}"),
    ];
    final rows = <Widget>[];
    for (int i = 0; i < stats.length; i += 2) {
      final second = i + 1 < stats.length ? stats[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _statCard(stats[i].$1, stats[i].$2)),
            const SizedBox(width: 12),
            Expanded(child: second != null ? _statCard(second.$1, second.$2) : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < stats.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _statCard(String label, String value) {
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 16, color: widget.color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildChangeCard(double change) {
    final isUp = change >= 0;
    final color = isUp ? AppColors.danger : AppColors.success; // ارتفاع مصروف = سلبي، انخفاضه = إيجابي
    return AppCard(
      child: Row(
        children: [
          Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${isUp ? 'ارتفع' : 'انخفض'} هذا البند بنسبة ${change.abs().toStringAsFixed(1)}٪ مقارنة بالشهر الماضي",
              style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(PendingExpense e) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: widget.color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.receipt_long_outlined, color: widget.color, size: 18),
        ),
        title: Text(e.statement, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text("${e.date} · ${e.paymentMethod}${e.isTransferred ? ' · مُرحَّل' : ' · معلّق'}", style: AppTextStyles.caption),
        trailing: Text(_format(e.amount), style: AppTextStyles.bodyBold.copyWith(color: widget.color)),
      ),
    );
  }
}
