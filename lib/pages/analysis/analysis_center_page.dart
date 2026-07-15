import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_theme.dart';
import '../../core/document_status.dart';
import '../../core/hotel_identity.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/financial_report.dart';
import '../../models/hotel.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/financial_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../services/financial_engine.dart';
import '../../widgets/common/app_card.dart';
import '../alerts/alerts_page.dart';
import 'cash_movements_list_page.dart';
import 'documents/documents_analysis_page.dart';
import 'employees/employees_analysis_page.dart';
import 'financial_analysis/financial_analysis_page.dart';
import 'financial_analysis/revenue_drilldown_page.dart';
import 'relationships/relationships_center_page.dart';
import 'reports/reports_center_page.dart';
import 'vault/financial_center_analysis_page.dart';

/// مركز التحليل: غرفة القيادة الرئيسية — كل الأرقام هنا مقروءة من بيانات
/// التطبيق الفعلية (مرحلة ٦)، ولا يوجد أي رقم ثابت أو تجريبي باستثناء
/// "مؤشر صحة الفندق" و"التحليل الذكي" اللذين طُلب صراحة إبقاؤهما واجهة فقط
/// (لا توجد خوارزمية حساب مطلوبة أو موصوفة لهما في أي مهمة سابقة).
class AnalysisCenterPage extends StatefulWidget {
  final Hotel hotel;
  const AnalysisCenterPage({super.key, required this.hotel});

  @override
  State<AnalysisCenterPage> createState() => _AnalysisCenterPageState();
}

/// بيانات بطاقة مؤشر — بنية ثابتة تسهّل إضافة مؤشرات جديدة مستقبلاً
/// بمجرد إضافة عنصر جديد لقائمة `_kpiCards`، دون تعديل البطاقة نفسها.
class _KpiCardData {
  final String title;
  final IconData icon;
  final Color color;
  const _KpiCardData(this.title, this.icon, this.color);
}

/// بطاقة مؤشر مستقلة (StatelessWidget) حتى لا يُعاد بناء بقية البطاقات
/// عند تحديث قيمة بطاقة واحدة مستقبلاً (عبر تغليفها بـ ValueListenableBuilder لاحقاً).
class _KpiCard extends StatelessWidget {
  final _KpiCardData data;
  final String value;
  final VoidCallback? onTap;

