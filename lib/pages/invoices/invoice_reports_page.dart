import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../models/invoice.dart';
import '../../repositories/invoice_repository.dart';
import '../../services/excel_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';

enum _ReportPeriod { day, week, month, year, custom }

/// قسم التقارير داخل الفواتير الضريبية — إنشاء تقرير بفترة وفلاتر مختارة
/// وتصديره إلى Excel. لا يوجد أي ربط هنا مع مركز التحليل أو المركز المالي
/// أو العلاقات المالية عمداً — تلك ستُضاف في مهمة قادمة.
class InvoiceReportsPage extends StatefulWidget {
  final Hotel hotel;
  const InvoiceReportsPage({super.key, required this.hotel});

  @override
  State<InvoiceReportsPage> createState() => _InvoiceReportsPageState();
}

class _InvoiceReportsPageState extends State<InvoiceReportsPage> {
  final _invoiceRepo = InvoiceRepository();

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  bool _allHotels = false;
  _ReportPeriod _period = _ReportPeriod.month;
  DateTime? _customStart;
  DateTime? _customEnd;

  String? _supplierFilter;
  String? _categoryFilter;
  String? _amountSourceFilter;

  List<String> _availableSuppliers = [];
  List<String> _availableCategories = [];
  List<String> _availableAmountSources = [];

  bool _isLoading = false;
  bool _isExporting = false;
  InvoicesSummary? _summary;
  List<Invoice>? _reportInvoices;

  List<int>? get _hotelIds => _allHotels ? null : [widget.hotel.id!];

