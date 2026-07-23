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

/// تحصيل ذمة أصل (receivable) لصالح المنشأة — عكس [SettleDebtPage] تماماً؛
/// هنا المنشأة تستلم مبلغاً (يزيد نقدها/شبكتها) لتخفيض ما يُدان لها به
/// (مثل "سلف المالك" owner_debt). راجع FinancialEngine.collectReceivable.
class CollectReceivablePage extends StatefulWidget {
  final Hotel hotel;
  final String receivableCategory;
  final String receivableLabel;
  final double currentBalance;
  const CollectReceivablePage({
    super.key,
    required this.hotel,
    required this.receivableCategory,
    required this.receivableLabel,
    required this.currentBalance,
  });

  @override
  State<CollectReceivablePage> createState() => _CollectReceivablePageState();
}

class _CollectReceivablePageState extends State<CollectReceivablePage> {
  final _financialEngine = FinancialEngine();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _depositTarget = 'cash'; // 'cash' or 'bank'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = NumberFormat("#,##0.##").format(widget.currentBalance);
    _descController.text = "تحصيل ${widget.receivableLabel}";
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    final targetName = _depositTarget == 'cash' ? 'نقد (الخزنة)' : 'الحساب البنكي';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: "مراجعة التحصيل",
          items: [
            ReviewItem(label: "الذمة", value: widget.receivableLabel),
            ReviewItem(label: "المبلغ", value: "${NumberFormat("#,##0.##").format(amount)} ريال", color: Colors.green),
            ReviewItem(label: "يُودَع في", value: targetName),
            ReviewItem(label: "البيان", value: _descController.text),
          ],
          onConfirm: () async {
            await _financialEngine.collectReceivable(
              hotelId: widget.hotel.id!,
              receivableCategory: widget.receivableCategory,
              amount: amount,
              depositTarget: _depositTarget,
              description: _descController.text,
            );
            if (mounted) {
              Navigator.pop(context); // Close Review
              Navigator.pop(context, true); // Close Collect Page
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
        title: HotelIdentityTitle(title: "تحصيل ذمة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          AppCard(
            child: Column(
              children: [
                Text(widget.receivableLabel, style: AppTextStyles.caption),
                Text(
                  "${NumberFormat("#,##0.##").format(widget.currentBalance)} ر.س",
                  style: AppTextStyles.title.copyWith(color: AppColors.success, fontSize: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text("تفاصيل التحصيل", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _amountController,
            hint: "المبلغ المُحصَّل",
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
          Text("يُودَع في", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          _buildTargetToggle(),
          const SizedBox(height: AppSizes.xl),
          AppButton(
            text: "تأكيد التحصيل وتحديث الأرصدة",
            onPressed: _submit,
            isLoading: _isLoading,
            backgroundColor: identityColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTargetToggle() {
    return Row(
      children: [
        Expanded(child: _buildTargetItem("نقد (الخزنة)", 'cash', Icons.money)),
        const SizedBox(width: AppSizes.md),
        Expanded(child: _buildTargetItem("الحساب البنكي", 'bank', Icons.account_balance)),
      ],
    );
  }

  Widget _buildTargetItem(String label, String id, IconData icon) {
    final isSelected = _depositTarget == id;
    final color = id == 'cash' ? Colors.green : Colors.blue;
    return InkWell(
      onTap: () => setState(() => _depositTarget = id),
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