  const _KpiCard({required this.data, this.value = "—", this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap ?? () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: data.color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(data.icon, color: data.color, size: 18),
              ),
              // مكان جاهز لسهم الاتجاه (ارتفاع/انخفاض) عند تفعيل الحسابات الفعلية.
              const Icon(Icons.trending_flat, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: AppTextStyles.title.copyWith(fontSize: 20, color: data.color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(data.title, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          // مساحة محجوزة لعرض نسبة التغيّر مستقبلاً دون إعادة تصميم البطاقة.
          Text("—٪ عن الفترة السابقة", style: AppTextStyles.caption.copyWith(fontSize: 9, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TodayStat {
  final String title;
  final IconData icon;
  final Color color;
  const _TodayStat(this.title, this.icon, this.color);
}

class _AnalysisSection {
  final String title;
  final IconData icon;
  final String description;
  const _AnalysisSection(this.title, this.icon, this.description);
}

class _AnalysisCenterPageState extends State<AnalysisCenterPage> {
  static const _periods = ["يوم", "أسبوع", "نصف شهر", "شهر", "ربع سنة", "نصف سنة", "سنة", "فترة مخصصة"];

  final _searchController = TextEditingController();
  DateTime _lastUpdated = DateTime.now();

  final _financialRepo = FinancialRepository();
  final _engine = FinancialEngine();
  final _documentRepo = DocumentRepository();

  List<Hotel> _allHotels = [];
  Set<int> _selectedHotelIds = {};
  String _selectedPeriod = "شهر";
  DateTimeRange? _customRange;
  bool _isLoading = true;
  bool _isLoadingKpis = true;

  List<FinancialReport> _periodReports = [];
  double _income = 0, _expenses = 0, _shortageTotal = 0, _networkTotal = 0, _transferTotal = 0;
  double _cashBalance = 0, _bankBalance = 0, _totalReceivable = 0, _totalLiability = 0;
  int _pendingReportsCount = 0;
  int _criticalAlertsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHotels() async {
    final hotels = await HotelRepository().getAllHotels();
    if (!mounted) return;
    setState(() {
      _allHotels = hotels;
      _selectedHotelIds = widget.hotel.id != null ? {widget.hotel.id!} : {};
      _isLoading = false;
    });
    await _loadKpis();
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

  List<FinancialReport> get _todayReports {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _periodReports.where((r) => r.date == todayStr).toList();
  }

  /// يقرأ كل المؤشرات الرئيسية من البيانات الفعلية: الإيرادات/المصروفات من
  /// financial_reports (نفس مصدر قسم "التقارير")، النقد/البنك/صافي المركز
  /// المالي من FinancialEngine (نفس مصدر المركز المالي)، والتنبيهات الحرجة
  /// من تواريخ انتهاء المستندات الفعلية (نفس منطق شاشة "التنبيهات" الموجودة).
  Future<void> _loadKpis() async {
    if (_selectedHotelIds.isEmpty) {
      setState(() => _isLoadingKpis = false);
      return;
    }
    setState(() => _isLoadingKpis = true);
    final hotelIds = _selectedHotelIds.toList();
    final range = _range;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      _financialRepo.getTotals(hotelIds: hotelIds, fromDate: range.start, toDate: range.end),
      _financialRepo.getReportsInRangeMultiHotel(hotelIds: hotelIds, fromDate: range.start.isBefore(today) ? range.start : today, toDate: now),
      _financialRepo.countReportsFiltered(hotelIds: hotelIds, isPosted: false),
      _loadBalances(hotelIds),
      _loadCriticalAlerts(hotelIds),
    ]);

    if (!mounted) return;
    final totals = results[0] as Map<String, double>;
    final reports = results[1] as List<FinancialReport>;
    final balances = results[3] as Map<String, double>;

    double network = 0, transfer = 0, shortage = 0;
    for (final r in reports) {
      if (r.detailsJson == null || r.detailsJson!.isEmpty) continue;
      try {
        final d = jsonDecode(r.detailsJson!) as Map<String, dynamic>;
        final income = (d['income_details'] as Map<String, dynamic>?) ?? {};
        network += double.tryParse(income['pos']?.toString() ?? '0') ?? 0;
        network += double.tryParse(income['parking_pos']?.toString() ?? '0') ?? 0;
        transfer += double.tryParse(income['transfer']?.toString() ?? '0') ?? 0;
        final adj = (d['adjustments'] as Map<String, dynamic>?) ?? {};
        shortage += double.tryParse(adj['shortage']?.toString() ?? '0') ?? 0;
      } catch (_) {}
    }

    setState(() {
      _income = totals['income'] ?? 0;
      _expenses = totals['expenses'] ?? 0;
      _periodReports = reports;
      _networkTotal = network;
      _transferTotal = transfer;
      _shortageTotal = shortage;
      _cashBalance = balances['cash'] ?? 0;
      _bankBalance = balances['bank'] ?? 0;
      _totalReceivable = balances['receivable'] ?? 0;
      _totalLiability = balances['liability'] ?? 0;
      _pendingReportsCount = results[2] as int;
      _criticalAlertsCount = results[4] as int;
      _lastUpdated = DateTime.now();
      _isLoadingKpis = false;
    });
  }

  Future<Map<String, double>> _loadBalances(List<int> hotelIds) async {
    double cash = 0, bank = 0, receivable = 0, liability = 0;
    for (final id in hotelIds) {
      cash += await _engine.getBalance(id, 'cash');
      bank += await _engine.getBalance(id, 'bank');
      receivable += await _engine.getTotalReceivable(id);
      liability += await _engine.getTotalLiability(id);
    }
    return {'cash': cash, 'bank': bank, 'receivable': receivable, 'liability': liability};
  }

  /// "حرجة" الآن تعني منتهية أو خلال 7 أيام أو أقل (وليس المنتهية فقط كما
  /// كان سابقاً) — بنفس عتبة DocumentStatus الموحّدة المعتمدة في كل مكان آخر
  /// يعرض حالة المستندات، بدل تعريف منفصل كان يتجاهل التنبيه العاجل.
  Future<int> _loadCriticalAlerts(List<int> hotelIds) async {
    int count = 0;
    for (final id in hotelIds) {
      final docs = await _documentRepo.getDocumentsForHotel(id);
      count += docs.where((d) {
        final level = DocumentStatus.fromExpiryDate(d.expiryDate).level;
        return level == DocumentStatusLevel.expired || level == DocumentStatusLevel.urgent;
      }).length;
    }
    return count;
  }

  Hotel? get _singleSelectedHotel {
    if (_selectedHotelIds.length != 1) return null;
    for (final h in _allHotels) {
      if (h.id == _selectedHotelIds.first) return h;
    }
    return widget.hotel;
  }

  HotelIdentity get _identity {
    final single = _singleSelectedHotel;
    return single != null ? HotelVisualIdentity.identityForHotel(single) : HotelIdentity.defaultIdentity();
  }

  String get _hotelSummaryLabel {
    if (_allHotels.isEmpty || _selectedHotelIds.isEmpty) return "لا يوجد فندق محدد";
    if (_selectedHotelIds.length == _allHotels.length) return "جميع الفنادق (${_allHotels.length})";
    if (_selectedHotelIds.length == 1) return _singleSelectedHotel?.arabicName ?? "فندق واحد";
    return "${_selectedHotelIds.length} فنادق مختارة";
  }

  String get _periodLabel {
    if (_selectedPeriod == "فترة مخصصة" && _customRange != null) {
      return "${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}";
    }
    return _selectedPeriod;
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
                        backgroundColor: _identity.primary,
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
      await _loadKpis();
    }
  }

  Future<void> _onPeriodSelected(String period) async {
    if (period == "فترة مخصصة") {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _customRange,
      );
      if (range != null && mounted) {
        setState(() {
          _selectedPeriod = period;
          _customRange = range;
        });
        await _loadKpis();
      }
      return;
    }
    setState(() => _selectedPeriod = period);
    await _loadKpis();
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("سيتم تفعيل هذا القسم في مرحلة قادمة"), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;

    return Theme(
      data: AppTheme.createTheme(identity),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: identity.primary,
          elevation: 0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("مركز التحليل", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 3),
              Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _hotelSummaryLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSizes.md),
                children: [
                  _buildWelcomeCard(identity.primary),
                  const SizedBox(height: AppSizes.lg),
                  _buildFilterBar(identity.primary),
                  const SizedBox(height: AppSizes.md),
                  _buildSearchBar(identity.primary),
                  const SizedBox(height: AppSizes.lg),
                  _buildSectionHeader("المؤشرات الرئيسية"),
                  const SizedBox(height: AppSizes.sm),
                  _isLoadingKpis
                      ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                      : _buildKpiGrid(identity.primary),
                  const SizedBox(height: AppSizes.lg),
                  if (!_isLoadingKpis) _buildTodaySummaryCard(identity.primary),
                  const SizedBox(height: AppSizes.lg),
                  _buildHealthScoreCard(identity.primary),
                  const SizedBox(height: AppSizes.lg),
                  _buildSectionHeader("الأقسام"),
                  const SizedBox(height: AppSizes.sm),
                  _buildSectionsGrid(identity.primary),
                  const SizedBox(height: AppSizes.xl),
                ],
              ),
      ),
    );
  }

  /// شبكة بلا Scrollable/Viewport داخلي إطلاقاً (Column من Row)، بدل GridView
  /// مُقلَّص (shrinkWrap) متداخل داخل ListView الخارجية — وهو النمط الذي كان
  /// يسبب فقدان قياسات العناصر (child.hasSize) عند عكس اتجاه التمرير.
  /// كل عنصر يُغلَّف بـ IntrinsicHeight+stretch ليتساوى ارتفاع بطاقات نفس الصف.
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

  Widget _buildSectionHeader(String title) {
    return Text(title, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _buildWelcomeCard(Color color) {
    return AppCard(
      identityAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.dashboard_customize_outlined, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_hotelSummaryLabel, style: AppTextStyles.title.copyWith(fontSize: 17, color: color)),
                    const SizedBox(height: 2),
                    const Text("مركز القيادة التنفيذي", style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSizes.lg),
          Row(
            children: [
              Expanded(child: _welcomeStat(Icons.date_range_outlined, "الفترة", _periodLabel, color)),
              Expanded(child: _welcomeStat(Icons.apartment_outlined, "عدد الفنادق", "${_selectedHotelIds.length}", color)),
              Expanded(child: _welcomeStat(Icons.update_outlined, "آخر تحديث", DateFormat('HH:mm').format(_lastUpdated), color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _welcomeStat(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
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
                label: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface)),
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

  Widget _buildSearchBar(Color color) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: "بحث عام...",
        hintStyle: AppTextStyles.caption,
        prefixIcon: Icon(Icons.search, color: color),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color)),
      ),
    );
  }

  String _fmtAmount(double v) => NumberFormat("#,##0.##").format(v);

  void _openReportsDrilldown(String title, Color color, {List<FinancialReport>? reports, ReportAmountSelector? amountSelector}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevenueDrilldownPage(
          hotel: widget.hotel,
          title: title,
          reports: reports ?? _periodReports,
          allHotels: _allHotels,
          color: color,
          totalLabel: title,
          amountSelector: amountSelector,
        ),
      ),
    ).then((_) => _loadKpis());
  }

