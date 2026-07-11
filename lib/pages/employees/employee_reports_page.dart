import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/employee.dart';
import '../../models/hotel.dart';
import '../../repositories/employee_repository.dart';
import '../../services/excel_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/hotel_identity_title.dart';

enum _ReportType { salary, advances, allowances, deductions, yearly }

class EmployeeReportsPage extends StatefulWidget {
  final Hotel hotel;
  const EmployeeReportsPage({super.key, required this.hotel});

  @override
  State<EmployeeReportsPage> createState() => _EmployeeReportsPageState();
}

class _EmployeeReportsPageState extends State<EmployeeReportsPage> {
  final _repository = EmployeeRepository();
  final _fmt = NumberFormat("#,##0.00");
  _ReportType _type = _ReportType.salary;
  String _period = 'month';
  DateTimeRange? _customRange;
  int _selectedYear = DateTime.now().year;
  bool _isLoading = true;

  List<Employee> _employees = [];
  List<Map<String, dynamic>> _payroll = [];
  List<Map<String, dynamic>> _advances = [];
  List<Map<String, dynamic>> _allowances = [];
  List<Map<String, dynamic>> _deductions = [];

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    _employees = await _repository.getEmployees(widget.hotel.id);
    _payroll = (await _repository.getPayrollRecords(hotelId: widget.hotel.id)).map((r) => r.toMap()).toList();
    _advances = await _repository.getAdvancesForHotel(widget.hotel.id);
    _allowances = await _repository.getAllowancesForHotel(widget.hotel.id);
    _deductions = await _repository.getDeductionsForHotel(widget.hotel.id);
    setState(() => _isLoading = false);
  }

  Map<int, Employee> get _employeeById => {for (var e in _employees) e.id!: e};

  DateTimeRange _resolveRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_period) {
      case 'day':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'custom':
        if (_customRange != null) {
          start = _customRange!.start;
          end = _customRange!.end.add(const Duration(hours: 23, minutes: 59));
        } else {
          start = DateTime(now.year, now.month, 1);
        }
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }
    return DateTimeRange(start: start, end: end);
  }

  bool _inRange(DateTime? d, DateTimeRange range) {
    if (d == null) return false;
    return d.isAfter(range.start.subtract(const Duration(seconds: 1))) && d.isBefore(range.end.add(const Duration(seconds: 1)));
  }

  List<Map<String, dynamic>> get _filteredPayroll {
    final range = _resolveRange();
    return _payroll.where((p) => _inRange(DateTime.tryParse("${p['period']}-01"), range)).toList();
  }

  List<Map<String, dynamic>> get _filteredAdvances {
    final range = _resolveRange();
    return _advances.where((a) => _inRange(DateTime.tryParse(a['date']?.toString() ?? ''), range)).toList();
  }

  List<Map<String, dynamic>> get _filteredAllowances {
    final range = _resolveRange();
    return _allowances.where((a) => _inRange(DateTime.tryParse(a['created_at']?.toString() ?? ''), range)).toList();
  }

  List<Map<String, dynamic>> get _filteredDeductions {
    final range = _resolveRange();
    return _deductions.where((d) => _inRange(DateTime.tryParse(d['created_at']?.toString() ?? ''), range)).toList();
  }

  List<Map<String, dynamic>> get _yearlyPayroll {
    return _payroll.where((p) => (p['period']?.toString() ?? '').startsWith('$_selectedYear-')).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "تقارير الموظفين", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_type == _ReportType.salary)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: "تصدير Excel",
              onPressed: _exportPayrollExcel,
            ),
        ],
      ),
      body: _isLoading
          ? const AppLoading()
          : Column(
              children: [
                _buildTypeSelector(),
                if (_type == _ReportType.yearly) _buildYearSelector() else _buildPeriodSelector(),
                Expanded(child: _buildBody()),
              ],
            ),
    );
  }

  Widget _buildTypeSelector() {
    final options = {
      _ReportType.salary: "الرواتب",
      _ReportType.advances: "السلف",
      _ReportType.allowances: "البدلات",
      _ReportType.deductions: "الخصومات",
      _ReportType.yearly: "التقرير السنوي",
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        child: Row(
          children: options.entries.map((e) {
            final selected = _type == e.key;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: selected,
                onSelected: (_) => setState(() => _type = e.key),
                selectedColor: _identityColor,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final options = {'day': 'اليوم', 'week': 'الأسبوع', 'month': 'الشهر', 'year': 'السنة', 'custom': 'مخصص'};
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        child: Row(
          children: options.entries.map((e) {
            final selected = _period == e.key;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: selected,
                onSelected: (_) async {
                  if (e.key == 'custom') {
                    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() { _period = 'custom'; _customRange = picked; });
                  } else {
                    setState(() => _period = e.key);
                  }
                },
                selectedColor: _identityColor,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    final years = List.generate(6, (i) => DateTime.now().year - i);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        child: Row(
          children: years.map((y) {
            final selected = _selectedYear == y;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text("$y"),
                selected: selected,
                onSelected: (_) => setState(() => _selectedYear = y),
                selectedColor: _identityColor,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_type) {
      case _ReportType.salary:
        return _buildSalaryReport();
      case _ReportType.advances:
        return _buildAdvancesReport();
      case _ReportType.allowances:
        return _buildAllowancesReport();
      case _ReportType.deductions:
        return _buildDeductionsReport();
      case _ReportType.yearly:
        return _buildYearlyReport();
    }
  }

  Widget _buildSalaryReport() {
    final rows = _filteredPayroll;
    final totalNet = rows.fold(0.0, (s, r) => s + (r['net_salary'] as num).toDouble());
    final totalCash = rows.fold(0.0, (s, r) => s + (r['cash_amount'] as num).toDouble());
    final totalBank = rows.fold(0.0, (s, r) => s + (r['bank_amount'] as num).toDouble());
    final totalPersonal = rows.fold(0.0, (s, r) => s + (r['personal_amount'] as num).toDouble());

    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        AppCard(
          color: _identityColor,
          child: Column(
            children: [
              const Text("إجمالي صافي الرواتب", style: TextStyle(color: Colors.white70)),
              Text("${_fmt.format(totalNet)} ر.س", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24, height: AppSizes.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem("نقد", totalCash),
                  _summaryItem("بنك", totalBank),
                  _summaryItem("شخصي", totalPersonal),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        if (rows.isEmpty) _emptyState("لا توجد رواتب معتمدة في هذه الفترة"),
        ...rows.map((r) {
          final emp = _employeeById[r['employee_id']];
          return _buildReportRow(
            title: emp?.name ?? '—',
            subtitle: "${emp?.position ?? ''} • ${r['period']} • ${r['status'] == 'paid' ? 'مصروف' : 'معتمد'}",
            amount: (r['net_salary'] as num).toDouble(),
          );
        }),
      ],
    );
  }

  Widget _buildAdvancesReport() {
    final rows = _filteredAdvances;
    final total = rows.fold(0.0, (s, r) => s + (r['amount'] as num).toDouble());
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        AppCard(color: _identityColor, child: _totalHeader("إجمالي السلف", total)),
        const SizedBox(height: AppSizes.md),
        if (rows.isEmpty) _emptyState("لا توجد سلف في هذه الفترة"),
        ...rows.map((r) => _buildReportRow(
              title: r['employee_name']?.toString() ?? '—',
              subtitle: "${r['date']}${(r['is_settled'] == 1) ? ' • مسددة' : ' • غير مسددة'}",
              amount: (r['amount'] as num).toDouble(),
            )),
      ],
    );
  }

  Widget _buildAllowancesReport() {
    final rows = _filteredAllowances;
    final total = rows.fold(0.0, (s, r) => s + (r['amount'] as num).toDouble());
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        AppCard(color: _identityColor, child: _totalHeader("إجمالي البدلات", total)),
        const SizedBox(height: AppSizes.md),
        if (rows.isEmpty) _emptyState("لا توجد بدلات في هذه الفترة"),
        ...rows.map((r) => _buildReportRow(
              title: r['employee_name']?.toString() ?? '—',
              subtitle: r['name']?.toString() ?? '',
              amount: (r['amount'] as num).toDouble(),
            )),
      ],
    );
  }

  Widget _buildDeductionsReport() {
    final rows = _filteredDeductions;
    final total = rows.fold(0.0, (s, r) => s + (r['amount'] as num).toDouble());
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        AppCard(color: _identityColor, child: _totalHeader("إجمالي الخصومات", total)),
        const SizedBox(height: AppSizes.md),
        if (rows.isEmpty) _emptyState("لا توجد خصومات في هذه الفترة"),
        ...rows.map((r) => _buildReportRow(
              title: r['employee_name']?.toString() ?? '—',
              subtitle: r['name']?.toString() ?? '',
              amount: (r['amount'] as num).toDouble(),
            )),
      ],
    );
  }

  Widget _buildYearlyReport() {
    final rows = _yearlyPayroll;
    final Map<int, double> byMonth = {for (var m = 1; m <= 12; m++) m: 0.0};
    for (var r in rows) {
      final period = r['period']?.toString() ?? '';
      final parts = period.split('-');
      if (parts.length == 2) {
        final m = int.tryParse(parts[1]);
        if (m != null && m >= 1 && m <= 12) byMonth[m] = (byMonth[m] ?? 0) + (r['net_salary'] as num).toDouble();
      }
    }
    final total = byMonth.values.fold(0.0, (s, v) => s + v);
    const monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        AppCard(color: _identityColor, child: _totalHeader("إجمالي رواتب $_selectedYear", total)),
        const SizedBox(height: AppSizes.md),
        AppCard(
          identityAccent: _identityColor,
          child: Column(
            children: List.generate(12, (i) {
              final month = i + 1;
              final amount = byMonth[month] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(monthNames[i], style: AppTextStyles.body),
                    Text(_fmt.format(amount), style: AppTextStyles.bodyBold.copyWith(color: amount > 0 ? _identityColor : AppColors.textSecondary)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _totalHeader(String label, double amount) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text("${_fmt.format(amount)} ر.س", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _summaryItem(String label, double amount) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(_fmt.format(amount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))),
    );
  }

  Widget _buildReportRow({required String title, required String subtitle, required double amount}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.sm),
        identityAccent: _identityColor,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyBold),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Text(_fmt.format(amount), style: AppTextStyles.bodyBold.copyWith(color: _identityColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPayrollExcel() async {
    final rows = _filteredPayroll.map((r) {
      final emp = _employeeById[r['employee_id']];
      return {
        'name': emp?.name ?? '—',
        'position': emp?.position ?? '',
        'base': r['base_salary'],
        'allowances': r['allowances_total'],
        'deductions': r['deductions_total'],
        'net': r['net_salary'],
        'cash': r['cash_amount'],
        'bank': r['bank_amount'],
        'personal': r['personal_amount'],
      };
    }).toList();

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد بيانات رواتب لتصديرها في هذه الفترة")));
      return;
    }

    await ExcelService.exportPayrollReport(hotel: widget.hotel, period: _periodLabel(), rows: rows);
  }

  String _periodLabel() {
    final range = _resolveRange();
    return "${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')} إلى ${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}";
  }
}
