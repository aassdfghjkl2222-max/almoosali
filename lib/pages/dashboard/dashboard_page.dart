import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/hotel_identity.dart';
import '../../models/hotel.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../expenses/pending_expenses_list_page.dart';
import '../vault/vault_dashboard_page.dart';
import 'pages/documents_page.dart';
import 'pages/more_modules_page.dart';
import '../employees/employees_page.dart';
import '../financial/financial_summary_page.dart';
import 'widgets/module_card.dart';

class DashboardPage extends StatefulWidget {
  final Hotel hotel;
  const DashboardPage({super.key, required this.hotel});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _expenseRepository = ExpenseRepository();
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final expenses = await _expenseRepository.getPendingExpenses(
      hotelId: widget.hotel.id!,
      isTransferred: false,
    );
    if (mounted) {
      setState(() {
        _pendingCount = expenses.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = HotelVisualIdentity.identityForHotel(widget.hotel);
    
    return Theme(
      data: AppTheme.createTheme(identity),
      child: Scaffold(
        appBar: AppBar(
          title: HotelIdentityTitle(title: "لوحة التحكم", hotel: widget.hotel),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              label: const Text(
                "تغيير الفندق",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        drawer: AppDrawer(hotel: widget.hotel),
        body: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            ModuleCard(
              title: "التقرير المالي",
              icon: Icons.account_balance,
              iconColor: identity.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FinancialSummaryPage(hotel: widget.hotel),
                  ),
                );
              },
            ),
            ModuleCard(
              title: "المصروفات المعلقة",
              icon: Icons.pending_actions,
              badgeCount: _pendingCount,
              backgroundColor: _pendingCount > 0 ? identity.warning : null,
              iconColor: _pendingCount > 0 ? Colors.white : null,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PendingExpensesListPage(hotel: widget.hotel),
                  ),
                );
                if (result == true) {
                  _loadPendingCount();
                }
              },
            ),
            ModuleCard(
              title: "المركز المالي",
              icon: Icons.account_balance_wallet,
              iconColor: identity.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VaultDashboardPage(hotel: widget.hotel),
                  ),
                );
              },
            ),
            ModuleCard(
              title: "المستندات",
              icon: Icons.description,
              iconColor: identity.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentsPage(hotel: widget.hotel),
                  ),
                );
              },
            ),
            ModuleCard(
              title: "الموظفون",
              icon: Icons.people,
              iconColor: identity.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmployeesPage(hotel: widget.hotel),
                  ),
                );
              },
            ),
            ModuleCard(
              title: "الموردون",
              icon: Icons.local_shipping,
              iconColor: identity.primary,
              onTap: () {},
            ),
            ModuleCard(
              title: "الحركة السنوية",
              icon: Icons.analytics,
              iconColor: identity.primary,
              onTap: () {},
            ),
            ModuleCard(
              title: "➕ المزيد",
              icon: Icons.add_circle_outline,
              iconColor: Colors.grey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MoreModulesPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}