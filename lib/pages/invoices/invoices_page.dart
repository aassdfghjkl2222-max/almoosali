import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../models/invoice.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/invoice_repository.dart';
import '../../services/zatca_qr_parser.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../expenses/manage_categories_page.dart';
import 'add_invoice_page.dart';
import 'invoice_details_page.dart';
import 'invoice_reports_page.dart';
import 'scan_invoice_qr_page.dart';
import 'supplier_report_page.dart';
import 'supplier_statement_page.dart';

enum _HotelScope { current, all, custom }

enum _PeriodPreset { today, thisWeek, lastWeek, thisMonth, lastMonth, custom }

/// مركز "الفواتير الضريبية" لكل فندق — الهيكل العام فقط في هذه المرحلة:
/// بطاقات ملخص، اختيار فندق واحد/الكل/عدة، فترات جاهزة وفترة مخصصة، بحث
/// فوري، فلاتر (مورد/تصنيف/مصدر تمويل)، قائمة مُحمَّلة تدريجياً. يُعاد
/// استخدام AddInvoicePage/InvoiceDetailsPage الموجودتين فعلياً بلا أي
/// تعديل — لا منطق مالي جديد ولا شاشات موردين/تقارير أُنشئت هنا.
class InvoicesPage extends StatefulWidget {
  final Hotel hotel;
  const InvoicesPage({super.key, required this.hotel});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  static const _pageSize = 20;

  final _invoiceRepo = InvoiceRepository();
  final _hotelRepo = HotelRepository();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  List<Hotel> _hotels = [];
  _HotelScope _hotelScope = _HotelScope.current;
  late Set<int> _customHotelIds;

  _PeriodPreset? _periodPreset;
  DateTime? _customStart;
  DateTime? _customEnd;

  String _searchQuery = '';
  String? _supplierFilter;
  String? _categoryFilter;
  String? _amountSourceFilter;

  List<String> _availableSuppliers = [];
  List<String> _availableCategories = [];
  List<String> _availableAmountSources = [];

  String _sortKey = 'date_desc';

  InvoicesSummary? _summary;
  final List<Invoice> _invoices = [];
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _customHotelIds = {widget.hotel.id!};
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  List<int>? get _effectiveHotelIds {
    switch (_hotelScope) {
      case _HotelScope.current:
        return [widget.hotel.id!];
      case _HotelScope.all:
        return null;
      case _HotelScope.custom:
        return _customHotelIds.toList();
    }
  }

