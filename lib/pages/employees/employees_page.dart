import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_permissions.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/employee.dart';
import '../../models/hotel.dart';
import '../../repositories/employee_repository.dart';
import '../../services/payroll_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/permission_gate.dart';
import 'add_employee_page.dart';
import 'employee_archive_page.dart';
import 'employee_details_page.dart';
import 'employee_reports_page.dart';

class EmployeesPage extends StatefulWidget {
  final Hotel hotel;
  const EmployeesPage({super.key, required this.hotel});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final _repository = EmployeeRepository();
  final _payrollService = PayrollService();
  final _searchController = TextEditingController();
  late Future<List<Employee>> _employeesFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _employeesFuture = _repository.getEmployees(widget.hotel.id);
    });
  }

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: AppPermissions.employeesView,
      hotelId: widget.hotel.id,
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "الموظفون", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: "أرشيف الموظفين",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EmployeeArchivePage(hotel: widget.hotel)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: "تقارير الموظفين",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EmployeeReportsPage(hotel: widget.hotel)),
            ),
          ),
        ],
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: FutureBuilder<List<Employee>>(
              future: _employeesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoading();
                }

                var employees = snapshot.data ?? [];
                if (_query.trim().isNotEmpty) {
                  final q = _query.trim().toLowerCase();
                  employees = employees.where((e) => e.name.toLowerCase().contains(q) || e.position.toLowerCase().contains(q)).toList();
                }

                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          _query.trim().isEmpty ? "لا يوجد موظفون مضافون" : "لا توجد نتائج مطابقة",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.md),
                      child: _buildEmployeeCard(employee),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !PermissionService.instance.hasPermission(AppPermissions.employeesCreate, hotelId: widget.hotel.id)
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddEmployeePage(hotel: widget.hotel)),
                );
                if (result == true) _load();
              },
              backgroundColor: _identityColor,
              foregroundColor: Colors.white,
              child: const Icon(Icons.person_add),
            ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: "بحث بالاسم أو الوظيفة",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Employee employee) {
    return AppCard(
      identityAccent: _identityColor,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmployeeDetailsPage(hotel: widget.hotel, employee: employee)),
        );
        if (result == true) _load();
      },
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _identityColor.withOpacity(0.1),
            child: Icon(Icons.person, color: _identityColor),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name, style: AppTextStyles.bodyBold),
                Text(employee.position, style: AppTextStyles.caption),
                if (employee.employeeNumber != null)
                  Text(employee.employeeNumber!, style: AppTextStyles.caption.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                _buildStatusBadge(employee.status),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FutureBuilder(
                future: _payrollService.calculateBreakdown(employee),
                builder: (context, snapshot) {
                  final net = snapshot.data?.netSalary ?? employee.salary;
                  return Text(
                    "${NumberFormat("#,##0").format(net)} ر.س",
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.success),
                  );
                },
              ),
              const SizedBox(height: 4),
              Icon(Icons.chevron_left, color: _identityColor, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case Employee.statusSuspended:
        color = AppColors.warning;
        break;
      case Employee.statusResigned:
      case Employee.statusTerminated:
        color = AppColors.danger;
        break;
      default:
        color = AppColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(Employee.statusLabel(status), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
