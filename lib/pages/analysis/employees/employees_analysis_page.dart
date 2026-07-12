import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/employee.dart';
import '../../../models/hotel.dart';
import '../../../repositories/employee_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../widgets/common/app_card.dart';
import 'employee_detail_analysis_page.dart';
import 'employee_operations_list_page.dart';

class _CategoryData {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _CategoryData(this.title, this.icon, this.color, this.count, this.onTap);
}

/// قسم "الموظفون" داخل مركز التحليل — قراءة فقط بالكامل، بيانات حقيقية من
/// نفس مصادر شاشات الموظفين الأصلية (لا تعديل ولا حذف من هنا).
class EmployeesAnalysisPage extends StatefulWidget {
  final Hotel hotel;
  const EmployeesAnalysisPage({super.key, required this.hotel});

  @override
  State<EmployeesAnalysisPage> createState() => _EmployeesAnalysisPageState();
}

class _EmployeesAnalysisPageState extends State<EmployeesAnalysisPage> {
  final _repo = EmployeeRepository();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Hotel> _allHotels = [];
  Set<int> _selectedHotelIds = {};
  List<Employee> _employees = [];
  List<Map<String, dynamic>> _advances = [];
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _allowances = [];
  List<Map<String, dynamic>> _transferEvents = [];
  String _search = "";

  @override
  void initState() {
    super.initState();
    _selectedHotelIds = widget.hotel.id != null ? {widget.hotel.id!} : {};
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _allHotels = await HotelRepository().getAllHotels();
    final hotelIds = _selectedHotelIds.toList();

    final employees = <Employee>[];
    final advances = <Map<String, dynamic>>[];
    final deductions = <Map<String, dynamic>>[];
    final allowances = <Map<String, dynamic>>[];
    final transfers = <Map<String, dynamic>>[];
    for (final id in hotelIds) {
      employees.addAll(await _repo.getEmployees(id));
      advances.addAll(await _repo.getAdvancesForHotel(id));
      deductions.addAll(await _repo.getDeductionsForHotel(id));
      allowances.addAll(await _repo.getAllowancesForHotel(id));
      transfers.addAll(await _repo.getEventsForHotel(id, eventType: 'transfer'));
    }

    if (!mounted) return;
    setState(() {
      _employees = employees;
      _advances = advances;
      _deductions = deductions;
      _allowances = allowances;
      _transferEvents = transfers;
      _isLoading = false;
    });
  }

  Color get _identityColor {
    if (_selectedHotelIds.length == 1) {
      final h = _allHotels.firstWhere((h) => h.id == _selectedHotelIds.first, orElse: () => widget.hotel);
      return HotelVisualIdentity.colorForHotel(h);
    }
    return AppColors.primary;
  }

  Hotel _hotelFor(int? id) => _allHotels.firstWhere((h) => h.id == id, orElse: () => widget.hotel);

  List<Employee> get _filteredEmployees {
    if (_search.isEmpty) return _employees;
    return _employees.where((e) => e.name.toLowerCase().contains(_search.toLowerCase()) || (e.employeeNumber ?? '').contains(_search)).toList();
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
                      style: ElevatedButton.styleFrom(backgroundColor: _identityColor, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
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
      await _load();
    }
  }

  void _openOperationsList(String title, List<Map<String, dynamic>> rows, Color color, {required String amountKey, required String subtitleFallback, String dateKey = 'date'}) {
    final items = rows
        .map((r) => EmployeeOperationItem(
              employeeName: r['employee_name'] as String? ?? 'غير معروف',
              title: title,
              subtitle: (r['name'] as String?) ?? (r['reason'] as String?) ?? subtitleFallback,
              amount: (r[amountKey] as num?)?.toDouble(),
              date: (r[dateKey] as String?)?.split('T').first ?? '',
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeOperationsListPage(hotel: widget.hotel, title: title, items: items, color: color)));
  }

