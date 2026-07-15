import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';
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
  late TabController _tabController;
  bool _isLoading = true;
  double _payables = 0;
  double _receivables = 0;
  List<Map<String, dynamic>> _ledger = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _payables = await _engine.getBalance(widget.hotel.id!, 'entity');
    _receivables = await _engine.getBalance(widget.hotel.id!, 'receivable_entity');
    _ledger = await _engine.getLedger(widget.hotel.id!, 'entity');
    if (mounted) setState(() => _isLoading = false);
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
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _buildBalanceCard("ديون على المنشأة", _payables, Colors.deepOrange, "سداد الآن", identityColor, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SettleDebtPage(
            hotel: widget.hotel,
            debtCategory: 'entity',
            currentBalance: _payables,
          ))).then((_) => _loadData());
        }),
        const SizedBox(height: AppSizes.md),
        _buildBalanceCard("مستحقات للمنشأة", _receivables, Colors.blue, "عرض التفاصيل", identityColor, () {}),
      ],
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color, String btnLabel, Color identityColor, VoidCallback onTap) {
    return AppCard(
      identityAccent: identityColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.caption),
                  Text(_formatCurrency(amount), style: AppTextStyles.title.copyWith(color: color, fontSize: 24)),
                ],
              ),
              ElevatedButton(
                onPressed: amount > 0 ? onTap : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: Text(btnLabel),
              ),
            ],
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
