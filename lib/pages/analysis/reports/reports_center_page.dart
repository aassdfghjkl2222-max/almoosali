import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/financial_report.dart';
import '../../../models/hotel.dart';
import '../../../repositories/financial_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../services/excel_service.dart';
import '../../../services/pdf_service.dart';
import '../../../widgets/common/app_card.dart';
import 'report_details_page.dart';

class _CategoryData {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _CategoryData(this.title, this.icon, this.color, this.count, this.onTap);
}

/// قسم "التقارير" داخل مركز التحليل: تصفّح وبحث وفلترة لكل التقارير المالية
/// عبر جميع الفنادق — شاشة قراءة فقط بالكامل، لا تعديل ولا حذف ولا ترحيل.
class ReportsCenterPage extends StatefulWidget {
  final Hotel hotel;
  final bool initialPendingOnly;
  const ReportsCenterPage({super.key, required this.hotel, this.initialPendingOnly = false});

  @override
  State<ReportsCenterPage> createState() => _ReportsCenterPageState();
}

class _ReportsCenterPageState extends State<ReportsCenterPage> {
  static const _pageSize = 25;
  static const _periods = ["الكل", "يوم", "أسبوع", "نصف شهر", "شهر", "ربع سنة", "نصف سنة", "سنة", "فترة مخصصة"];

  final _repo = FinancialRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Hotel> _allHotels = [];
  Set<int> _selectedHotelIds = {};

  String _selectedPeriod = "الكل";
  DateTimeRange? _customRange;
  bool? _statusFilter; // null=الكل، true=معتمد، false=معلّق
  String? _typeFilter; // null=الكل، 'main'، 'additional'
  String? _employeeFilter;
  List<String> _employeeOptions = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<FinancialReport> _reports = [];

  int _countToday = 0, _countMonth = 0, _countYear = 0, _countPosted = 0, _countPending = 0;