  void _openCashMovements(String title, String category, Color color, {bool boundToPeriod = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CashMovementsListPage(
          hotel: widget.hotel,
          title: title,
          category: category,
          hotelIds: _selectedHotelIds.toList(),
          hotelNames: _hotelNames,
          color: color,
          fromDate: boundToPeriod ? _range.start : null,
          toDate: boundToPeriod ? _range.end : null,
        ),
      ),
    ).then((_) => _loadKpis());
  }

  /// المؤشرات الرئيسية — كل قيمة مقروءة فعلياً من نفس مصادر بيانات قسمي
  /// "التقارير" و"المركز المالي" (financial_reports وFinancialEngine)، وكل
  /// بطاقة قابلة للضغط لعرض العمليات التي كوّنت رقمها (البند ٢+٣). "النقد"
  /// و"الخزنة" يعرضان نفس رصيد الخزنة الفعلي (لا يوجد حساب منفصل لهما في
  /// النظام)، و"الشبكة"/"التحويلات" مجموع فعلي من تفاصيل التقارير لأنه لا
  /// يوجد لهما حساب رصيد مستقل (يُودَعان ضمن حساب البنك مباشرة).
  Widget _buildKpiGrid(Color identityColor) {
    final net = _income - _expenses;
    final netPosition = _cashBalance + _bankBalance + _totalReceivable - _totalLiability;
    final cards = <(_KpiCardData, double, VoidCallback)>[
      (const _KpiCardData("الإيرادات", Icons.trending_up_outlined, Color(0xFF1FA971)), _income, () => _openReportsDrilldown("الإيرادات", const Color(0xFF1FA971))),
      (const _KpiCardData("المصروفات", Icons.trending_down_outlined, Color(0xFFE0524A)), _expenses, () => _openReportsDrilldown("المصروفات", const Color(0xFFE0524A), amountSelector: (r) => r.expenses)),
      (const _KpiCardData("الأرباح", Icons.savings_outlined, Color(0xFF3B6FE0)), net, () => _openReportsDrilldown("الأرباح", const Color(0xFF3B6FE0), amountSelector: (r) => r.income - r.expenses)),
      (
        const _KpiCardData("الخسائر", Icons.warning_amber_outlined, Color(0xFFD9743C)),
        _shortageTotal,
        () => _openReportsDrilldown(
              "الخسائر (عجز العهدة)",
              const Color(0xFFD9743C),
              reports: _periodReports.where((r) {
                if (r.detailsJson == null) return false;
                try {
                  final adj = (jsonDecode(r.detailsJson!)['adjustments'] as Map<String, dynamic>?) ?? {};
                  return (double.tryParse(adj['shortage']?.toString() ?? '0') ?? 0) > 0;
                } catch (_) {
                  return false;
                }
              }).toList(),
              amountSelector: (r) {
                try {
                  final adj = (jsonDecode(r.detailsJson!)['adjustments'] as Map<String, dynamic>?) ?? {};
                  return double.tryParse(adj['shortage']?.toString() ?? '0') ?? 0;
                } catch (_) {
                  return 0;
                }
              },
            )
      ),
      (const _KpiCardData("النقد", Icons.payments_outlined, Color(0xFF12B886)), _cashBalance, () => _openCashMovements("حركات النقد (الخزنة)", 'cash', const Color(0xFF12B886))),
      (const _KpiCardData("الشبكة", Icons.credit_card_outlined, Color(0xFF8B5CF6)), _networkTotal, () => _openReportsDrilldown("إيرادات الشبكة", const Color(0xFF8B5CF6), amountSelector: _networkAmount)),
      (const _KpiCardData("البنك", Icons.account_balance_outlined, Color(0xFF1E3A5F)), _bankBalance, () => _openCashMovements("حركات البنك", 'bank', const Color(0xFF1E3A5F))),
      (const _KpiCardData("التحويلات", Icons.swap_horiz_outlined, Color(0xFF6366F1)), _transferTotal, () => _openReportsDrilldown("إيرادات التحويل البنكي", const Color(0xFF6366F1), amountSelector: _transferAmount)),
      (const _KpiCardData("الخزنة", Icons.lock_outline, Color(0xFFC7972C)), _cashBalance, () => _openCashMovements("حركات النقد (الخزنة)", 'cash', const Color(0xFFC7972C))),
      (const _KpiCardData("صافي المركز المالي", Icons.account_balance_wallet_outlined, Color(0xFF14B8A6)), netPosition, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinancialAnalysisPage(hotel: widget.hotel))).then((_) => _loadKpis())),
    ];
    return _buildStaticGrid(
      cards.map((c) => _KpiCard(data: c.$1, value: _fmtAmount(c.$2), onTap: c.$3)).toList(),
      columns: 2,
    );
  }

  double _networkAmount(FinancialReport r) {
    if (r.detailsJson == null) return 0;
    try {
      final d = (jsonDecode(r.detailsJson!)['income_details'] as Map<String, dynamic>?) ?? {};
      return (double.tryParse(d['pos']?.toString() ?? '0') ?? 0) + (double.tryParse(d['parking_pos']?.toString() ?? '0') ?? 0);
    } catch (_) {
      return 0;
    }
  }

  double _transferAmount(FinancialReport r) {
    if (r.detailsJson == null) return 0;
    try {
      final d = (jsonDecode(r.detailsJson!)['income_details'] as Map<String, dynamic>?) ?? {};
      return double.tryParse(d['transfer']?.toString() ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildTodaySummaryCard(Color color) {
    final todayReports = _todayReports;
    final todayIncome = todayReports.fold(0.0, (s, r) => s + r.income);
    final todayExpenses = todayReports.fold(0.0, (s, r) => s + r.expenses);
    final items = <(_TodayStat, String, VoidCallback?)>[
      (const _TodayStat("إيرادات اليوم", Icons.arrow_downward_outlined, Color(0xFF1FA971)), _fmtAmount(todayIncome), () => _openReportsDrilldown("إيرادات اليوم", const Color(0xFF1FA971), reports: todayReports)),
      (const _TodayStat("مصروفات اليوم", Icons.arrow_upward_outlined, Color(0xFFE0524A)), _fmtAmount(todayExpenses), () => _openReportsDrilldown("مصروفات اليوم", const Color(0xFFE0524A), reports: todayReports, amountSelector: (r) => r.expenses)),
      (_TodayStat("صافي اليوم", Icons.equalizer_outlined, color), _fmtAmount(todayIncome - todayExpenses), () => _openReportsDrilldown("صافي اليوم", color, reports: todayReports, amountSelector: (r) => r.income - r.expenses)),
      (const _TodayStat("تقارير غير معتمدة", Icons.pending_actions_outlined, AppColors.warning), "$_pendingReportsCount", () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsCenterPage(hotel: widget.hotel, initialPendingOnly: true))).then((_) => _loadKpis())),
      (const _TodayStat("تنبيهات حرجة", Icons.notifications_active_outlined, AppColors.danger), "$_criticalAlertsCount", () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlertsPage(hotel: _singleSelectedHotel ?? widget.hotel))).then((_) => _loadKpis())),
    ];
    return AppCard(
      identityAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ملخص اليوم", style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
              Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: AppTextStyles.caption),
            ],
          ),
          const Divider(height: AppSizes.lg),
          _buildStaticGrid(
            items.map((s) => _todayStatItem(s.$1, s.$2, s.$3)).toList(),
            columns: 3,
            spacing: 4,
          ),
        ],
      ),
    );
  }

  Widget _todayStatItem(_TodayStat s, String value, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(s.icon, color: s.color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 14, color: s.color), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(s.title, style: AppTextStyles.caption.copyWith(fontSize: 9), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // الحالة الافتراضية الحالية بانتظار اكتمال بقية الأنظمة. الدالة أدناه جاهزة
  // لاستقبال إحدى الحالات الأربع الفعلية (ممتاز/جيد/يحتاج متابعة/خطر) مستقبلاً.
  String get _healthStatus => "بانتظار الاحتساب";

  Color _healthStatusColor(String status) {
    switch (status) {
      case 'ممتاز': return AppColors.success;
      case 'جيد': return AppColors.info;
      case 'يحتاج متابعة': return AppColors.warning;
      case 'خطر': return AppColors.danger;
      default: return Colors.grey;
    }
  }

  Widget _buildHealthScoreCard(Color color) {
    final statusColor = _healthStatusColor(_healthStatus);
    return AppCard(
      identityAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("مؤشر صحة الفندق", style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
          const SizedBox(height: AppSizes.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 0,
                      strokeWidth: 9,
                      backgroundColor: statusColor.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("—", style: AppTextStyles.title.copyWith(fontSize: 26, color: statusColor)),
                        Text("من 100", style: AppTextStyles.caption.copyWith(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        _healthStatus,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "سيتم احتساب المؤشر بعد اكتمال بقية الأنظمة.",
                      style: AppTextStyles.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsGrid(Color color) {
    final sections = [
      _AnalysisSection("التحليل المالي", Icons.query_stats_outlined, "أداء الإيرادات والمصروفات"),
      _AnalysisSection("التقارير", Icons.summarize_outlined, "التقارير اليومية والشهرية"),
      _AnalysisSection("الموظفون", Icons.badge_outlined, "الرواتب والحضور والسلف"),
      _AnalysisSection("الموردون", Icons.local_shipping_outlined, "المستحقات والمشتريات الآجلة"),
      _AnalysisSection("المستندات", Icons.folder_copy_outlined, "العقود والفواتير والأرشيف"),
      _AnalysisSection("المركز المالي", Icons.account_balance_wallet_outlined, "الخزنة والبنك والحسابات"),
      _AnalysisSection("العلاقات المالية", Icons.apartment_outlined, "الديون والمستحقات بين المنشآت"),
      _AnalysisSection("التحليل الذكي", Icons.psychology_outlined, "استنتاجات وتوصيات تلقائية"),
      _AnalysisSection("الرسوم البيانية", Icons.bar_chart_outlined, "مقارنات ومؤشرات بصرية"),
      _AnalysisSection("التنبيهات", Icons.notifications_active_outlined, "تنبيهات إدارية هامة"),
    ];
    return _buildStaticGrid(
      sections.map((s) => _buildSectionCard(s, color)).toList(),
      columns: 2,
    );
  }

  void _openSection(_AnalysisSection s) {
    if (s.title == "التقارير") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsCenterPage(hotel: widget.hotel))).then((_) => _loadKpis());
      return;
    }
    if (s.title == "التحليل المالي") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => FinancialAnalysisPage(hotel: widget.hotel))).then((_) => _loadKpis());
      return;
    }
    if (s.title == "العلاقات المالية") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RelationshipsCenterPage(hotel: widget.hotel))).then((_) => _loadKpis());
      return;
    }
    if (s.title == "الموظفون") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeesAnalysisPage(hotel: widget.hotel))).then((_) => _loadKpis());
      return;
    }
    if (s.title == "المستندات") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsAnalysisPage(hotel: widget.hotel))).then((_) => _loadKpis());
      return;
    }
    if (s.title == "المركز المالي") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => FinancialCenterAnalysisPage(hotel: widget.hotel))).then((_) => _loadKpis());
      return;
    }
    if (s.title == "الموردون") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RelationshipsCenterPage(hotel: widget.hotel, initialRelationTypeFilter: 'supplier'))).then((_) => _loadKpis());
      return;
    }
    _showComingSoon();
  }

  Widget _buildSectionCard(_AnalysisSection s, Color color) {
    return AppCard(
      onTap: () => _openSection(s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(s.icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(s.title, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(s.description, style: AppTextStyles.caption.copyWith(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
