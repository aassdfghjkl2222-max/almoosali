import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../../../widgets/app_button.dart';
import '../common/transaction_review_page.dart';

class SettleDebtPage extends StatefulWidget {
  final Hotel hotel;
  final String debtCategory; // 'personal' or 'entity'
  final double currentBalance;
  const SettleDebtPage({
    super.key,
    required this.hotel,
    required this.debtCategory,
    required this.currentBalance,
  });

  @override
  State<SettleDebtPage> createState() => _SettleDebtPageState();
}

class _SettleDebtPageState extends State<SettleDebtPage> {
  final _financialEngine = FinancialEngine();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _paymentSource = 'cash'; // 'cash' or 'bank'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = NumberFormat("#,##0.##").format(widget.currentBalance);
    _descController.text = widget.debtCategory == 'personal' ? "سداد للمالك" : "سداد فندق زميل";
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    final sourceName = _paymentSource == 'cash' ? 'نقد (الخزنة)' : 'الحساب البنكي';
    final categoryName = widget.debtCategory == 'personal' ? 'المالك' : 'فندق زميل';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: "مراجعة سداد المديونية",
          items: [
            ReviewItem(label: "الحساب المستحق", value: categoryName),
            ReviewItem(label: "المبلغ", value: "${NumberFormat("#,##0.##").format(amount)} ريال", color: Colors.green),
            ReviewItem(label: "مصدر السداد", value: sourceName),
            ReviewItem(label: "البيان", value: _descController.text),
          ],
          onConfirm: () async {
            await _financialEngine.settleDebt(
              hotelId: widget.hotel.id!,
              debtCategory: widget.debtCategory,
              amount: amount,
              paymentSource: _paymentSource,
              description: _descController.text,
            );
            if (mounted) {
              Navigator.pop(context); // Close Review
              Navigator.pop(context, true); // Close Settle Page
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
        title: HotelIdentityTitle(title: "سداد مديونية", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          AppCard(
            child: Column(
              children: [
                Text(
                  "الرصيد المستحق الحالي",
                  style: AppTextStyles.caption,
                ),
                Text(
                  "${NumberFormat("#,##0.##").format(widget.currentBalance)} ر.س",
                  style: AppTextStyles.title.copyWith(color: AppColors.danger, fontSize: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text("تفاصيل السداد", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _amountController,
            hint: "المبلغ المراد سداده",
            formatThousands: true,
            icon: Icons.attach_money,
          ),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _descController,
            hint: "البيان",
            icon: Icons.description,
          ),
          const SizedBox(height: AppSizes.lg),
          Text("مصدر السداد", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          _buildSourceToggle(),
          const SizedBox(height: AppSizes.xl),
          AppButton(
            text: "تأكيد السداد وتحديث الأرصدة",
            onPressed: _submit,
            isLoading: _isLoading,
            backgroundColor: identityColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceToggle() {
    return Row(
      children: [
        Expanded(
          child: _buildSourceItem("نقد (الخزنة)", 'cash', Icons.money),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: _buildSourceItem("الحساب البنكي", 'bank', Icons.account_balance),
        ),
      ],
    );
  }

  Widget _buildSourceItem(String label, String id, IconData icon) {
    final isSelected = _paymentSource == id;
    final color = id == 'cash' ? Colors.green : Colors.blue;
    return InkWell(
      onTap: () => setState(() => _paymentSource = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
