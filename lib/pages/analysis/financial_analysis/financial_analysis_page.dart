import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/financial_report.dart';
import '../../../models/hotel.dart';
import '../../../repositories/employee_repository.dart';
import '../../../repositories/expense_repository.dart';
import '../../../repositories/financial_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import 'analysis_charts.dart';
import 'expense_category_detail_page.dart';
import 'revenue_drilldown_page.dart';

/// قسم "التحليل المالي" داخل مركز التحليل — شاشة قراءة فقط بالكامل. كل الأرقام
/// هنا محسوبة من بيانات حقيقية (financial_reports وpending_expenses وسجلات
/// الرواتب وأرصدة الخزنة)، باستثناء قسم "التحليل الذكي" الذي طُلب صراحة أن
/// يبقى واجهة فقط في هذه المرحلة دون ربط منطق تحليلي فعلي.
class FinancialAnalysisPage extends StatefulWidget {
  final Hotel hotel;
  const FinancialAnalysisPage({super.key, required this.hotel});

  @override
  State<FinancialAnalysisPage> createState() => _FinancialAnalysisPageState();
}

class _FinancialAnalysisPageState extends State<FinancialAnalysisPage> {
  static const _periods = ["يوم", "أسبوع", "نصف شهر", "شهر", "ربع سنة", "نصف سنة", "سنة", "فترة مخصصة"];
  static const _revenueDimensions = ["الفندق", "الشهر", "اليوم", "النوع", "المصدر"];

  final _financialRepo = FinancialRepository();
  final _expenseRepo = ExpenseRepository();
  final _employeeRepo = EmployeeRepository();
  final _engine = FinancialEngine();

  List<Hotel> _allHotels = [];
  Set<int> _selectedHotelIds = {};
  String _selectedPeriod = "شهر";
  DateTimeRange? _customRange;
  String _revenueDimension = "الفندق";

  bool _isLoading = true;
  List<FinancialReport> _reports = [];
  Map<String, double> _totals = {'income': 0, 'expenses': 0};
  Map<String, double> _prevTotals = {'income': 0, 'expenses': 0};
  List<Map<String, dynamic>> _expenseCategories = [];
  double _payrollTotal = 0;
  double _liquidityAssets = 0;
  double _liquidityLiabilities = 0;

  @override
  void initState() {
    super.initState();
    _selectedHotelIds = widget.hotel.id != null ? {widget.hotel.id!} : {};
    _init();
  }

  Future<void> _init() async {
    _allHotels = await HotelRepository().getAllHotels();
    await _loadAll();
  }

  Hotel? get _singleSelectedHotel {
    if (_selectedHotelIds.length != 1) return null;
    for (final h in _allHotels) {
      if (h.id == _selectedHotelIds.first) return h;
    }
    return widget.hotel;
  }

  Color get _identityColor {
    final single = _singleSelectedHotel;
    return single != null ? HotelVisualIdentity.colorForHotel(single) : AppColors.primary;
  }

  String get _hotelSummaryLabel {
    if (_allHotels.isEmpty || _selectedHotelIds.isEmpty) return "لا يوجد فندق محدد";
    if (_selectedHotelIds.length == _allHotels.length) return "جميع الفنادق (${_allHotels.length})";
    if (_selectedHotelIds.length == 1) return _singleSelectedHotel?.arabicName ?? "فندق واحد";
    return "${_selectedHotelIds.length} فنادق مختارة";
  }

  Map<int, String> get _hotelNames => {for (final h in _allHotels) if (h.id != null) h.id!: h.arabicName};

