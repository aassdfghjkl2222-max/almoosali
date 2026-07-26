import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import 'settle_debt_page.dart';

class InterEntityDebtsPage extends StatefulWidget {
  final Hotel hotel;
  const InterEntityDebtsPage({super.key, required this.hotel});

  @override
  State<InterEntityDebtsPage> createState() => _InterEntityDebtsPageState();
}

class _InterEntityDebtsPageState extends State<InterEntityDebtsPage> with SingleTickerProviderStateMixin {
  final _engine = FinancialEngine();
  final _hotelRepository = HotelRepository();
  late TabController _tabController;
  bool _isLoading = true;
  List<Hotel> _allHotels = [];

  // كل بند التزام (ديون على المنشأة) بفئة entity_<otherHotelId> — مرتَّبة حسب المنشأة الأخرى.
  List<FinancialAccount> _payableAccounts = [];
  // كل بند أصل (مستحقات للمنشأة) بفئة receivable_entity_<otherHotelId>.
  List<FinancialAccount> _receivableAccounts = [];
  List<Map<String, dynamic>> _ledger = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  int? _otherHotelIdFromCategory(String category) {
    if (category.startsWith('receivable_entity_')) return int.tryParse(category.substring('receivable_entity_'.length));
    if (category.startsWith('entity_')) return int.tryParse(category.substring('entity_'.length));
    return null;
  }

  String _hotelName(int? id) {
    if (id == null) return "منشأة أخرى";
    return _allHotels.firstWhere((h) => h.id == id, orElse: () => Hotel(id: id, arabicName: "منشأة #$id", englishName: '', city: '')).arabicName;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final hotels = await _hotelRepository.getAllHotelsIncludingArchived();
    final liabilities = await _engine.getAccountsByType(widget.hotel.id!, 'liability');
    final assets = await _engine.getAccountsByType(widget.hotel.id!, 'asset');
    final payables = liabilities.where((a) => a.category.startsWith('entity_') && a.balance > 0).toList();
    final receivables = assets.where((a) => a.category.startsWith('receivable_entity_') && a.balance > 0).toList();

    final ledgerLists = await Future.wait([
      for (final a in [...payables, ...receivables]) _engine.getLedger(widget.hotel.id!, a.category),
    ]);
    final mergedLedger = ledgerLists.expand((l) => l).toList()
      ..sort((a, b) => "${b['date']} ${b['time']}".compareTo("${a['date']} ${a['time']}"));

    if (mounted) {
      setState(() {
        _allHotels = hotels;
        _payableAccounts = payables;
        _receivableAccounts = receivables;
        _ledger = mergedLedger;
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat("#,##0.##").format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "ديون المنشآت", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "الملخص والسداد"),
            Tab(text: "كشف الحساب"),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(identityColor),
              _buildTransactionsTab(identityColor),
            ],
          ),
    );
  }

  Widget _buildOverviewTab(Color identityColor) {
    if (_payableAccounts.isEmpty && _receivableAccounts.isEmpty) {
      return const Center(child: Text("لا توجد ذمم مع منشآت أخرى حالياً", style: AppTextStyles.caption));
    }
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        if (_payableAccounts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: AppSizes.sm),
            child: Text("ديون على المنشأة (يجب سدادها)", style: AppTextStyles.bodyBold),
          ),
          for (final account in _payableAccounts) ...[
            _buildCounterpartyCard(
              hotelName: _hotelName(_otherHotelIdFromCategory(account.category)),
              amount: account.balance,
              color: Colors.deepOrange,
              btnLabel: "سداد الآن",
              identityColor: identityColor,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SettleDebtPage(
                  hotel: widget.hotel,
                  debtCategory: account.category,
                  currentBalance: account.balance,
                ))).then((_) => _loadData());
              },
            ),
            const SizedBox(height: AppSizes.sm),
          ],
          const SizedBox(height: AppSizes.md),
        ],
        if (_receivableAccounts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: AppSizes.sm),
            child: Text("مستحقات للمنشأة (على منشآت أخرى)", style: AppTextStyles.bodyBold),
          ),
          for (final account in _receivableAccounts) ...[
            _buildCounterpartyCard(
              hotelName: _hotelName(_otherHotelIdFromCategory(account.category)),
              amount: account.balance,
              color: Colors.blue,
              btnLabel: null,
              identityColor: identityColor,
              onTap: null,
            ),
            const SizedBox(height: AppSizes.sm),
          ],
        ],
      ],
    );
  }

  Widget _buildCounterpartyCard({
    required String hotelName,
    required double amount,
    required Color color,
    required String? btnLabel,
    required Color identityColor,
    required VoidCallback? onTap,
  }) {
    return AppCard(
      identityAccent: identityColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hotelName, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_formatCurrency(amount), style: AppTextStyles.title.copyWith(color: color, fontSize: 22)),
              ],
            ),
          ),
          if (btnLabel != null)
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text(btnLabel),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(Color identityColor) {
    if (_ledger.isEmpty) return const Center(child: Text("لا توجد حركات مسجلة"));

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: _ledger.length,
      itemBuilder: (context, index) {
        final item = _ledger[index];
        final isCredit = item['type'] == 'credit'; // في حساب الالتزام: credit يعني زيادة الدين
        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSizes.sm),
          identityAccent: identityColor,
          child: Row(
            children: [
              Icon(
                isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                color: isCredit ? Colors.red : Colors.green,
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['description'], style: AppTextStyles.bodyBold),
                    Text("${item['date']} ${item['time']}", style: AppTextStyles.caption),
                  ],
                ),
              ),
              Text(
                _formatCurrency(item['amount']),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