  (String?, String?) get _dateRange {
    final now = DateTime.now();
    String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    switch (_period) {
      case _ReportPeriod.day:
        return (fmt(now), fmt(now));
      case _ReportPeriod.week:
        return (fmt(now.subtract(Duration(days: now.weekday - 1))), fmt(now));
      case _ReportPeriod.month:
        return (fmt(DateTime(now.year, now.month, 1)), fmt(now));
      case _ReportPeriod.year:
        return (fmt(DateTime(now.year, 1, 1)), fmt(now));
      case _ReportPeriod.custom:
        return (_customStart != null ? fmt(_customStart!) : null, _customEnd != null ? fmt(_customEnd!) : null);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    final suppliers = await _invoiceRepo.getDistinctSuppliers(_hotelIds);
    final categories = await _invoiceRepo.getDistinctCategories(_hotelIds);
    final amountSources = await _invoiceRepo.getDistinctAmountSources(_hotelIds);
    if (!mounted) return;
    setState(() {
      _availableSuppliers = suppliers;
      _availableCategories = categories;
      _availableAmountSources = amountSources;
      if (_supplierFilter != null && !_availableSuppliers.contains(_supplierFilter)) _supplierFilter = null;
      if (_categoryFilter != null && !_availableCategories.contains(_categoryFilter)) _categoryFilter = null;
      if (_amountSourceFilter != null && !_availableAmountSources.contains(_amountSourceFilter)) _amountSourceFilter = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customStart != null && _customEnd != null ? DateTimeRange(start: _customStart!, end: _customEnd!) : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _identityColor)),
        child: child!,
      ),
    );
    if (range == null) return;
    setState(() {
      _period = _ReportPeriod.custom;
      _customStart = range.start;
      _customEnd = range.end;
    });
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _summary = null;
      _reportInvoices = null;
    });
    final (start, end) = _dateRange;
    final summary = await _invoiceRepo.getInvoicesSummary(
      hotelIds: _hotelIds,
      startDate: start,
      endDate: end,
      supplierName: _supplierFilter,
      category: _categoryFilter,
      amountSource: _amountSourceFilter,
    );
    final invoices = await _invoiceRepo.getAllFilteredInvoicesForReport(
      hotelIds: _hotelIds,
      startDate: start,
      endDate: end,
      supplierName: _supplierFilter,
      category: _categoryFilter,
      amountSource: _amountSourceFilter,
    );
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _reportInvoices = invoices;
      _isLoading = false;
    });
  }

  Future<void> _export() async {
    if (_reportInvoices == null) return;
    setState(() => _isExporting = true);
    final (start, end) = _dateRange;
    try {
      await ExcelService.exportInvoicesDetailedReport(
        scopeLabel: _allHotels ? "جميع الفنادق" : widget.hotel.arabicName,
        invoices: _reportInvoices!,
        fromDate: start != null ? DateTime.tryParse(start) : null,
        toDate: end != null ? DateTime.tryParse(end) : null,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "تقارير الفواتير الضريبية", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          _buildScopeCard(),
          const SizedBox(height: AppSizes.md),
          _buildPeriodCard(),
          const SizedBox(height: AppSizes.md),
          _buildFiltersCard(),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _generateReport,
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.insert_chart_outlined),
              label: const Text("إنشاء التقرير"),
            ),
          ),
          if (_summary != null) ...[
            const SizedBox(height: AppSizes.lg),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("النطاق", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(widget.hotel.arabicName, style: const TextStyle(fontSize: 12))),
              const ButtonSegment(value: true, label: Text("جميع الفنادق", style: TextStyle(fontSize: 12))),
            ],
            selected: {_allHotels},
            showSelectedIcon: false,
            onSelectionChanged: (v) {
              setState(() => _allHotels = v.first);
              _loadFilterOptions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard() {
    final periods = <(_ReportPeriod, String)>[
      (_ReportPeriod.day, "يوم"),
      (_ReportPeriod.week, "أسبوع"),
      (_ReportPeriod.month, "شهر"),
      (_ReportPeriod.year, "سنة"),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("الفترة", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...periods.map((p) => ChoiceChip(
                    label: Text(p.$2),
                    selected: _period == p.$1,
                    onSelected: (_) => setState(() => _period = p.$1),
                  )),
              ChoiceChip(
                label: Text(_customStart != null && _period == _ReportPeriod.custom
                    ? "${DateFormat('yyyy-MM-dd').format(_customStart!)} → ${DateFormat('yyyy-MM-dd').format(_customEnd!)}"
                    : "فترة مخصصة"),
                selected: _period == _ReportPeriod.custom,
                onSelected: (_) => _pickCustomRange(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("الفلاتر", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(label: "المورد", value: _supplierFilter, options: _availableSuppliers, onChanged: (v) => setState(() => _supplierFilter = v)),
              _buildFilterChip(label: "تصنيف المصروف", value: _categoryFilter, options: _availableCategories, onChanged: (v) => setState(() => _categoryFilter = v)),
              _buildFilterChip(label: "مصدر التمويل", value: _amountSourceFilter, options: _availableAmountSources, onChanged: (v) => setState(() => _amountSourceFilter = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final hasValue = value != null;
    return InputChip(
      label: Text(hasValue ? value : label, style: const TextStyle(fontSize: 12)),
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

  Widget _buildResultCard() {
    final summary = _summary!;
    final fmt = NumberFormat("#,##0.00");
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("نتيجة التقرير", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          _resultRow("عدد الفواتير", "${summary.invoiceCount}"),
          _resultRow("إجمالي قبل الضريبة", "${fmt.format(summary.totalBeforeTax)} ريال"),
          _resultRow("إجمالي الضريبة", "${fmt.format(summary.totalVat)} ريال"),
          _resultRow("الإجمالي شامل الضريبة", "${fmt.format(summary.totalAmount)} ريال", isBold: true),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: summary.invoiceCount == 0 || _isExporting ? null : _export,
              icon: _isExporting
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _identityColor))
                  : const Icon(Icons.file_download_outlined),
              label: const Text("تصدير Excel"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(value, style: isBold ? AppTextStyles.bodyBold.copyWith(color: _identityColor) : AppTextStyles.bodyBold.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
