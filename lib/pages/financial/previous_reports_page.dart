import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/financial_report.dart';
import '../../models/hotel.dart';
import '../../repositories/financial_repository.dart';
import 'saved_report_view_page.dart';

/// "التقارير السابقة" — كل التقارير المحفوظة لهذا الفندق، الأحدث أولاً، مع
/// فلاتر فترة سريعة. الضغط على أي تقرير يفتحه كاملاً (SavedReportViewPage)
/// بنفس القالب الرسمي مع خيارات العرض/المشاركة/PDF/الطباعة.
class PreviousReportsPage extends StatefulWidget {
  final Hotel hotel;
  const PreviousReportsPage({super.key, required this.hotel});

  @override
  State<PreviousReportsPage> createState() => _PreviousReportsPageState();
}

class _PreviousReportsPageState extends State<PreviousReportsPage> {
  final _repository = FinancialRepository();
  String _periodKey = 'today';
  DateTimeRange? _customRange;
  List<FinancialReport> _reports = [];
  bool _isLoading = true;

  /// "اليوم" هنا يعني يوم العمل الحالي (أمس تقويمياً) — نفس اصطلاح تاريخ
  /// التقرير المعتمد في شاشة التقرير المالي اليومي نفسها، وليس تاريخ الجهاز.
  DateTime get _businessToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    DateTime? from, to;
    final today = _businessToday;
    switch (_periodKey) {
      case 'today':
        from = today;
        to = today;
        break;
      case '5':
        from = today.subtract(const Duration(days: 4));
        to = today;
        break;
      case '10':
        from = today.subtract(const Duration(days: 9));
        to = today;
        break;
      case '30':
        from = today.subtract(const Duration(days: 29));
        to = today;
        break;
      case 'custom':
        from = _customRange?.start;
        to = _customRange?.end;
        break;
    }
    final reports = await _repository.getReportsFiltered(hotelIds: [widget.hotel.id!], fromDate: from, toDate: to, limit: 500);
    if (mounted) setState(() { _reports = reports; _isLoading = false; });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDateRange: _customRange,
      locale: const Locale('ar', 'SA'),
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _periodKey = 'custom';
      });
      _load();
    }
  }

  void _selectPeriod(String key) {
    if (key == 'custom') {
      _pickCustomRange();
      return;
    }
    setState(() => _periodKey = key);
    _load();
  }

  double _netCashFor(FinancialReport r) {
    if (r.detailsJson == null) return 0;
    try {
      final details = jsonDecode(r.detailsJson!) as Map<String, dynamic>;
      final v = details['net_cash'];
      return v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("التقارير السابقة", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildPeriodFilters(identityColor),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? const Center(child: Text("لا توجد تقارير في هذه الفترة", style: AppTextStyles.caption))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSizes.md),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) => _buildReportCard(_reports[index], identityColor),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilters(Color identityColor) {
    final options = <(String, String)>[
      ('today', "اليوم"),
      ('5', "آخر 5 أيام"),
      ('10', "آخر 10 أيام"),
      ('30', "آخر 30 يوماً"),
      ('custom', _customRange != null ? "${DateFormat('yyyy-MM-dd').format(_customRange!.start)} → ${DateFormat('yyyy-MM-dd').format(_customRange!.end)}" : "فترة مخصصة"),
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final (key, label) = options[index];
            final selected = _periodKey == key;
            return ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              selected: selected,
              selectedColor: identityColor,
              labelStyle: TextStyle(color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface),
              onSelected: (_) => _selectPeriod(key),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReportCard(FinancialReport report, Color identityColor) {
    final fmt = NumberFormat("#,##0.##");
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavedReportViewPage(hotel: widget.hotel, report: report))),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(DateFormat('yyyy-MM-dd').format(DateTime.parse(report.date)), style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (report.isPosted ? AppColors.success : AppColors.warning).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      report.isPosted ? "معتمد" : "غير معتمد",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: report.isPosted ? AppColors.success : AppColors.warning),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.hotel.arabicName, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(child: _statColumn("الإيرادات", fmt.format(report.income), AppColors.success)),
                  Expanded(child: _statColumn("المصروفات", fmt.format(report.expenses), AppColors.danger)),
                  Expanded(child: _statColumn("صافي النقد", fmt.format(_netCashFor(report)), identityColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