  DateTimeRange _rollingRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case "يوم":
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      case "أسبوع":
        return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      case "نصف شهر":
        return DateTimeRange(start: now.subtract(const Duration(days: 15)), end: now);
      case "شهر":
        return DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
      case "ربع سنة":
        return DateTimeRange(start: now.subtract(const Duration(days: 90)), end: now);
      case "نصف سنة":
        return DateTimeRange(start: now.subtract(const Duration(days: 182)), end: now);
      case "سنة":
        return DateTimeRange(start: now.subtract(const Duration(days: 365)), end: now);
      default:
        return DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    }
  }

  DateTimeRange get _range {
    if (_selectedPeriod == "فترة مخصصة" && _customRange != null) return _customRange!;
    return _rollingRange(_selectedPeriod);
  }

  DateTimeRange get _previousRange {
    final r = _range;
    final duration = r.end.difference(r.start);
    return DateTimeRange(start: r.start.subtract(duration), end: r.start);
  }

  int get _daysInRange => _range.end.difference(_range.start).inDays.clamp(1, 100000);

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final hotelIds = _selectedHotelIds.toList();
    final range = _range;
    final prevRange = _previousRange;

    final results = await Future.wait([
      _financialRepo.getTotals(hotelIds: hotelIds, fromDate: range.start, toDate: range.end),
      _financialRepo.getTotals(hotelIds: hotelIds, fromDate: prevRange.start, toDate: prevRange.end),
      _financialRepo.getReportsInRangeMultiHotel(hotelIds: hotelIds, fromDate: range.start, toDate: range.end),
      _expenseRepo.getExpenseTotalsByCategory(hotelIds: hotelIds, fromDate: range.start, toDate: range.end),
      _loadPayrollTotal(hotelIds, range),
      _loadLiquidity(hotelIds),
    ]);

    if (!mounted) return;
    setState(() {
      _totals = results[0] as Map<String, double>;
      _prevTotals = results[1] as Map<String, double>;
      _reports = results[2] as List<FinancialReport>;
      _expenseCategories = results[3] as List<Map<String, dynamic>>;
      _payrollTotal = results[4] as double;
      _isLoading = false;
    });
  }

  Future<double> _loadPayrollTotal(List<int> hotelIds, DateTimeRange range) async {
    final startPeriod = "${range.start.year}-${range.start.month.toString().padLeft(2, '0')}";
    final endPeriod = "${range.end.year}-${range.end.month.toString().padLeft(2, '0')}";
    double total = 0;
    for (final id in hotelIds) {
      final records = await _employeeRepo.getPayrollRecords(hotelId: id, startPeriod: startPeriod, endPeriod: endPeriod);
      total += records.fold(0.0, (s, r) => s + r.netSalary);
    }
    return total;
  }

  Future<void> _loadLiquidity(List<int> hotelIds) async {
    double assets = 0, liabilities = 0;
    for (final id in hotelIds) {
      assets += await _engine.getBalance(id, 'cash');
      assets += await _engine.getBalance(id, 'bank');
      liabilities += await _engine.getTotalLiability(id);
    }
    if (!mounted) return;
    setState(() {
      _liquidityAssets = assets;
      _liquidityLiabilities = liabilities;
    });
  }

  String _format(double v) => NumberFormat("#,##0.##").format(v);
  String _pct(double v) => "${v.toStringAsFixed(1)}٪";

  double get _income => _totals['income'] ?? 0;
  double get _expenses => _totals['expenses'] ?? 0;
  double get _net => _income - _expenses;
  double get _prevIncome => _prevTotals['income'] ?? 0;
  double get _prevExpenses => _prevTotals['expenses'] ?? 0;
  double get _prevNet => _prevIncome - _prevExpenses;

  double get _profitabilityRatio => _income > 0 ? (_net / _income * 100) : 0;
  double get _profitMargin => _expenses > 0 ? (_net / _expenses * 100) : 0;
  double get _expenseToIncomeRatio => _income > 0 ? (_expenses / _income * 100) : 0;
  double get _growthRate => _prevIncome > 0 ? ((_income - _prevIncome) / _prevIncome * 100) : 0;
  double get _avgDailyIncome => _income / _daysInRange;
  double get _avgDailyExpense => _expenses / _daysInRange;
  double get _avgMonthlyIncome => _income / (_daysInRange / 30).clamp(1, double.infinity);
  double get _salaryToIncomeRatio => _income > 0 ? (_payrollTotal / _income * 100) : 0;
  double get _electricityTotal {
    final row = _expenseCategories.firstWhere((c) => c['category_name'] == 'كهرباء', orElse: () => {'total': 0});
    return (row['total'] as num?)?.toDouble() ?? 0;
  }

  double get _electricityToIncomeRatio => _income > 0 ? (_electricityTotal / _income * 100) : 0;
  double get _liquidityRatio => _liquidityLiabilities > 0 ? (_liquidityAssets / _liquidityLiabilities * 100) : (_liquidityAssets > 0 ? 100 : 0);

  Map<String, double> _incomeDetailsSum() {
    double cash = 0, parkingCash = 0, pos = 0, parkingPos = 0, transfer = 0;
    for (final r in _reports) {
      if (r.detailsJson == null || r.detailsJson!.isEmpty) continue;
      try {
        final d = (jsonDecode(r.detailsJson!)['income_details'] as Map<String, dynamic>?) ?? {};
        cash += double.tryParse(d['cash']?.toString() ?? '0') ?? 0;
        parkingCash += double.tryParse(d['parking_cash']?.toString() ?? '0') ?? 0;
        pos += double.tryParse(d['pos']?.toString() ?? '0') ?? 0;
        parkingPos += double.tryParse(d['parking_pos']?.toString() ?? '0') ?? 0;
        transfer += double.tryParse(d['transfer']?.toString() ?? '0') ?? 0;
      } catch (_) {}
    }
    return {'cash': cash, 'parking_cash': parkingCash, 'pos': pos, 'parking_pos': parkingPos, 'transfer': transfer};
  }

  Future<void> _openHotelSelector() async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) {
        Set<int> temp = Set.from(_selectedHotelIds);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final allSelected = _allHotels.isNotEmpty && temp.length == _allHotels.length;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("اختيار الفنادق", style: AppTextStyles.title.copyWith(fontSize: 18)),
                    const SizedBox(height: AppSizes.sm),
                    CheckboxListTile(
                      title: const Text("جميع الفنادق", style: TextStyle(fontWeight: FontWeight.bold)),
                      value: allSelected,
                      onChanged: (v) => setSheetState(() {
                        temp = v == true ? _allHotels.map((h) => h.id!).toSet() : <int>{};
                      }),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allHotels.length,
                        itemBuilder: (_, i) {
                          final h = _allHotels[i];
                          return CheckboxListTile(
                            title: Text(h.arabicName),
                            secondary: CircleAvatar(radius: 10, backgroundColor: HotelVisualIdentity.colorForHotel(h)),
                            value: h.id != null && temp.contains(h.id),
                            onChanged: (v) => setSheetState(() {
                              if (h.id == null) return;
                              if (v == true) {
                                temp.add(h.id!);
                              } else {
                                temp.remove(h.id!);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _identityColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed: temp.isEmpty ? null : () => Navigator.pop(ctx, temp),
                      child: const Text("تطبيق"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _selectedHotelIds = result);
      await _loadAll();
    }
  }

  Future<void> _onPeriodSelected(String p) async {
    if (p == "فترة مخصصة") {
      final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: _customRange);
      if (range == null) return;
      setState(() {
        _selectedPeriod = p;
        _customRange = range;
      });
    } else {
      setState(() => _selectedPeriod = p);
    }
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final color = _identityColor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: color,
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("التحليل المالي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 3),
            Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
              child: Text(_hotelSummaryLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildFilterBar(color),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("الملخص المالي"),
                const SizedBox(height: AppSizes.sm),
                _buildSummaryGrid(color),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("مقارنة الفترات"),
                const SizedBox(height: AppSizes.sm),
                _buildComparisonCard(),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("تحليل الإيرادات"),
                const SizedBox(height: AppSizes.sm),
                _buildRevenueAnalysis(color),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("تحليل المصروفات"),
                const SizedBox(height: AppSizes.sm),
                _buildExpenseAnalysis(color),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("مؤشرات الأداء (KPIs)"),
                const SizedBox(height: AppSizes.sm),
                _buildKpiGrid(),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("التحليل الذكي"),
                const SizedBox(height: AppSizes.sm),
                _buildSmartInsights(color),
                const SizedBox(height: AppSizes.xl),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _buildFilterBar(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _openHotelSelector,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: color.withOpacity(0.25))),
            child: Row(
              children: [
                Icon(Icons.apartment, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_hotelSummaryLabel, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Icon(Icons.expand_more, color: color),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _periods.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = _periods[i];
              final selected = _selectedPeriod == p;
              return ChoiceChip(
                label: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textPrimary)),
                selected: selected,
                selectedColor: color,
                backgroundColor: Colors.white,
                shape: StadiumBorder(side: BorderSide(color: color.withOpacity(0.25))),
                onSelected: (_) => _onPeriodSelected(p),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openReportsDrilldown(String title, Color color, {ReportAmountSelector? amountSelector}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevenueDrilldownPage(hotel: widget.hotel, title: title, reports: _reports, allHotels: _allHotels, color: color, totalLabel: title, amountSelector: amountSelector),
      ),
    );
  }

  Widget _buildSummaryGrid(Color color) {
    final items = <(String, String, Color, VoidCallback?)>[
      ("إجمالي الإيرادات", _format(_income), const Color(0xFF1FA971), () => _openReportsDrilldown("إجمالي الإيرادات", const Color(0xFF1FA971))),
      ("إجمالي المصروفات", _format(_expenses), const Color(0xFFE0524A), () => _openReportsDrilldown("إجمالي المصروفات", const Color(0xFFE0524A), amountSelector: (r) => r.expenses)),
      ("صافي الربح", _format(_net), color, () => _openReportsDrilldown("صافي الربح", color, amountSelector: (r) => r.income - r.expenses)),
      ("نسبة الربحية", _pct(_profitabilityRatio), const Color(0xFF3B6FE0), null),
      ("معدل النمو", _pct(_growthRate), _growthRate >= 0 ? AppColors.success : AppColors.danger, null),
      ("متوسط الإيراد اليومي", _format(_avgDailyIncome), const Color(0xFF12B886), null),
      ("متوسط المصروف اليومي", _format(_avgDailyExpense), const Color(0xFFD9743C), null),
    ];
    return _buildStaticGrid(items.map((i) => _summaryCard(i.$1, i.$2, i.$3, onTap: i.$4)).toList(), columns: 2);
  }

  Widget _summaryCard(String label, String value, Color color, {VoidCallback? onTap}) {
    return AppCard(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.title.copyWith(fontSize: 18, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildComparisonCard() {
    final rows = [
      ("الإيرادات", _income, _prevIncome),
      ("المصروفات", _expenses, _prevExpenses),
      ("صافي الربح", _net, _prevNet),
    ];
    return AppCard(
      identityAccent: _identityColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("مقارنة \"$_selectedPeriod\" الحالية مع الفترة السابقة مباشرة", style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.md),
          ...rows.map((r) {
            final diff = r.$2 - r.$3;
            final pct = r.$3 != 0 ? (diff / r.$3.abs() * 100) : 0.0;
            final isUp = diff >= 0;
            final color = isUp ? AppColors.success : AppColors.danger;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(r.$1, style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
                  Expanded(flex: 2, child: Text(_format(r.$2), style: AppTextStyles.bodyBold.copyWith(fontSize: 13), textAlign: TextAlign.center)),
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: color),
                        const SizedBox(width: 2),
                        Flexible(child: Text("${_format(diff.abs())} (${pct.abs().toStringAsFixed(1)}٪)", style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRevenueAnalysis(Color color) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _revenueDimensions.map((d) {
              final selected = _revenueDimension == d;
              return ChoiceChip(
                label: Text(d, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
                selected: selected,
                selectedColor: color,
                onSelected: (_) => setState(() => _revenueDimension = d),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSizes.md),
          _buildRevenueChartAndList(color),
        ],
      ),
    );
  }

  Widget _buildRevenueChartAndList(Color color) {
    if (_reports.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: Text("لا توجد بيانات إيرادات لهذه الفترة", style: AppTextStyles.caption)));
    }
    switch (_revenueDimension) {
      case "الفندق":
        return _buildRevenueByGroup(
          groupKey: (r) => r.hotelId.toString(),
          groupLabel: (k) => _hotelNames[int.parse(k)] ?? 'فندق #$k',
          groupColor: (k) {
            final h = _allHotels.firstWhere((h) => h.id == int.parse(k), orElse: () => widget.hotel);
            return HotelVisualIdentity.colorForHotel(h);
          },
          tappable: true,
        );
      case "الشهر":
        return _buildRevenueByGroup(
          groupKey: (r) => r.date.substring(0, 7),
          groupLabel: (k) => DateFormat('MM/yyyy').format(DateTime.parse('$k-01')),
          groupColor: (_) => color,
          tappable: true,
        );
      case "اليوم":
        return _buildRevenueByGroup(
          groupKey: (r) => r.date,
          groupLabel: (k) => DateFormat('dd/MM').format(DateTime.parse(k)),
          groupColor: (_) => color,
          tappable: true,
          capToRecent: 30,
        );
      case "النوع":
        final d = _incomeDetailsSum();
        final points = [
          ChartPoint("نقد", d['cash']! + d['parking_cash']!, const Color(0xFF1FA971)),
          ChartPoint("شبكة", d['pos']! + d['parking_pos']!, const Color(0xFF8B5CF6)),
          ChartPoint("تحويل بنكي", d['transfer']!, const Color(0xFF3B6FE0)),
        ];
        return _buildChartWithLegend(points);
      case "المصدر":
        final d = _incomeDetailsSum();
        final points = [
          ChartPoint("غرف", d['cash']! + d['pos']! + d['transfer']!, const Color(0xFF14B8A6)),
          ChartPoint("باركنج", d['parking_cash']! + d['parking_pos']!, const Color(0xFFC7972C)),
        ];
        return _buildChartWithLegend(points);
      default:
        return const SizedBox();
    }
  }

  Widget _buildRevenueByGroup({
    required String Function(FinancialReport) groupKey,
    required String Function(String) groupLabel,
    required Color Function(String) groupColor,
    bool tappable = false,
    int? capToRecent,
  }) {
    final Map<String, List<FinancialReport>> grouped = {};
    for (final r in _reports) {
      grouped.putIfAbsent(groupKey(r), () => []).add(r);
    }
    var keys = grouped.keys.toList()..sort();
    if (capToRecent != null && keys.length > capToRecent) {
      keys = keys.sublist(keys.length - capToRecent);
    }
    final points = keys.map((k) => ChartPoint(groupLabel(k), grouped[k]!.fold(0.0, (s, r) => s + r.income), groupColor(k))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnalysisBarChart(points: points),
        const SizedBox(height: AppSizes.md),
        ...keys.reversed.take(8).map((k) {
          final total = grouped[k]!.fold(0.0, (s, r) => s + r.income);
          // Material مباشرة فوق ListTile حتى لا تُخفي خلفية AppCard تأثير الضغط.
          return Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 6, backgroundColor: groupColor(k)),
              title: Text(groupLabel(k), style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
              trailing: Text(_format(total), style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: _identityColor)),
              onTap: tappable
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RevenueDrilldownPage(
                            hotel: widget.hotel,
                            title: groupLabel(k),
                            reports: grouped[k]!,
                            allHotels: _allHotels,
                            color: _identityColor,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildChartWithLegend(List<ChartPoint> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnalysisBarChart(points: points),
        const SizedBox(height: AppSizes.md),
        ...points.map((p) => Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 6, backgroundColor: p.color),
                title: Text(p.label, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                trailing: Text(_format(p.value), style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: _identityColor)),
              ),
            )),
      ],
    );
  }

  Widget _buildExpenseAnalysis(Color color) {
    if (_expenseCategories.isEmpty) {
      return AppCard(
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text("لا توجد مصروفات مسجلة (من المصروفات المعلقة) لهذه الفترة", style: AppTextStyles.caption),
        ),
      );
    }
    final palette = [
      const Color(0xFFE0524A), const Color(0xFF8B5CF6), const Color(0xFF1FA971), const Color(0xFFC7972C),
      const Color(0xFF3B6FE0), const Color(0xFFD9743C), const Color(0xFF14B8A6), const Color(0xFF6366F1),
      const Color(0xFF1E3A5F), const Color(0xFF12B886),
    ];
    final points = _expenseCategories.asMap().entries.map((e) {
      final total = (e.value['total'] as num?)?.toDouble() ?? 0;
      return ChartPoint(e.value['category_name'] as String, total, palette[e.key % palette.length]);
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnalysisBarChart(points: points),
          const SizedBox(height: AppSizes.md),
          ...points.map((p) => Card(
                margin: const EdgeInsets.only(bottom: AppSizes.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: p.color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.category_outlined, color: p.color, size: 18),
                  ),
                  title: Text(p.label, style: AppTextStyles.bodyBold),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_format(p.value), style: AppTextStyles.bodyBold.copyWith(color: p.color)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExpenseCategoryDetailPage(
                          hotel: widget.hotel,
                          hotelIds: _selectedHotelIds.toList(),
                          categoryName: p.label,
                          color: p.color,
                        ),
                      ),
                    );
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    final items = [
      ("متوسط الإيراد اليومي", _format(_avgDailyIncome)),
      ("متوسط الإيراد الشهري", _format(_avgMonthlyIncome)),
      ("متوسط المصروف اليومي", _format(_avgDailyExpense)),
      ("نسبة الربحية", _pct(_profitabilityRatio)),
      ("هامش الربح", _pct(_profitMargin)),
      ("نسبة المصروف إلى الإيراد", _pct(_expenseToIncomeRatio)),
      ("نسبة الرواتب إلى الإيراد", _pct(_salaryToIncomeRatio)),
      ("نسبة الكهرباء إلى الإيراد", _pct(_electricityToIncomeRatio)),
      ("نسبة السيولة", _pct(_liquidityRatio)),
    ];
    return _buildStaticGrid(items.map((i) => _summaryCard(i.$1, i.$2, _identityColor)).toList(), columns: 2);
  }

  Widget _buildSmartInsights(Color color) {
    final insights = [
      ("تحليل المصروفات", Icons.trending_up_outlined),
      ("مقارنة الإيرادات", Icons.compare_arrows_outlined),
      ("تغيّر الأرباح", Icons.insights_outlined),
      ("نسبة الرواتب", Icons.groups_outlined),
      ("مستوى السيولة", Icons.water_drop_outlined),
    ];
    return Column(
      children: insights
          .map((i) => AppCard(
                margin: const EdgeInsets.only(bottom: AppSizes.sm),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(i.$2, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.$1, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                          const SizedBox(height: 2),
                          const Text("سيتم عرض استنتاج تلقائي هنا عند تفعيل التحليل الذكي في مرحلة قادمة", style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  /// شبكة بلا Scrollable/Viewport داخلي (Column من Row) لتفادي مشكلة فقدان
  /// القياسات (child.hasSize) الناتجة عن تداخل GridView مُقلَّص داخل ListView.
  Widget _buildStaticGrid(List<Widget> items, {required int columns, double spacing = 12}) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += columns) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < columns; c++) {
        final idx = i + c;
        if (c > 0) rowChildren.add(SizedBox(width: spacing));
        rowChildren.add(Expanded(child: idx < items.length ? items[idx] : const SizedBox()));
      }
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren)));
      if (i + columns < items.length) rows.add(SizedBox(height: spacing));
    }
    return Column(children: rows);
  }
}