  (String?, String?) get _effectiveDateRange {
    final now = DateTime.now();
    String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    switch (_periodPreset) {
      case null:
        return (null, null);
      case _PeriodPreset.today:
        return (fmt(now), fmt(now));
      case _PeriodPreset.thisWeek:
        return (fmt(now.subtract(Duration(days: now.weekday - 1))), fmt(now));
      case _PeriodPreset.lastWeek:
        final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
        final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
        final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));
        return (fmt(lastWeekStart), fmt(lastWeekEnd));
      case _PeriodPreset.thisMonth:
        return (fmt(DateTime(now.year, now.month, 1)), fmt(now));
      case _PeriodPreset.lastMonth:
        final lastMonthEnd = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
        return (fmt(DateTime(lastMonthEnd.year, lastMonthEnd.month, 1)), fmt(lastMonthEnd));
      case _PeriodPreset.custom:
        return (_customStart != null ? fmt(_customStart!) : null, _customEnd != null ? fmt(_customEnd!) : null);
    }
  }

  Future<void> _bootstrap() async {
    final hotels = await _hotelRepo.getAllHotels();
    if (!mounted) return;
    setState(() => _hotels = hotels);
    await _reloadFilterOptions();
    await _reload();
  }

  Future<void> _reloadFilterOptions() async {
    final hotelIds = _effectiveHotelIds;
    final suppliers = await _invoiceRepo.getDistinctSuppliers(hotelIds);
    final categories = await _invoiceRepo.getDistinctCategories(hotelIds);
    final amountSources = await _invoiceRepo.getDistinctAmountSources(hotelIds);
    if (!mounted) return;
    setState(() {
      _availableSuppliers = suppliers;
      _availableCategories = categories;
      _availableAmountSources = amountSources;
      if (_supplierFilter != null && !_availableSuppliers.contains(_supplierFilter)) _supplierFilter = null;
      if (_categoryFilter != null && _categoryFilter != kUnclassifiedInvoiceCategory && !_availableCategories.contains(_categoryFilter)) _categoryFilter = null;
      if (_amountSourceFilter != null && !_availableAmountSources.contains(_amountSourceFilter)) _amountSourceFilter = null;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _isLoadingFirstPage = true;
      _invoices.clear();
      _hasMore = true;
    });
    final hotelIds = _effectiveHotelIds;
    final (start, end) = _effectiveDateRange;

    final summary = await _invoiceRepo.getInvoicesSummary(
      hotelIds: hotelIds,
      startDate: start,
      endDate: end,
      supplierName: _supplierFilter,
      category: _categoryFilter,
      amountSource: _amountSourceFilter,
      searchQuery: _searchQuery,
    );
    final firstPage = await _invoiceRepo.getInvoicesPagedFiltered(
      hotelIds: hotelIds,
      startDate: start,
      endDate: end,
      supplierName: _supplierFilter,
      category: _categoryFilter,
      amountSource: _amountSourceFilter,
      searchQuery: _searchQuery,
      sortKey: _sortKey,
      limit: _pageSize,
      offset: 0,
    );

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _invoices.addAll(firstPage);
      _hasMore = firstPage.length >= _pageSize;
      _isLoadingFirstPage = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final hotelIds = _effectiveHotelIds;
    final (start, end) = _effectiveDateRange;
    final next = await _invoiceRepo.getInvoicesPagedFiltered(
      hotelIds: hotelIds,
      startDate: start,
      endDate: end,
      supplierName: _supplierFilter,
      category: _categoryFilter,
      amountSource: _amountSourceFilter,
      searchQuery: _searchQuery,
      sortKey: _sortKey,
      limit: _pageSize,
      offset: _invoices.length,
    );
    if (!mounted) return;
    setState(() {
      _invoices.addAll(next);
      _hasMore = next.length >= _pageSize;
      _isLoadingMore = false;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchQuery = value.trim();
      _reload();
    });
  }

  Future<void> _openHotelScopeSheet() async {
    var scope = _hotelScope;
    var custom = {..._customHotelIds};
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSizes.md,
                right: AppSizes.md,
                top: AppSizes.md,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSizes.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("اختيار الفندق", style: AppTextStyles.title.copyWith(fontSize: 18)),
                  const SizedBox(height: AppSizes.sm),
                  RadioListTile<_HotelScope>(
                    contentPadding: EdgeInsets.zero,
                    title: Text("هذا الفندق فقط (${widget.hotel.arabicName})"),
                    value: _HotelScope.current,
                    groupValue: scope,
                    onChanged: (v) => setSheetState(() => scope = v!),
                  ),
                  RadioListTile<_HotelScope>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("جميع الفنادق"),
                    value: _HotelScope.all,
                    groupValue: scope,
                    onChanged: (v) => setSheetState(() => scope = v!),
                  ),
                  RadioListTile<_HotelScope>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("تحديد عدة فنادق"),
                    value: _HotelScope.custom,
                    groupValue: scope,
                    onChanged: (v) => setSheetState(() => scope = v!),
                  ),
                  if (scope == _HotelScope.custom)
                    ..._hotels.map((h) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(h.arabicName),
                          value: custom.contains(h.id),
                          onChanged: (checked) => setSheetState(() {
                            if (checked == true) {
                              custom.add(h.id!);
                            } else {
                              custom.remove(h.id!);
                            }
                          }),
                        )),
                  const SizedBox(height: AppSizes.md),
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.buttonHeight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text("تطبيق"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != true) return;
    setState(() {
      _hotelScope = scope;
      _customHotelIds = custom.isEmpty ? {widget.hotel.id!} : custom;
    });
    await _reloadFilterOptions();
    await _reload();
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customStart != null && _customEnd != null ? DateTimeRange(start: _customStart!, end: _customEnd!) : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _identityColor)),
          child: child!,
        );
      },
    );
    if (range == null) return;
    setState(() {
      _periodPreset = _PeriodPreset.custom;
      _customStart = range.start;
      _customEnd = range.end;
    });
    _reload();
  }

  void _selectPeriod(_PeriodPreset preset) {
    setState(() {
      if (_periodPreset == preset) {
        _periodPreset = null;
      } else {
        _periodPreset = preset;
      }
    });
    _reload();
  }

  String get _hotelScopeLabel {
    switch (_hotelScope) {
      case _HotelScope.current:
        return widget.hotel.arabicName;
      case _HotelScope.all:
        return "جميع الفنادق";
      case _HotelScope.custom:
        return "${_customHotelIds.length} فنادق مختارة";
    }
  }

  void _openReportsPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceReportsPage(hotel: widget.hotel)));
  }

  /// يفتح شاشة مسح رمز QR. عند نجاح القراءة تُرجِع [ZatcaInvoiceData] فنفتح
  /// "إضافة فاتورة" معبَّأة تلقائياً. عند اختيار "إدخال يدوي" داخل شاشة
  /// المسح (بعد فشل قراءة) تستبدل تلك الشاشة نفسها بـAddInvoicePage فارغة
  /// مباشرة، فتُرجِع القيمة `true` مباشرة إلى هنا عند نجاح الحفظ هناك. أما
  /// الإلغاء ببساطة (زر الرجوع) فيُرجِع null ولا يفتح أي شاشة إضافية.
  Future<void> _openQrScan() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ScanInvoiceQrPage(hotel: widget.hotel)));
    if (!mounted || result == null) return;

    if (result is ZatcaInvoiceData) {
      final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddInvoicePage(hotel: widget.hotel, qrPrefill: result)));
      if (saved != true) return;
    } else if (result != true) {
      return;
    }

    await _reloadFilterOptions();
    await _reload();
  }

  PopupMenuItem<String> _sortMenuItem(String key, String label) {
    final isSelected = _sortKey == key;
    return PopupMenuItem(
      value: key,
      child: Row(
        children: [
          if (isSelected) Icon(Icons.check, size: 16, color: _identityColor) else const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
        ],
      ),
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("إعدادات الفواتير الضريبية", style: AppTextStyles.title.copyWith(fontSize: 18)),
              const SizedBox(height: AppSizes.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.category_outlined, color: _identityColor),
                title: const Text("إدارة تصنيفات المصروفات"),
                subtitle: const Text("قاعدة تصنيفات موحدة تُستخدم في كل الفنادق"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ManageCategoriesPage(hotel: widget.hotel)));
                },
              ),
              const SizedBox(height: AppSizes.sm),
              const Text(
                "بقية إعدادات هذا القسم (ترقيم الفواتير، ربط الموردين) ستتوفر في مرحلة قادمة.",
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "الفواتير الضريبية", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: "الفرز والترتيب",
            onSelected: (key) {
              setState(() => _sortKey = key);
              _reload();
            },
            itemBuilder: (context) => [
              _sortMenuItem('date_desc', "التاريخ (الأحدث أولاً)"),
              _sortMenuItem('date_asc', "التاريخ (الأقدم أولاً)"),
              _sortMenuItem('amount_desc', "المبلغ (الأعلى أولاً)"),
              _sortMenuItem('amount_asc', "المبلغ (الأقل أولاً)"),
              _sortMenuItem('invoice_number_desc', "رقم الفاتورة (تنازلي)"),
              _sortMenuItem('invoice_number_asc', "رقم الفاتورة (تصاعدي)"),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: "التقارير",
            onPressed: _openReportsPage,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: "الإعدادات",
            onPressed: _openSettingsSheet,
          ),
        ],
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      // زر "مسح الباركود" بجانب زر "إضافة فاتورة" مباشرة (بدل أيقونة مطمورة
      // ضمن actions شريط العنوان) — تسمية كاملة ظاهرة لكليهما كما طُلب.
      // Wrap بدل Row عمداً: على الشاشات الضيقة جداً حيث لا يتسع الزران معاً
      // بعرض واحد، ينتقل الثاني لسطر جديد تلقائياً بدل حدوث RIGHT OVERFLOWED.
      // ConstrainedBox صريح بعرض الشاشة لأن فتحة floatingActionButton داخل
      // Scaffold لا تضمن قيداً أقصى محدداً للعرض تلقائياً (Wrap يحتاج قيداً
      // محدوداً ليقرر متى ينتقل لسطر جديد).
      floatingActionButton: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            FloatingActionButton.extended(
              heroTag: 'scan_invoice_qr_fab',
              onPressed: _openQrScan,
              backgroundColor: Colors.white,
              foregroundColor: _identityColor,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("مسح الباركود"),
            ),
            FloatingActionButton.extended(
              heroTag: 'add_invoice_fab',
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddInvoicePage(hotel: widget.hotel)));
                if (result == true) {
                  await _reloadFilterOptions();
                  await _reload();
                }
              },
              backgroundColor: _identityColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text("إضافة فاتورة"),
            ),
          ],
        ),
      ),
      body: _isLoadingFirstPage && _hotels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _reloadFilterOptions();
                await _reload();
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _buildSummarySection()),
                  SliverToBoxAdapter(child: _buildControlsSection()),
                  SliverToBoxAdapter(child: _buildSearchAndFilters()),
                  _isLoadingFirstPage
                      ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                      : _invoices.isEmpty
                          ? SliverFillRemaining(child: _buildEmptyState())
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, 96),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index == _invoices.length) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                                        child: Center(child: _isLoadingMore ? const CircularProgressIndicator() : const SizedBox.shrink()),
                                      );
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                                      child: _buildInvoiceRow(_invoices[index]),
                                    );
                                  },
                                  childCount: _invoices.length + (_hasMore ? 1 : 0),
                                ),
                              ),
                            ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.md),
            const Text("لا توجد فواتير مطابقة", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.xs),
            const Text("جرّب تغيير الفترة أو الفلاتر، أو أضِف أول فاتورة", style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ---------------- بطاقات الملخص ----------------

  Widget _buildSummarySection() {
    final summary = _summary;
    final fmt = NumberFormat("#,##0.00");
    final cards = <_SummaryCardData>[
      _SummaryCardData("عدد الفواتير", summary == null ? "-" : "${summary.invoiceCount}", Icons.receipt_long),
      _SummaryCardData("إجمالي قيمة الفواتير", summary == null ? "-" : "${fmt.format(summary.totalAmount)} ريال", Icons.payments_outlined),
      _SummaryCardData("إجمالي ضريبة القيمة المضافة", summary == null ? "-" : "${fmt.format(summary.totalVat)} ريال", Icons.percent),
      _SummaryCardData("الإجمالي قبل الضريبة", summary == null ? "-" : "${fmt.format(summary.totalBeforeTax)} ريال", Icons.request_quote_outlined),
      _SummaryCardData("عدد الموردين", summary == null ? "-" : "${summary.supplierCount}", Icons.local_shipping_outlined),
      _SummaryCardData("آخر فاتورة مضافة", summary?.lastInvoice == null ? "لا توجد" : "${summary!.lastInvoice!.invoiceNumber} — ${summary.lastInvoice!.date}", Icons.history),
    ];

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (context, index) => _buildSummaryCard(cards[index]),
      ),
    );
  }

  Widget _buildSummaryCard(_SummaryCardData data) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: _identityColor, size: 20),
          const Spacer(),
          Text(
            data.value,
            style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(data.label, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ---------------- أدوات التحكم (الفندق + الفترة) ----------------

  Widget _buildControlsSection() {
    final periods = <(_PeriodPreset, String)>[
      (_PeriodPreset.today, "اليوم"),
      (_PeriodPreset.thisWeek, "الأسبوع الحالي"),
      (_PeriodPreset.lastWeek, "الأسبوع الماضي"),
      (_PeriodPreset.thisMonth, "هذا الشهر"),
      (_PeriodPreset.lastMonth, "الشهر الماضي"),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _openHotelScopeSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
              decoration: BoxDecoration(
                color: _identityColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: _identityColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.apartment, color: _identityColor, size: 18),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(child: Text(_hotelScopeLabel, style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
                  Icon(Icons.expand_more, color: _identityColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: periods.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == periods.length) {
                  return ChoiceChip(
                    label: const Text("فترة مخصصة"),
                    selected: _periodPreset == _PeriodPreset.custom,
                    onSelected: (_) => _pickCustomRange(),
                  );
                }
                final (preset, label) = periods[index];
                return ChoiceChip(
                  label: Text(label),
                  selected: _periodPreset == preset,
                  onSelected: (_) => _selectPeriod(preset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- البحث والفلاتر ----------------

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchBar(
            controller: _searchController,
            hintText: "بحث برقم الفاتورة أو اسم الشركة...",
            leading: const Icon(Icons.search),
            trailing: _searchController.text.isEmpty
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  ],
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFilterDropdown(
                label: "المورد",
                value: _supplierFilter,
                options: _availableSuppliers,
                onChanged: (v) {
                  setState(() => _supplierFilter = v);
                  _reload();
                },
              ),
              _buildFilterDropdown(
                label: "تصنيف المصروف",
                value: _categoryFilter,
                options: _availableCategories,
                includeUnclassified: true,
                onChanged: (v) {
                  setState(() => _categoryFilter = v);
                  _reload();
                },
              ),
              _buildFilterDropdown(
                label: "مصدر التمويل",
                value: _amountSourceFilter,
                options: _availableAmountSources,
                onChanged: (v) {
                  setState(() => _amountSourceFilter = v);
                  _reload();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool includeUnclassified = false,
  }) {
    final hasValue = value != null;
    return InputChip(
      label: Text(
        hasValue ? (value == kUnclassifiedInvoiceCategory ? "غير مصنَّف" : value) : label,
        style: const TextStyle(fontSize: 12),
      ),
      selected: hasValue,
      onPressed: () async {
        final chosen = await showModalBottomSheet<String?>(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(title: Text(label, style: AppTextStyles.bodyBold)),
                ListTile(
                  title: const Text("الكل"),
                  trailing: value == null ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(sheetContext, ''),
                ),
                if (includeUnclassified)
                  ListTile(
                    title: const Text("غير مصنَّف"),
                    trailing: value == kUnclassifiedInvoiceCategory ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(sheetContext, kUnclassifiedInvoiceCategory),
                  ),
                ...options.map((o) => ListTile(
                      title: Text(o),
                      trailing: value == o ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(sheetContext, o),
                    )),
              ],
            ),
          ),
        );
        if (chosen == null) return;
        onChanged(chosen.isEmpty ? null : chosen);
      },
      onDeleted: hasValue ? () => onChanged(null) : null,
      deleteIcon: hasValue ? const Icon(Icons.close, size: 16) : null,
    );
  }

  // ---------------- قائمة الفواتير ----------------

  Widget _buildInvoiceRow(Invoice invoice) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.xs),
        onTap: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailsPage(invoice: invoice, hotel: widget.hotel)));
          if (result == true) {
            await _reloadFilterOptions();
            await _reload();
          }
        },
        leading: CircleAvatar(
          backgroundColor: _identityColor.withOpacity(0.1),
          child: Icon(Icons.receipt_outlined, color: _identityColor, size: 20),
        ),
        title: Text(invoice.companyName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
        subtitle: Text(
          "#${invoice.invoiceNumber} · ${invoice.date} · ${invoice.expenseCategory ?? 'غير مصنَّف'} · ${invoice.amountSource}\n${invoice.facilityName}",
          style: AppTextStyles.caption,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${NumberFormat("#,##0.00").format(invoice.totalAmount)} ريال",
              style: AppTextStyles.bodyBold.copyWith(color: _identityColor, fontSize: 13),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onSelected: (value) {
                if (value == 'supplier_report') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SupplierReportPage(hotel: widget.hotel, companyName: invoice.companyName)),
                  );
                } else if (value == 'supplier_statement') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SupplierStatementPage(hotel: widget.hotel, companyName: invoice.companyName)),
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'supplier_statement', child: Text("كشف حساب المورد")),
                PopupMenuItem(value: 'supplier_report', child: Text("تقرير هذا المورد")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardData {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryCardData(this.label, this.value, this.icon);
}
