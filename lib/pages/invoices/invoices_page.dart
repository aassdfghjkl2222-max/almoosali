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
import '../../widgets/common/app_drawer.dart';
import '../settings/financial_categories_page.dart';
import 'add_invoice_page.dart';
import 'invoice_capture_processing_page.dart';
import 'invoice_capture_sheet.dart';
import 'invoice_details_page.dart';
import 'invoice_reports_page.dart';

enum _HotelScope { current, all, custom }

enum _PeriodPreset { today, thisWeek, lastWeek, thisMonth, lastMonth, custom }

/// مركز "الفواتير الضريبية" لكل فندق — واجهة مُعاد تصميمها بالكامل: شريط
/// علوي مبسَّط (بحث/فلاتر/تصدير فقط)، بلا اسم فندق مكرَّر (الفندق الحالي
/// ضمني من widget.hotel؛ التبديل لفندق آخر/كل الفنادق فقط عبر قسم "الفندق"
/// داخل نافذة الفلاتر الموحَّدة)، بطاقة فاتورة مبسَّطة (مورد + مبلغ فقط،
/// بقية الحقول داخل InvoiceDetailsPage)، وزرّا الإضافة/مسح الباركود ثابتان
/// أسفل الشاشة دائماً. منطق الفلترة/الفرز/الصفحات نفسه تماماً
/// (InvoiceRepository) — هذه إعادة تنظيم واجهة فقط، بلا أي تغيير حسابي.
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

  bool _isSearchVisible = false;
  String _searchQuery = '';
  String? _supplierFilter;
  String? _categoryFilter;
  String? _amountSourceFilter;
  String? _paymentMethodFilter;
  bool? _isPostedFilter;

  List<String> _availableSuppliers = [];
  List<String> _availableCategories = [];
  List<String> _availableAmountSources = [];

  String _sortKey = 'date_desc';

  InvoicesSummary? _summary;
  final List<Invoice> _invoices = [];
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  bool get _hasActiveFilters =>
      _hotelScope != _HotelScope.current ||
      _supplierFilter != null ||
      _categoryFilter != null ||
      _amountSourceFilter != null ||
      _paymentMethodFilter != null ||
      _periodPreset != null ||
      _isPostedFilter != null;

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
      paymentMethod: _paymentMethodFilter,
      isPosted: _isPostedFilter,
      searchQuery: _searchQuery,
    );
    final firstPage = await _invoiceRepo.getInvoicesPagedFiltered(
      hotelIds: hotelIds,
      startDate: start,
      endDate: end,
      supplierName: _supplierFilter,
      category: _categoryFilter,
      amountSource: _amountSourceFilter,
      paymentMethod: _paymentMethodFilter,
      isPosted: _isPostedFilter,
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
      paymentMethod: _paymentMethodFilter,
      isPosted: _isPostedFilter,
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

  void _toggleSearch() {
    setState(() => _isSearchVisible = !_isSearchVisible);
    if (!_isSearchVisible && _searchQuery.isNotEmpty) {
      _searchController.clear();
      _searchQuery = '';
      _reload();
    }
  }

  void _openReportsPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceReportsPage(hotel: widget.hotel)));
  }

  /// يفتح ورقة اختيار مصدر مسح الفاتورة (تصوير/معرض/PDF)، ثم شاشة معالجة
  /// موجزة تُجري خط الأنابيب الكامل تلقائياً (QR على الصورة الثابتة، وإلا
  /// ذكاء اصطناعي سحابي، وإلا OCR محلي) وتنتهي إما بـQuickInvoiceReviewPage
  /// مباشرة أو بحفظ فعلي (`true`) عبر "إدخال يدوي" من شاشة المعالجة نفسها
  /// عند فشل القراءة كلياً.
  Future<void> _openInvoiceCapture() async {
    final source = await showInvoiceCaptureSheet(context, hotel: widget.hotel);
    if (!mounted || source == null) return;

    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceCaptureProcessingPage(hotel: widget.hotel, source: source)));
    if (result != true) return;

    await _reloadFilterOptions();
    await _reload();
  }

  // ---------------- نافذة الفلاتر الموحَّدة ----------------

  /// نافذة واحدة تجمع كل أبعاد التصفية/الفرز (البند 4) — نسخ محلية من كل
  /// فلتر تُعدَّل داخل النافذة فقط، ولا تُطبَّق على الشاشة الفعلية إلا عند
  /// الضغط على "تطبيق" (نفس نمط `reports_center_page.dart::_openFilterSheet`).
  /// إضافة فلتر مستقبلي = قسم جديد هنا فقط، بلا أي تعديل على AppBar أو بقية
  /// الشاشة.
  Future<void> _openFiltersSheet() async {
    var scope = _hotelScope;
    var customHotels = {..._customHotelIds};
    var supplier = _supplierFilter;
    var category = _categoryFilter;
    var amountSource = _amountSourceFilter;
    var paymentMethod = _paymentMethodFilter;
    var period = _periodPreset;
    var customStart = _customStart;
    var customEnd = _customEnd;
    var isPosted = _isPostedFilter;
    var sortKey = _sortKey;

    final periods = <(_PeriodPreset, String)>[
      (_PeriodPreset.today, "اليوم"),
      (_PeriodPreset.thisWeek, "هذا الأسبوع"),
      (_PeriodPreset.lastWeek, "الأسبوع الماضي"),
      (_PeriodPreset.thisMonth, "هذا الشهر"),
      (_PeriodPreset.lastMonth, "الشهر الماضي"),
    ];
    final sortOptions = <(String, String)>[
      ('date_desc', "الأحدث أولاً"),
      ('date_asc', "الأقدم أولاً"),
      ('amount_desc', "المبلغ الأعلى"),
      ('amount_asc', "المبلغ الأقل"),
      ('invoice_number_desc', "رقم الفاتورة تنازلياً"),
      ('invoice_number_asc', "رقم الفاتورة تصاعدياً"),
    ];

    final applied = await showModalBottomSheet<bool>(
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
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.88),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("الفلاتر", style: AppTextStyles.title.copyWith(fontSize: 18))),
                        TextButton(
                          onPressed: () => setSheetState(() {
                            scope = _HotelScope.current;
                            customHotels = {widget.hotel.id!};
                            supplier = null;
                            category = null;
                            amountSource = null;
                            paymentMethod = null;
                            period = null;
                            customStart = null;
                            customEnd = null;
                            isPosted = null;
                            sortKey = 'date_desc';
                          }),
                          child: const Text("إعادة تعيين"),
                        ),
                      ],
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filterSectionTitle("الفندق"),
                            RadioListTile<_HotelScope>(
                              contentPadding: EdgeInsets.zero,
                              title: Text("هذا الفندق فقط (${widget.hotel.arabicName})", style: const TextStyle(fontSize: 13)),
                              value: _HotelScope.current,
                              groupValue: scope,
                              onChanged: (v) => setSheetState(() => scope = v!),
                            ),
                            RadioListTile<_HotelScope>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("جميع الفنادق", style: TextStyle(fontSize: 13)),
                              value: _HotelScope.all,
                              groupValue: scope,
                              onChanged: (v) => setSheetState(() => scope = v!),
                            ),
                            RadioListTile<_HotelScope>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("تحديد عدة فنادق", style: TextStyle(fontSize: 13)),
                              value: _HotelScope.custom,
                              groupValue: scope,
                              onChanged: (v) => setSheetState(() => scope = v!),
                            ),
                            if (scope == _HotelScope.custom)
                              ..._hotels.map((h) => CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(h.arabicName, style: const TextStyle(fontSize: 13)),
                                    value: customHotels.contains(h.id),
                                    onChanged: (checked) => setSheetState(() {
                                      if (checked == true) {
                                        customHotels.add(h.id!);
                                      } else {
                                        customHotels.remove(h.id!);
                                      }
                                    }),
                                  )),
                            const Divider(height: AppSizes.lg),
                            _filterSectionTitle("المورد"),
                            const SizedBox(height: AppSizes.xs),
                            _buildChipPicker(
                              sheetContext: sheetContext,
                              label: "المورد",
                              value: supplier,
                              options: _availableSuppliers,
                              onChanged: (v) => setSheetState(() => supplier = v),
                            ),
                            const Divider(height: AppSizes.lg),
                            _filterSectionTitle("تصنيف المصروف"),
                            const SizedBox(height: AppSizes.xs),
                            _buildChipPicker(
                              sheetContext: sheetContext,
                              label: "تصنيف المصروف",
                              value: category,
                              options: _availableCategories,
                              includeUnclassified: true,
                              onChanged: (v) => setSheetState(() => category = v),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => FinancialCategoriesPage(hotel: widget.hotel)));
                                },
                                icon: const Icon(Icons.settings_outlined, size: 16),
                                label: const Text("إدارة الفئات المالية", style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const Divider(height: AppSizes.lg),
                            _filterSectionTitle("مصدر التمويل"),
                            const SizedBox(height: AppSizes.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kInvoiceFundingSources.map((option) {
                                final isSelected = amountSource == option.label;
                                return ChoiceChip(
                                  label: Text(option.label, style: const TextStyle(fontSize: 12)),
                                  avatar: Icon(option.icon, size: 16, color: isSelected ? Colors.white : option.color),
                                  selected: isSelected,
                                  selectedColor: option.color,
                                  labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.bold : null),
                                  onSelected: (_) => setSheetState(() => amountSource = isSelected ? null : option.label),
                                );
                              }).toList(),
                            ),
                            const Divider(height: AppSizes.lg),
                            _filterSectionTitle("نوع العملية"),
                            const SizedBox(height: AppSizes.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kInvoicePaymentMethods.map((method) {
                                final isSelected = paymentMethod == method;
                                return ChoiceChip(
                                  label: Text(method, style: const TextStyle(fontSize: 12)),
                                  selected: isSelected,
                                  onSelected: (_) => setSheetState(() => paymentMethod = isSelected ? null : method),
                                );
                              }).toList(),
                            ),
                            const Divider(height: AppSizes.lg),
                            _filterSectionTitle("الفترة"),
                            const SizedBox(height: AppSizes.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...periods.map((p) => ChoiceChip(
                                      label: Text(p.$2, style: const TextStyle(fontSize: 12)),
                                      selected: period == p.$1,
                                      onSelected: (_) => setSheetState(() => period = period == p.$1 ? null : p.$1),
                                    )),
                                ChoiceChip(
                                  label: Text(
                                    customStart != null && period == _PeriodPreset.custom
                                        ? "${DateFormat('yyyy-MM-dd').format(customStart!)} → ${DateFormat('yyyy-MM-dd').format(customEnd!)}"
                                        : "فترة مخصصة",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  selected: period == _PeriodPreset.custom,
                                  onSelected: (_) async {
                                    final range = await showDateRangePicker(
                                      context: sheetContext,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                      initialDateRange: customStart != null && customEnd != null ? DateTimeRange(start: customStart!, end: customEnd!) : null,
                                    );
                                    if (range == null) return;
                                    setSheetState(() {
                                      period = _PeriodPreset.custom;
                                      customStart = range.start;
                                      customEnd = range.end;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: AppSizes.lg),
                            _filterSectionTitle("الحالة"),
                            const SizedBox(height: AppSizes.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(label: const Text("الكل", style: TextStyle(fontSize: 12)), selected: isPosted == null, onSelected: (_) => setSheetState(() => isPosted = null)),
                                ChoiceChip(label: const Text("مرحّلة", style: TextStyle(fontSize: 12)), selected: isPosted == true, onSelected: (_) => setSheetState(() => isPosted = true)),
                                ChoiceChip(label: const Text("غير مرحّلة", style: TextStyle(fontSize: 12)), selected: isPosted == false, onSelected: (_) => setSheetState(() => isPosted = false)),
                              ],
                            ),
                            const Divider(height: AppSizes.lg),
                            _filterSectionTitle("الترتيب"),
                            const SizedBox(height: AppSizes.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: sortOptions.map((s) => ChoiceChip(
                                    label: Text(s.$2, style: const TextStyle(fontSize: 12)),
                                    selected: sortKey == s.$1,
                                    onSelected: (_) => setSheetState(() => sortKey = s.$1),
                                  )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
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
              ),
            );
          },
        );
      },
    );

    if (applied != true) return;
    setState(() {
      _hotelScope = scope;
      _customHotelIds = customHotels.isEmpty ? {widget.hotel.id!} : customHotels;
      _supplierFilter = supplier;
      _categoryFilter = category;
      _amountSourceFilter = amountSource;
      _paymentMethodFilter = paymentMethod;
      _periodPreset = period;
      _customStart = customStart;
      _customEnd = customEnd;
      _isPostedFilter = isPosted;
      _sortKey = sortKey;
    });
    await _reloadFilterOptions();
    await _reload();
  }

  Widget _filterSectionTitle(String title) => Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 13));

  /// منتقي قيمة واحدة من قائمة قد تطول (المورد/تصنيف المصروف) — رقاقة تفتح
  /// نافذة سفلية متداخلة فوق نافذة الفلاتر نفسها (Flutter يدعم ذلك بأمان)،
  /// وتُحدِّث حالة نافذة الفلاتر المحلية عبر [onChanged] فقط (لا تُطبَّق على
  /// الشاشة الفعلية إلا بالضغط على "تطبيق" في النافذة الخارجية).
  Widget _buildChipPicker({
    required BuildContext sheetContext,
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool includeUnclassified = false,
  }) {
    final hasValue = value != null;
    return InputChip(
      label: Text(
        hasValue ? (value == kUnclassifiedInvoiceCategory ? "غير مصنَّف" : value) : "الكل",
        style: const TextStyle(fontSize: 12),
      ),
      selected: hasValue,
      onPressed: () async {
        final chosen = await showModalBottomSheet<String?>(
          context: sheetContext,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
          builder: (innerContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(title: Text(label, style: AppTextStyles.bodyBold)),
                ListTile(
                  title: const Text("الكل"),
                  trailing: value == null ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(innerContext, ''),
                ),
                if (includeUnclassified)
                  ListTile(
                    title: const Text("غير مصنَّف"),
                    trailing: value == kUnclassifiedInvoiceCategory ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(innerContext, kUnclassifiedInvoiceCategory),
                  ),
                ...options.map((o) => ListTile(
                      title: Text(o),
                      trailing: value == o ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(innerContext, o),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: "رقم الفاتورة، المورد، أو الرقم الضريبي...",
                  hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text("الفواتير الضريبية", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: !_isSearchVisible,
        backgroundColor: _identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            tooltip: _isSearchVisible ? "إغلاق البحث" : "بحث",
            onPressed: _toggleSearch,
          ),
          if (!_isSearchVisible) ...[
            IconButton(
              icon: Badge(isLabelVisible: _hasActiveFilters, smallSize: 8, child: const Icon(Icons.tune)),
              tooltip: "الفلاتر",
              onPressed: _openFiltersSheet,
            ),
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: "تصدير التقرير",
              onPressed: _openReportsPage,
            ),
          ],
        ],
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      // زر "مسح الباركود" بجانب زر "إضافة فاتورة" مباشرة — تسمية كاملة ظاهرة
      // لكليهما. Wrap بدل Row عمداً: على الشاشات الضيقة جداً حيث لا يتسع
      // الزران معاً بعرض واحد، ينتقل الثاني لسطر جديد تلقائياً بدل حدوث
      // RIGHT OVERFLOWED. ConstrainedBox صريح بعرض الشاشة لأن فتحة
      // floatingActionButton داخل Scaffold لا تضمن قيداً أقصى محدداً للعرض
      // تلقائياً (Wrap يحتاج قيداً محدوداً ليقرر متى ينتقل لسطر جديد).
      floatingActionButton: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            FloatingActionButton.extended(
              heroTag: 'scan_invoice_qr_fab',
              onPressed: _openInvoiceCapture,
              backgroundColor: Colors.white,
              foregroundColor: _identityColor,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("الباركود"),
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
                  _isLoadingFirstPage
                      ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                      : _invoices.isEmpty
                          ? SliverFillRemaining(child: _buildEmptyState())
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, 96),
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
            const Text("جرّب تغيير الفلاتر، أو أضِف أول فاتورة", style: AppTextStyles.caption, textAlign: TextAlign.center),
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
      height: 116,
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

  // ---------------- قائمة الفواتير ----------------

  /// بطاقة فاتورة مبسَّطة — اسم المورد والمبلغ فقط (البند 5)؛ بقية الحقول
  /// (التاريخ/التصنيف/مصدر التمويل/الفندق/رقم الفاتورة) تظهر في
  /// InvoiceDetailsPage بعد الفتح. Row بسيط بلا أي قيد ارتفاع (نفس منهجية
  /// إصلاح BOTTOM OVERFLOWED السابقة لهذه الشاشة تحديداً).
  Widget _buildInvoiceRow(Invoice invoice) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailsPage(invoice: invoice, hotel: widget.hotel)));
            if (result == true) {
              await _reloadFilterOptions();
              await _reload();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.md),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _identityColor.withOpacity(0.1),
                  child: Icon(Icons.receipt_outlined, color: _identityColor, size: 20),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(invoice.companyName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  "${NumberFormat("#,##0.00").format(invoice.totalAmount)} ريال",
                  style: AppTextStyles.bodyBold.copyWith(color: _identityColor, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
