import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/contract.dart';
import '../../models/contract_payment.dart';
import '../../repositories/contract_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/app_text_field.dart';
import 'add_contract_page.dart';
import 'contract_details_page.dart';
import '../../models/hotel.dart';
import '../../widgets/common/hotel_identity_title.dart';

class ContractsPage extends StatefulWidget {
  final Hotel hotel;
  const ContractsPage({super.key, required this.hotel});

  @override
  State<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage> {
  final _repository = ContractRepository();
  final _searchController = TextEditingController();
  List<Contract> _allContracts = [];
  List<Contract> _filteredContracts = [];
  Map<int, List<ContractPayment>> _contractPayments = {};
  bool _isLoading = true;
  String _sortBy = 'الأحدث';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final contracts = await _repository.getAllContracts(widget.hotel.id!);
    final Map<int, List<ContractPayment>> paymentsMap = {};
    for (var contract in contracts) {
      if (contract.id != null) {
        paymentsMap[contract.id!] = await _repository.getContractPayments(contract.id!);
      }
    }
    setState(() {
      _allContracts = contracts;
      _contractPayments = paymentsMap;
      _filteredContracts = contracts;
      _isLoading = false;
      _applySearchAndSort();
    });
  }

  void _applySearchAndSort() {
    List<Contract> results = _allContracts.where((c) {
      final query = _searchController.text.toLowerCase();
      return c.name.toLowerCase().contains(query) || c.contractorName.toLowerCase().contains(query);
    }).toList();

    switch (_sortBy) {
      case 'الأحدث':
        results.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
      case 'الأقرب انتهاءً':
        results.sort((a, b) => a.endDate.compareTo(b.endDate));
        break;
      case 'الأقرب دفعة':
        results.sort((a, b) {
          final nextA = _getNearestPaymentDate(a.id);
          final nextB = _getNearestPaymentDate(b.id);
          return nextA.compareTo(nextB);
        });
        break;
      case 'الاسم':
        results.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    setState(() {
      _filteredContracts = results;
    });
  }

  String _getNearestPaymentDate(int? contractId) {
    if (contractId == null) return '9999-99-99';
    final payments = _contractPayments[contractId] ?? [];
    final duePayments = payments.where((p) => p.status == 'مستحقة' || p.status == 'متأخرة').toList();
    if (duePayments.isEmpty) return '9999-99-99';
    duePayments.sort((a, b) => a.date.compareTo(b.date));
    return duePayments.first.date;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "إدارة العقود", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummarySection(identityColor),
                _buildSearchAndFilterSection(identityColor),
                Expanded(
                  child: _filteredContracts.isEmpty
                      ? const Center(child: Text("لا توجد عقود حالياً"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSizes.md),
                          itemCount: _filteredContracts.length,
                          itemBuilder: (context, index) {
                            final contract = _filteredContracts[index];
                            return _buildContractCard(contract, identityColor);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddContractPage(hotel: widget.hotel)),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummarySection(Color identityColor) {
    double totalValue = 0;
    double collected = 0;
    int active = 0;
    int nearingEnd = 0;
    int expired = 0;

    for (var c in _allContracts) {
      totalValue += c.totalValue;
      if (c.status == 'ساري') active++;
      if (c.status == 'يقترب من الانتهاء') nearingEnd++;
      if (c.status == 'منتهي') expired++;

      final payments = _contractPayments[c.id] ?? [];
      for (var p in payments) {
        if (p.status == 'تم السداد') {
          collected += p.amount;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: identityColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.lg),
          bottomRight: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryItem("إجمالي العقود", "${_allContracts.length}", Icons.assignment_outlined),
              const SizedBox(width: AppSizes.sm),
              _buildSummaryItem("سارية", "$active", Icons.check_circle_outline, color: Colors.greenAccent),
              const SizedBox(width: AppSizes.sm),
              _buildSummaryItem("تقترب من الانتهاء", "$nearingEnd", Icons.history, color: Colors.orangeAccent),
              const SizedBox(width: AppSizes.sm),
              _buildSummaryItem("منتهية", "$expired", Icons.error_outline, color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              _buildFinancialItem("إجمالي القيمة", totalValue, Theme.of(context).colorScheme.secondary),
              const SizedBox(width: AppSizes.sm),
              _buildFinancialItem("المحصلة", collected, Colors.greenAccent),
              const SizedBox(width: AppSizes.sm),
              _buildFinancialItem("المتبقية", totalValue - collected, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, {Color color = Colors.white}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm, horizontal: AppSizes.xs),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialItem(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              NumberFormat("#,##0").format(amount),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection(Color identityColor) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _searchController,
              hint: "ابحث عن عقد أو متعاقد...",
              icon: Icons.search,
              onChanged: (_) => _applySearchAndSort(),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: identityColor),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _applySearchAndSort();
            },
            itemBuilder: (context) => [
              'الأحدث',
              'الأقرب انتهاءً',
              'الأقرب دفعة',
              'الاسم',
            ].map((choice) => PopupMenuItem(value: choice, child: Text(choice))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContractCard(Contract contract, Color identityColor) {
    final payments = _contractPayments[contract.id] ?? [];
    final totalPaid = payments.where((p) => p.status == 'تم السداد').length;
    final totalRemaining = payments.length - totalPaid;

    Color statusColor;
    switch (contract.status) {
      case 'ساري': statusColor = Colors.green; break;
      case 'يقترب من الانتهاء': statusColor = Colors.orange; break;
      case 'منتهي': statusColor = Colors.red; break;
      case 'مكتمل': statusColor = Colors.blue; break;
      default: statusColor = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: AppCard(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ContractDetailsPage(contract: contract, hotel: widget.hotel)),
          );
          if (result == true) _loadData();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    contract.name,
                    style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusBadge(contract.status, statusColor),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              "المتعاقد: ${contract.contractorName}",
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const Divider(height: AppSizes.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem("البداية", contract.startDate),
                _buildInfoItem("النهاية", contract.endDate),
                _buildInfoItem("القيمة", "${NumberFormat("#,##0").format(contract.totalValue)} ريال"),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat("الدفعات", "${payments.length}"),
                _buildMiniStat("مدفوعة", "$totalPaid", color: Colors.green),
                _buildMiniStat("متبقية", "$totalRemaining", color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? color}) {
    return Row(
      children: [
        Text("$label: ", style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 13)),
      ],
    );
  }
}
