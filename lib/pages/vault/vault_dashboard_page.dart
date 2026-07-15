import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';
import '../../../repositories/financial_repository.dart';
import '../../../repositories/vault_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_drawer.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../../../services/financial_engine.dart';
import 'unposted_funds_page.dart';
import 'financial_relationships_page.dart';
import 'personal_accounts_page.dart';
import 'inter_entity_debts_page.dart';
import 'vault_transactions_page.dart';
import 'ledger_page.dart';

class VaultDashboardPage extends StatefulWidget {
  final Hotel hotel;
  const VaultDashboardPage({super.key, required this.hotel});

  @override
  State<VaultDashboardPage> createState() => _VaultDashboardPageState();
}

class _VaultDashboardPageState extends State<VaultDashboardPage> {
  final _engine = FinancialEngine();
  final _financialRepository = FinancialRepository();
  final _vaultRepository = VaultRepository();
  bool _isLoading = true;
  
  double _cash = 0;
  double _bank = 0;
  double _receivable = 0;
  double _payable = 0;
  int _unpostedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _cash = await _engine.getBalance(widget.hotel.id!, 'cash');
    _bank = await _engine.getBalance(widget.hotel.id!, 'bank');
    _payable = await _engine.getTotalLiability(widget.hotel.id!);
    _receivable = await _engine.getTotalReceivable(widget.hotel.id!);
    
    // توحيد مصدر البيانات: جلب القائمة غير المرحلة ثم عدها
    final unpostedFunds = await _vaultRepository.getDepositedFunds(
      hotelId: widget.hotel.id!, 
      isArchived: false
    );
    _unpostedCount = unpostedFunds.length;

    if (mounted) setState(() => _isLoading = false);
  }

  String _format(double val) => NumberFormat("#,##0.##").format(val);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    final netAssets = _cash + _bank;
    final trueNet = (_cash + _bank + _receivable) - _payable;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "المركز المالي", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildRealNetCards(netAssets, trueNet),
                const SizedBox(height: AppSizes.md),
                _buildFinancialSummaryGrid(identityColor),
                const SizedBox(height: AppSizes.lg),
                _buildMainSections(identityColor),
                const SizedBox(height: AppSizes.xl),
              ],
            ),
      ),
    );
  }

  Widget _buildRealNetCards(double netAssets, double trueNet) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            color: Colors.blue.shade900,
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              children: [
                const Text("صافي الأصول", style: TextStyle(color: Colors.white70, fontSize: 11)),
                const Text("(نقد + بنك)", style: TextStyle(color: Colors.white54, fontSize: 9)),
                const SizedBox(height: 4),
                FittedBox(child: Text(_format(netAssets), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: AppCard(
            color: trueNet >= 0 ? Colors.teal.shade800 : Colors.red.shade900,
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              children: [
                const Text("المركز المالي الحقيقي", style: TextStyle(color: Colors.white70, fontSize: 11)),
                const Text("(الأصول - الالتزامات)", style: TextStyle(color: Colors.white54, fontSize: 9)),
                const SizedBox(height: 4),
                FittedBox(child: Text(_format(trueNet), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummaryGrid(Color identityColor) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryItem("💵 النقد", _cash, Colors.green, 'cash'),
              _buildDivider(),
              _buildSummaryItem("🏦 البنك", _bank, Colors.blue, 'bank'),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _buildSummaryItem("🟢 للمنشأة", _receivable, Colors.teal, 'receivable'),
              _buildDivider(),
              _buildSummaryItem("🔴 على المنشأة", _payable, AppColors.danger, 'payable'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double val, Color color, String type) {
    return Expanded(
      child: InkWell(
        onTap: () => _openStatement(type, label),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              _format(val),
              style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => Container(width: 1, height: 35, color: Colors.grey.withOpacity(0.2));

  void _openStatement(String type, String title) {
     if (type == 'receivable' || type == 'payable') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => FinancialRelationshipsPage(
          hotel: widget.hotel,
          initialType: type,
        ))).then((_) => _loadData());
     } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LedgerPage(
          hotel: widget.hotel, 
          category: type, 
          title: title
        ))).then((_) => _loadData());
     }
  }

  Widget _buildMainSections(Color identityColor) {
    return Column(
      children: [
        _buildMenuCard(
          title: "الأموال غير المرحلة",
          desc: "التقارير اليومية بانتظار الاعتماد",
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
          badgeCount: _unpostedCount,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnpostedFundsPage(hotel: widget.hotel))).then((_) => _loadData()),
        ),
        const SizedBox(height: AppSizes.md),
        _buildMenuCard(
          title: "ديون بين المنشآت",
          desc: "التحويلات والمصروفات المتبادلة",
          icon: Icons.business_outlined,
          color: Colors.deepOrange,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InterEntityDebtsPage(hotel: widget.hotel))).then((_) => _loadData()),
        ),
        const SizedBox(height: AppSizes.md),
        _buildMenuCard(
          title: "حسابات الأشخاص",
          desc: "المالك، الشركاء، والعهد الشخصية",
          icon: Icons.people_outline_rounded,
          color: Colors.purple,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalAccountsPage(hotel: widget.hotel))).then((_) => _loadData()),
        ),
        const SizedBox(height: AppSizes.md),
        _buildMenuCard(
          title: "الموردون (الآجل فقط)",
          desc: "مديونيات المشتريات والخدمات",
          icon: Icons.local_shipping_outlined,
          color: Colors.brown,
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => FinancialRelationshipsPage(
               hotel: widget.hotel,
               initialType: 'payable',
             ))).then((_) => _loadData());
          },
        ),
        const SizedBox(height: AppSizes.md),
        _buildMenuCard(
          title: "سجل الحركات",
          desc: "الأرشيف الكامل للعمليات المالية",
          icon: Icons.receipt_long_rounded,
          color: identityColor,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VaultTransactionsPage(hotel: widget.hotel))),
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                Text(desc, style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ],
            ),
          ),
          if (badgeCount != null && badgeCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}
