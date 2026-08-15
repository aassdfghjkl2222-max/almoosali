import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/app_radius.dart';
import '../../../models/hotel.dart';
import '../../../models/deposited_fund.dart';
import '../../../repositories/vault_repository.dart';
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

  /// إجراءا الترحيل الوحيدان الظاهران للمستخدم الآن (راجع البند 4 من متطلبات
  /// إعادة تصميم سير العمل المالي): "ترحيل التقرير" = كل شيء في التقرير ما
  /// عدا صافي النقد (VaultRepository.postReportComponents)، و"ترحيل صافي
  /// النقد" = صافي النقد فقط (VaultRepository.transferCashToVault). مستقلان
  /// تماماً — لا أحدهما ينتظر الآخر ولا يكرِّر عمل الآخر.
  Future<void> _confirmAndPost({
    required DepositedFund fund,
    required String type, // 'report' or 'cash'
  }) async {
    final List<ReviewItem> reviewItems = [
      ReviewItem(label: "تاريخ التقرير", value: fund.date),
      if (type == 'report')
        ReviewItem(label: "ترحيل التقرير (الشبكة + المصروفات الخاصة)", value: "${_format(fund.networkAmount)} ريال", color: Colors.purple)
      else
        ReviewItem(label: "ترحيل صافي النقد", value: "${_format(fund.cashAmount)} ريال", color: Colors.green),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: type == 'report' ? "تأكيد ترحيل التقرير" : "تأكيد ترحيل صافي النقد",
          items: reviewItems,
          confirmLabel: "ترحيل الآن",
          onConfirm: () async {
            if (type == 'report') {
              await _vaultRepository.postReportComponents(fund);
            } else {
              await _vaultRepository.transferCashToVault(fund);
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
    bool reportPending = fund.reportStatus == 'pending';
    bool cashPending = fund.cashStatus == 'pending';

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
                child: const Text("معتمد — بانتظار الترحيل", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 32),
          // حالتان مستقلتان تماماً (راجع البند 4 من متطلبات إعادة تصميم سير
          // العمل المالي) — لا مؤشر ثالث مجمَّع بينهما حتى لا يوحي بترابط.
          Row(
            children: [
              _buildStatusInfo("📋 التقرير", reportPending, "بانتظار الترحيل", "تم ترحيل التقرير"),
              _buildStatusInfo("💵 صافي النقد", cashPending, "بانتظار الترحيل", "تم ترحيل صافي النقد"),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              _buildAmountInfo("الشبكة + المصروفات الخاصة", fund.networkAmount, reportPending ? Colors.orange : Colors.green),
              _buildAmountInfo("صافي النقد", fund.cashAmount, cashPending ? Colors.orange : Colors.green),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          _buildActionButtons(fund, reportPending, cashPending),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(String label, bool isPending, String pendingLabel, String postedLabel) {
    final color = isPending ? Colors.orange : Colors.green;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(
            isPending ? "⌛ $pendingLabel" : "✔ $postedLabel",
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInfo(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(_format(amount), style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 18)),
        ],
      ),
    );
  }

  /// إجراءا الترحيل الوحيدان الظاهران — بلا أي خيار ترحيل جزئي/بديل آخر
  /// (راجع البند 4 من متطلبات إعادة تصميم سير العمل المالي: "لا أزرار ترحيل
  /// منفصلة زائدة عن الحاجة").
  Widget _buildActionButtons(DepositedFund fund, bool reportPending, bool cashPending) {
    return Row(
      children: [
        Expanded(
          child: _postBtn(
            reportPending ? "📋 ترحيل التقرير" : "✔ تم ترحيل التقرير",
            Icons.assignment_turned_in_outlined,
            Colors.purple,
            reportPending ? () => _confirmAndPost(fund: fund, type: 'report') : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _postBtn(
            cashPending ? "💵 ترحيل صافي النقد" : "✔ تم ترحيل صافي النقد",
            Icons.money,
            Colors.green,
            cashPending ? () => _confirmAndPost(fund: fund, type: 'cash') : null,
          ),
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
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: isDisabled ? Colors.grey : color, fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
          const Text("تم ترحيل كافة التقارير المالية المعتمدة إلى الخزنة", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
