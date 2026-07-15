import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';
import '../../../models/financial_account.dart';
import '../../../repositories/hotel_repository.dart';
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

/// رصيد فندق زميل ضمن علاقة مالية بين المنشآت (مستحق أو التزام).
class _EntityBalance {
  final int? otherHotelId;
  final String hotelName;
  final double balance;
  final String category;

  _EntityBalance({required this.otherHotelId, required this.hotelName, required this.balance, required this.category});
}

class _FinancialRelationshipsPageState extends State<FinancialRelationshipsPage> with SingleTickerProviderStateMixin {
  final _engine = FinancialEngine();
  late TabController _tabController;
  bool _isLoading = true;

  // تفصيل حسب كل منشأة زميلة (الطبقة التنظيمية الجديدة).
  List<_EntityBalance> _receivableEntities = [];
  List<_EntityBalance> _payableEntities = [];

  // بقية الحسابات (أشخاص/موردون/عملاء) — تبقى كما هي دون تغيير.
  List<FinancialAccount> _otherReceivables = [];
  List<FinancialAccount> _otherPayables = [];

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

  bool _isEntityCategory(String cat) =>
      cat.startsWith('entity_') || cat.startsWith('receivable_entity_') || cat == 'entity' || cat == 'receivable_entity';

  List<_EntityBalance> _extractEntities(List<FinancialAccount> accounts, String prefix, String legacyCategory, Map<int, String> hotelNames) {
    final list = <_EntityBalance>[];
    for (final acc in accounts) {
      if (acc.category.startsWith(prefix)) {
        final id = int.tryParse(acc.category.substring(prefix.length));
        if (id != null) {
          list.add(_EntityBalance(otherHotelId: id, hotelName: hotelNames[id] ?? 'منشأة محذوفة', balance: acc.balance, category: acc.category));
        }
      } else if (acc.category == legacyCategory && acc.balance != 0) {
        // رصيد سابق لم يكن مرتبطاً بمنشأة محددة (قبل تفعيل التصنيف حسب كل منشأة).
        list.add(_EntityBalance(otherHotelId: null, hotelName: 'غير محدد (رصيد سابق)', balance: acc.balance, category: acc.category));
      }
    }
    list.sort((a, b) => b.balance.compareTo(a.balance));
    return list;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final allAssets = await _engine.getAccountsByType(widget.hotel.id!, 'asset');
    final allLiabilities = await _engine.getAccountsByType(widget.hotel.id!, 'liability');
    final hotels = await HotelRepository().getAllHotels();
    final hotelNames = {for (final h in hotels) if (h.id != null) h.id!: h.arabicName};

    _receivableEntities = _extractEntities(allAssets, 'receivable_entity_', 'receivable_entity', hotelNames);
    _payableEntities = _extractEntities(allLiabilities, 'entity_', 'entity', hotelNames);

    _otherReceivables = allAssets.where((a) => !_isEntityCategory(a.category)).toList();
    _otherPayables = allLiabilities.where((a) => !_isEntityCategory(a.category)).toList();

    _totalReceivables = allAssets.fold(0.0, (sum, item) => sum + item.balance);
    _totalPayables = allLiabilities.fold(0.0, (sum, item) => sum + item.balance);

    if (mounted) setState(() => _isLoading = false);
  }

  String _format(double amount) => NumberFormat("#,##0.##").format(amount);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              _buildList(_receivableEntities, _otherReceivables, _totalReceivables, Colors.green, "لا توجد مستحقات حالياً"),
              _buildList(_payableEntities, _otherPayables, _totalPayables, AppColors.danger, "لا توجد التزامات حالياً"),
            ],
          ),
    );
  }

  Widget _buildList(List<_EntityBalance> entities, List<FinancialAccount> otherAccounts, double total, Color color, String emptyMsg) {
    final hasAny = entities.isNotEmpty || otherAccounts.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _buildTotalSummaryCard(total, color),
        const SizedBox(height: AppSizes.lg),
        if (!hasAny)
          Center(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
          ))
        else ...[
          if (entities.isNotEmpty) ...[
            Text("🏨 الفنادق الزميلة", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            ...entities.map((e) => _buildEntityItem(e, color)),
          ],
          if (entities.isNotEmpty && otherAccounts.isNotEmpty) const SizedBox(height: AppSizes.lg),
          if (otherAccounts.isNotEmpty) ...[
            Text("👥 حسابات أخرى", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            ...otherAccounts.map((acc) => _buildAccountItem(acc, color)),
          ],
        ],
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

  Widget _buildEntityItem(_EntityBalance e, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.apartment_outlined, color: color, size: 20),
        ),
        title: Text(e.hotelName, style: AppTextStyles.bodyBold),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_format(e.balance), style: AppTextStyles.bodyBold.copyWith(color: color)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => LedgerPage(
            hotel: widget.hotel,
            category: e.category,
            title: e.hotelName,
          )));
        },
      ),
    );
  }

  Widget _buildAccountItem(FinancialAccount acc, Color color) {
    IconData icon = Icons.account_circle_outlined;
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
    'supplier': 'مورد (آجل)',
    'client': 'عميل',
  };
}
