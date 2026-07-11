import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';
import '../../../models/financial_account.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import 'ledger_page.dart';

class FinancialRelationshipsPage extends StatefulWidget {
  final Hotel hotel;
  final String initialType; // 'receivable' or 'payable'

  const FinancialRelationshipsPage({
    super.key, 
    required this.hotel,
    required this.initialType,
  });

  @override
  State<FinancialRelationshipsPage> createState() => _FinancialRelationshipsPageState();
}

class _FinancialRelationshipsPageState extends State<FinancialRelationshipsPage> with SingleTickerProviderStateMixin {
  final _engine = FinancialEngine();
  late TabController _tabController;
  bool _isLoading = true;
  
  List<FinancialAccount> _receivables = [];
  List<FinancialAccount> _payables = [];
  
  double _totalReceivables = 0;
  double _totalPayables = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialType == 'receivable' ? 0 : 1
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _receivables = await _engine.getAccountsByType(widget.hotel.id!, 'asset');
    _payables = await _engine.getAccountsByType(widget.hotel.id!, 'liability');
    
    _totalReceivables = _receivables.fold(0, (sum, item) => sum + item.balance);
    _totalPayables = _payables.fold(0, (sum, item) => sum + item.balance);

    if (mounted) setState(() => _isLoading = false);
  }

  String _format(double amount) => NumberFormat("#,##0.##").format(amount);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "العلاقات المالية", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "🟢 للمنشأة (مستحقات)"),
            Tab(text: "🔴 على المنشأة (التزامات)"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildList(_receivables, _totalReceivables, Colors.green, "لا توجد مستحقات حالياً"),
              _buildList(_payables, _totalPayables, AppColors.danger, "لا توجد التزامات حالياً"),
            ],
          ),
    );
  }

  Widget _buildList(List<FinancialAccount> accounts, double total, Color color, String emptyMsg) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _buildTotalSummaryCard(total, color),
        const SizedBox(height: AppSizes.lg),
        if (accounts.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
          ))
        else
          ...accounts.map((acc) => _buildAccountItem(acc, color)),
      ],
    );
  }

  Widget _buildTotalSummaryCard(double total, Color color) {
    return AppCard(
      child: Column(
        children: [
          const Text("الإجمالي الكلي", style: AppTextStyles.caption),
          Text(
            _format(total),
            style: AppTextStyles.title.copyWith(fontSize: 28, color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(FinancialAccount acc, Color color) {
    IconData icon = Icons.account_circle_outlined;
    if (acc.category.contains('entity')) icon = Icons.apartment_outlined;
    if (acc.category.contains('supplier')) icon = Icons.local_shipping_outlined;
    if (acc.category.contains('client')) icon = Icons.group_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(acc.name, style: AppTextStyles.bodyBold),
        subtitle: Text(_getCategoryLabel(acc.category), style: AppTextStyles.caption),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_format(acc.balance), style: AppTextStyles.bodyBold.copyWith(color: color)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => LedgerPage(
            hotel: widget.hotel, 
            category: acc.category, 
            title: acc.name
          )));
        },
      ),
    );
  }

  String _getCategoryLabel(String cat) {
    if (accLabels.containsKey(cat)) return accLabels[cat]!;
    if (cat.startsWith('person_')) return "حساب شخصي";
    return "حساب مالي";
  }

  static const accLabels = {
    'personal': 'حساب المالك',
    'entity': 'منشأة زميلة (دين)',
    'receivable_entity': 'منشأة زميلة (مستحق)',
    'supplier': 'مورد (آجل)',
    'client': 'عميل',
  };
}