  @override
  void initState() {
    super.initState();
    _selectedHotelIds = widget.hotel.id != null ? {widget.hotel.id!} : {};
    if (widget.initialPendingOnly) _statusFilter = false;
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _allHotels = await HotelRepository().getAllHotels();
    await Future.wait([_refreshCounts(), _resetAndLoad()]);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
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

  DateTimeRange? get _periodRange {
    final now = DateTime.now();
    switch (_selectedPeriod) {
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
      case "فترة مخصصة":
        return _customRange;
      default:
        return null;
    }
  }

  int? get _searchReportId {
    final t = _searchController.text.trim();
    final parsed = int.tryParse(t);
    return parsed;
  }

  String? get _searchText {
    final t = _searchController.text.trim();
    if (t.isEmpty || int.tryParse(t) != null) return null;
    return t;
  }

  Future<void> _refreshCounts() async {
    final hotelIds = _selectedHotelIds.toList();
    final now = DateTime.now();
    final results = await Future.wait([
      _repo.countReportsFiltered(hotelIds: hotelIds, fromDate: DateTime(now.year, now.month, now.day)),
      _repo.countReportsFiltered(hotelIds: hotelIds, fromDate: now.subtract(const Duration(days: 30))),
      _repo.countReportsFiltered(hotelIds: hotelIds, fromDate: now.subtract(const Duration(days: 365))),
      _repo.countReportsFiltered(hotelIds: hotelIds, isPosted: true),
      _repo.countReportsFiltered(hotelIds: hotelIds, isPosted: false),
      _repo.getDistinctReportEmployeeNames(hotelIds: hotelIds),
    ]);
    if (!mounted) return;
    setState(() {
      _countToday = results[0] as int;
      _countMonth = results[1] as int;
      _countYear = results[2] as int;
      _countPosted = results[3] as int;
      _countPending = results[4] as int;
      _employeeOptions = results[5] as List<String>;
      if (_employeeFilter != null && !_employeeOptions.contains(_employeeFilter)) _employeeFilter = null;
    });
  }

  Future<void> _resetAndLoad() async {
    setState(() {
      _isLoading = true;
      _reports = [];
      _hasMore = true;
    });
    await _loadMore(reset: true);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMore && !reset)) return;
    setState(() => _isLoadingMore = true);
    final range = _periodRange;
    final newItems = await _repo.getReportsFiltered(
      hotelIds: _selectedHotelIds.toList(),
      fromDate: range?.start,
      toDate: range?.end,
      isPosted: _statusFilter,
      reportType: _typeFilter,
      employeeName: _employeeFilter,
      reportId: _searchReportId,
      searchText: _searchText,
      limit: _pageSize,
      offset: reset ? 0 : _reports.length,
    );
    if (!mounted) return;
    setState(() {
      if (reset) {
        _reports = newItems;
      } else {
        _reports.addAll(newItems);
      }
      _hasMore = newItems.length == _pageSize;
      _isLoadingMore = false;
    });
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _resetAndLoad();
    });
  }

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  Map<int, String> get _hotelNames => {for (final h in _allHotels) if (h.id != null) h.id!: h.arabicName};

  String get _activeFiltersSummary {
    final parts = <String>[_hotelSummaryLabel];
    if (_selectedPeriod != "الكل") parts.add(_selectedPeriod);
    if (_statusFilter != null) parts.add(_statusFilter! ? "معتمد" : "معلّق");
    if (_typeFilter != null) parts.add(_typeFilter == 'main' ? "رئيسي" : "إضافي");
    if (_employeeFilter != null) parts.add("الموظف: $_employeeFilter");
    return parts.join(" · ");
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
      await Future.wait([_refreshCounts(), _resetAndLoad()]);
    }
  }

  Future<void> _openFilterSheet() async {
    String period = _selectedPeriod;
    DateTimeRange? customRange = _customRange;
    bool? status = _statusFilter;
    String? type = _typeFilter;
    String? employee = _employeeFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("فلاتر التقارير", style: AppTextStyles.title.copyWith(fontSize: 18)),
                    const SizedBox(height: AppSizes.md),
                    Text("الفترة الزمنية", style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                    const SizedBox(height: AppSizes.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _periods.map((p) {
                        final selected = period == p;
                        return ChoiceChip(
                          label: Text(p, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
                          selected: selected,
                          selectedColor: _identityColor,
                          backgroundColor: AppColors.background,
                          onSelected: (_) async {
                            if (p == "فترة مخصصة") {
                              final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: customRange);
                              if (range != null) setSheetState(() { period = p; customRange = range; });
                            } else {
                              setSheetState(() => period = p);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSizes.md),
                    Text("حالة التقرير", style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                    const SizedBox(height: AppSizes.sm),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(label: const Text("الكل", style: TextStyle(fontSize: 12)), selected: status == null, selectedColor: _identityColor, onSelected: (_) => setSheetState(() => status = null)),
                        ChoiceChip(label: Text("معتمد", style: TextStyle(fontSize: 12, color: status == true ? Colors.white : AppColors.textPrimary)), selected: status == true, selectedColor: AppColors.success, onSelected: (_) => setSheetState(() => status = true)),
                        ChoiceChip(label: Text("معلّق", style: TextStyle(fontSize: 12, color: status == false ? Colors.white : AppColors.textPrimary)), selected: status == false, selectedColor: AppColors.warning, onSelected: (_) => setSheetState(() => status = false)),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    Text("نوع التقرير", style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                    const SizedBox(height: AppSizes.sm),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(label: const Text("الكل", style: TextStyle(fontSize: 12)), selected: type == null, selectedColor: _identityColor, onSelected: (_) => setSheetState(() => type = null)),
                        ChoiceChip(label: Text("رئيسي", style: TextStyle(fontSize: 12, color: type == 'main' ? Colors.white : AppColors.textPrimary)), selected: type == 'main', selectedColor: _identityColor, onSelected: (_) => setSheetState(() => type = 'main')),
                        ChoiceChip(label: Text("إضافي", style: TextStyle(fontSize: 12, color: type == 'additional' ? Colors.white : AppColors.textPrimary)), selected: type == 'additional', selectedColor: _identityColor, onSelected: (_) => setSheetState(() => type = 'additional')),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    Text("الموظف", style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                    const SizedBox(height: AppSizes.sm),
                    if (_employeeOptions.isEmpty)
                      const Text(
                        "لا تحتوي التقارير الحالية على بيانات موظف مرتبطة بها بعد.",
                        style: AppTextStyles.caption,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(label: const Text("الكل", style: TextStyle(fontSize: 12)), selected: employee == null, selectedColor: _identityColor, onSelected: (_) => setSheetState(() => employee = null)),
                          ..._employeeOptions.map((e) => ChoiceChip(
                                label: Text(e, style: TextStyle(fontSize: 12, color: employee == e ? Colors.white : AppColors.textPrimary)),
                                selected: employee == e,
                                selectedColor: _identityColor,
                                onSelected: (_) => setSheetState(() => employee = e),
                              )),
                        ],
                      ),
                    const SizedBox(height: AppSizes.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                period = "الكل";
                                customRange = null;
                                status = null;
                                type = null;
                                employee = null;
                              });
                            },
                            child: const Text("إعادة تعيين"),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _identityColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("تطبيق"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    setState(() {
      _selectedPeriod = period;
      _customRange = customRange;
      _statusFilter = status;
      _typeFilter = type;
      _employeeFilter = employee;
    });
    await _resetAndLoad();
  }

  Future<List<FinancialReport>> _fetchAllFilteredForExport() async {
    final range = _periodRange;
    return _repo.getReportsFiltered(
      hotelIds: _selectedHotelIds.toList(),
      fromDate: range?.start,
      toDate: range?.end,
      isPosted: _statusFilter,
      reportType: _typeFilter,
      employeeName: _employeeFilter,
      reportId: _searchReportId,
      searchText: _searchText,
      limit: 5000,
      offset: 0,
    );
  }

  void _openShareSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("مشاركة التقارير", style: AppTextStyles.title.copyWith(fontSize: 17)),
            const SizedBox(height: AppSizes.sm),
            Text(_activeFiltersSummary, style: AppTextStyles.caption, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.md),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.danger),
              title: const Text("مشاركة PDF"),
              onTap: () async {
                Navigator.pop(ctx);
                final reports = await _fetchAllFilteredForExport();
                if (!mounted) return;
                await PdfService.shareReportsListPdf(reports: reports, hotelNames: _hotelNames, filtersSummary: _activeFiltersSummary);
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined, color: Colors.blueGrey),
              title: const Text("طباعة"),
              onTap: () async {
                Navigator.pop(ctx);
                final reports = await _fetchAllFilteredForExport();
                if (!mounted) return;
                await PdfService.printReportsListPdf(reports: reports, hotelNames: _hotelNames, filtersSummary: _activeFiltersSummary);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_view, color: Colors.green),
              title: const Text("تصدير Excel"),
              onTap: () async {
                Navigator.pop(ctx);
                final reports = await _fetchAllFilteredForExport();
                if (!mounted) return;
                await ExcelService.exportReportsList(reports: reports, hotelNames: _hotelNames);
              },
            ),
          ],
        ),
      ),
    );
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
            const Text("التقارير", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 3),
            Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
              child: Text(_hotelSummaryLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _openShareSheet, icon: const Icon(Icons.ios_share, color: Colors.white)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_refreshCounts(), _resetAndLoad()]);
              },
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSizes.md),
                children: [
                  _buildCategoryGrid(color),
                  const SizedBox(height: AppSizes.lg),
                  _buildSearchBar(color),
                  const SizedBox(height: AppSizes.sm),
                  _buildFilterBarButton(color),
                  const SizedBox(height: AppSizes.lg),
                  Text("التقارير (${_reports.length}${_hasMore ? '+' : ''})", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: AppSizes.sm),
                  if (_reports.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text("لا توجد تقارير مطابقة", style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ..._reports.map((r) => _buildReportRow(r, color)),
                  if (_isLoadingMore)
                    const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator())),
                  if (!_hasMore && _reports.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text("لا مزيد من التقارير", style: TextStyle(color: Colors.grey, fontSize: 12))),
                    ),
                ],
              ),
            ),
    );
  }

  /// يعيد ضبط كل الفلاتر الأخرى (باستثناء الفندق المختار) قبل تطبيق بُعد
  /// واحد فقط، حتى يطابق عدد نتائج القائمة دائماً الرقم المعروض على البطاقة.
  void _applyCategoryFilter({String? period, bool? posted}) {
    setState(() {
      _selectedPeriod = period ?? "الكل";
      _customRange = null;
      _statusFilter = posted;
      _typeFilter = null;
      _employeeFilter = null;
      _searchController.clear();
    });
    _resetAndLoad();
  }

  Widget _buildCategoryGrid(Color color) {
    final categories = [
      _CategoryData("التقارير اليومية", Icons.today_outlined, const Color(0xFF3B6FE0), _countToday, () => _applyCategoryFilter(period: "يوم")),
      _CategoryData("التقارير الشهرية", Icons.calendar_month_outlined, const Color(0xFF8B5CF6), _countMonth, () => _applyCategoryFilter(period: "شهر")),
      _CategoryData("التقارير السنوية", Icons.calendar_today_outlined, const Color(0xFF1E3A5F), _countYear, () => _applyCategoryFilter(period: "سنة")),
      _CategoryData("التقارير المعتمدة", Icons.check_circle_outline, AppColors.success, _countPosted, () => _applyCategoryFilter(posted: true)),
      _CategoryData("التقارير غير المعتمدة", Icons.cancel_outlined, AppColors.warning, _countPending, () => _applyCategoryFilter(posted: false)),
      _CategoryData("التقارير المعلّقة", Icons.hourglass_empty_outlined, const Color(0xFFD9743C), _countPending, () => _applyCategoryFilter(posted: false)),
    ];
    return _buildStaticGrid(categories.map((c) => _buildCategoryCard(c)).toList(), columns: 2);
  }

  Widget _buildCategoryCard(_CategoryData c) {
    return AppCard(
      onTap: c.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(c.icon, color: c.color, size: 18),
          ),
          const SizedBox(height: 12),
          Text("${c.count}", style: AppTextStyles.title.copyWith(fontSize: 22, color: c.color)),
          const SizedBox(height: 2),
          Text(c.title, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
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

  Widget _buildSearchBar(Color color) {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: "بحث باسم الفندق أو تاريخ التقرير أو رقمه...",
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

  Widget _buildFilterBarButton(Color color) {
    return InkWell(
      onTap: _openFilterSheet,
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
            Icon(Icons.tune, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_activeFiltersSummary, style: AppTextStyles.bodyBold.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            InkWell(onTap: _openHotelSelector, child: Icon(Icons.apartment, color: color, size: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(FinancialReport r, Color color) {
    final net = r.income - r.expenses;
    final statusColor = r.isPosted ? AppColors.success : AppColors.warning;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          final hotel = _allHotels.firstWhere((h) => h.id == r.hotelId, orElse: () => widget.hotel);
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailsPage(hotel: hotel, report: r)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_hotelNames[r.hotelId] ?? 'فندق #${r.hotelId}', style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(r.isPosted ? "معتمد" : "معلّق", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text("${r.date} · ${(r.employeeName?.isNotEmpty ?? false) ? r.employeeName! : 'غير محدد'}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _rowStat("إيرادات", r.income, const Color(0xFF1FA971))),
                  Expanded(child: _rowStat("مصروفات", r.expenses, const Color(0xFFE0524A))),
                  Expanded(child: _rowStat("الصافي", net, color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 9)),
        Text(_format(value), style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