  @override
  Widget build(BuildContext context) {
    final color = _identityColor;
    final suspendedCount = _employees.where((e) => e.status == Employee.statusSuspended).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: color,
        elevation: 0,
        title: const Text("الموظفون", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                InkWell(
                  onTap: _openHotelSelector,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: color.withOpacity(0.25))),
                    child: Row(children: [Icon(Icons.apartment, color: color, size: 20), const SizedBox(width: 10), Expanded(child: Text(_selectedHotelIds.length == _allHotels.length ? "جميع الفنادق" : "${_selectedHotelIds.length} فندق مختار", style: AppTextStyles.bodyBold.copyWith(fontSize: 13))), Icon(Icons.expand_more, color: color)]),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.trim()),
                  decoration: InputDecoration(
                    hintText: "بحث باسم الموظف أو رقمه الوظيفي...",
                    hintStyle: AppTextStyles.caption,
                    prefixIcon: Icon(Icons.search, color: color),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color.withOpacity(0.2))),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                _buildCategoryGrid(color, suspendedCount),
                const SizedBox(height: AppSizes.lg),
                Text("جميع الموظفين (${_filteredEmployees.length})", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSizes.sm),
                if (_filteredEmployees.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("لا يوجد موظفون مطابقون", style: TextStyle(color: Colors.grey))))
                else
                  ..._filteredEmployees.map((e) => _buildEmployeeRow(e, color)),
              ],
            ),
    );
  }

  Widget _buildCategoryGrid(Color color, int suspendedCount) {
    final categories = [
      _CategoryData("جميع الموظفين", Icons.people_outline, color, _employees.length, () {}),
      _CategoryData("السلف", Icons.request_quote_outlined, const Color(0xFF3B6FE0), _advances.length, () => _openOperationsList("السلف", _advances, const Color(0xFF3B6FE0), amountKey: 'amount', subtitleFallback: 'سلفة')),
      _CategoryData("الخصومات", Icons.remove_circle_outline, AppColors.danger, _deductions.length, () => _openOperationsList("الخصومات", _deductions, AppColors.danger, amountKey: 'amount', subtitleFallback: 'خصم')),
      _CategoryData("البدلات", Icons.add_card_outlined, AppColors.success, _allowances.length, () => _openOperationsList("البدلات", _allowances, AppColors.success, amountKey: 'amount', subtitleFallback: 'بدل')),
      _CategoryData("الإيقاف", Icons.pause_circle_outlined, AppColors.warning, suspendedCount, () {
        final items = _employees.where((e) => e.status == Employee.statusSuspended).toList();
        Navigator.push(context, MaterialPageRoute(builder: (_) => _EmployeeListSubPage(hotel: widget.hotel, title: "الموظفون الموقوفون", employees: items, color: AppColors.warning, hotelFor: _hotelFor)));
      }),
      _CategoryData("النقل بين المنشآت", Icons.swap_horiz_outlined, const Color(0xFF6366F1), _transferEvents.length, () => _openOperationsList("النقل بين المنشآت", _transferEvents, const Color(0xFF6366F1), amountKey: 'none', subtitleFallback: 'نقل', dateKey: 'event_date')),
    ];
    final rows = <Widget>[];
    for (int i = 0; i < categories.length; i += 2) {
      final second = i + 1 < categories.length ? categories[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _buildCategoryCard(categories[i])),
          const SizedBox(width: 12),
          Expanded(child: second != null ? _buildCategoryCard(second) : const SizedBox()),
        ]),
      ));
      if (i + 2 < categories.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _buildCategoryCard(_CategoryData c) {
    return AppCard(
      onTap: c.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(c.icon, color: c.color, size: 18)),
          const SizedBox(height: 12),
          Text("${c.count}", style: AppTextStyles.title.copyWith(fontSize: 22, color: c.color)),
          const SizedBox(height: 2),
          Text(c.title, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(Employee e, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.badge_outlined, color: color, size: 18)),
        title: Text(e.name, style: AppTextStyles.bodyBold),
        subtitle: Text("${e.position} · ${Employee.statusLabel(e.status)}", style: AppTextStyles.caption),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetailAnalysisPage(hotel: _hotelFor(e.hotelId), employee: e, color: color)));
        },
      ),
    );
  }
}

class _EmployeeListSubPage extends StatelessWidget {
  final Hotel hotel;
  final String title;
  final List<Employee> employees;
  final Color color;
  final Hotel Function(int?) hotelFor;
  const _EmployeeListSubPage({required this.hotel, required this.title, required this.employees, required this.color, required this.hotelFor});

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title, style: const TextStyle(color: Colors.white)), centerTitle: true, backgroundColor: identityColor, elevation: 0),
      body: employees.isEmpty
          ? const Center(child: Text("لا يوجد موظفون", style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: employees
                  .map((e) => Card(
                        margin: const EdgeInsets.only(bottom: AppSizes.sm),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: ListTile(
                          leading: Icon(Icons.badge_outlined, color: color),
                          title: Text(e.name, style: AppTextStyles.bodyBold),
                          subtitle: Text(e.position, style: AppTextStyles.caption),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetailAnalysisPage(hotel: hotelFor(e.hotelId), employee: e, color: color))),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
