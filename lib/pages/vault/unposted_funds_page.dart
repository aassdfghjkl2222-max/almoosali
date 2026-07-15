import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/app_radius.dart';
import '../../../models/hotel.dart';
import '../../../models/deposited_fund.dart';
import '../../../repositories/vault_repository.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../common/transaction_review_page.dart';

class UnpostedFundsPage extends StatefulWidget {
  final Hotel hotel;
  const UnpostedFundsPage({super.key, required this.hotel});

  @override
  State<UnpostedFundsPage> createState() => _UnpostedFundsPageState();
}

class _UnpostedFundsPageState extends State<UnpostedFundsPage> {
  final _vaultRepository = VaultRepository();
  final _engine = FinancialEngine();
  List<DepositedFund> _funds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _vaultRepository.getDepositedFunds(hotelId: widget.hotel.id!, isArchived: false);
    if (mounted) setState(() {
      _funds = data;
      _isLoading = false;
    });
  }

  String _format(double val) => NumberFormat("#,##0.##").format(val);

  Future<void> _confirmAndPost({
    required DepositedFund fund,
    required String type, // 'cash', 'bank', 'all'
    required double amount,
  }) async {
    final List<ReviewItem> reviewItems = [
      ReviewItem(label: "تاريخ التقرير", value: fund.date),
    ];

    if (type == 'cash' || type == 'all') {
      if (fund.cashStatus == 'pending') {
        reviewItems.add(ReviewItem(label: "ترحيل للنقد", value: "${_format(fund.cashAmount)} ريال", color: Colors.green));
      }
    }
    if (type == 'bank' || type == 'all') {
      if (fund.networkStatus == 'pending') {
        reviewItems.add(ReviewItem(label: "ترحيل للبنك", value: "${_format(fund.networkAmount)} ريال", color: Colors.purple));
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: "تأكيد عملية الترحيل",
          items: reviewItems,
          confirmLabel: "ترحيل الآن",
          onConfirm: () async {
            if (type == 'cash' || type == 'all') {
              await _vaultRepository.transferCashToVault(fund);
            }
            if (type == 'bank' || type == 'all') {
              await _vaultRepository.transferNetworkToBank(fund);
            }
            if (mounted) {
              Navigator.pop(context); // Close Review
              await _loadData();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الترحيل بنجاح")));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "الأموال غير المرحلة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _funds.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _funds.length,
                  itemBuilder: (context, index) => _buildFundCard(_funds[index], identityColor),
                ),
    );
  }

  Widget _buildFundCard(DepositedFund fund, Color identityColor) {
    bool cashPending = fund.cashStatus == 'pending';
    bool bankPending = fund.networkStatus == 'pending';

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      identityAccent: identityColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("تقرير مالي بتاريخ", style: AppTextStyles.caption),
                  Text(fund.date, style: AppTextStyles.bodyBold.copyWith(fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Text("بانتظار الاعتماد", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              _buildAmountInfo("💵 صافي النقد", fund.cashAmount, cashPending ? Colors.orange : Colors.green, !cashPending),
              _buildAmountInfo("🏦 صافي البنك", fund.networkAmount, bankPending ? Colors.orange : Colors.green, !bankPending),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          _buildActionButtons(fund, cashPending, bankPending),
        ],
      ),
    );
  }

  Widget _buildAmountInfo(String label, double amount, Color color, bool isPosted) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(_format(amount), style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 18)),
          if (isPosted)
            const Text("✔ تم الترحيل", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))
          else
            const Text("⌛ معلق", style: TextStyle(color: Colors.orange, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DepositedFund fund, bool cashPending, bool bankPending) {
    return Column(
      children: [
        _postBtn(
          "ترحيل الجميع", 
          Icons.done_all, 
          Colors.green, 
          (cashPending || bankPending) ? () => _confirmAndPost(fund: fund, type: 'all', amount: 0) : null
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _postBtn(
                cashPending ? "ترحيل النقد" : "✔ تم ترحيل النقد", 
                Icons.money, 
                Colors.blue, 
                cashPending ? () => _confirmAndPost(fund: fund, type: 'cash', amount: fund.cashAmount) : null
              )
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _postBtn(
                bankPending ? "ترحيل البنك" : "✔ تم ترحيل البنك", 
                Icons.account_balance, 
                Colors.purple, 
                bankPending ? () => _confirmAndPost(fund: fund, type: 'bank', amount: fund.networkAmount) : null
              )
            ),
          ],
        ),
      ],
    );
  }

  Widget _postBtn(String label, IconData icon, Color color, VoidCallback? onTap) {
    bool isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isDisabled ? Colors.grey.withOpacity(0.3) : color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isDisabled ? Colors.grey : color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isDisabled ? Colors.grey : color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("لا توجد مبالغ بانتظار الترحيل", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const Text("تم اعتماد كافة التقارير المالية", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
