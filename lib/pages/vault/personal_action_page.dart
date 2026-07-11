import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../models/financial_account.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../../../widgets/app_button.dart';
import '../common/transaction_review_page.dart';

class PersonalActionPage extends StatefulWidget {
  final Hotel hotel;
  final FinancialAccount account;
  final String action; // 'withdraw' or 'deposit'

  const PersonalActionPage({
    super.key,
    required this.hotel,
    required this.account,
    required this.action,
  });

  @override
  State<PersonalActionPage> createState() => _PersonalActionPageState();
}

class _PersonalActionPageState extends State<PersonalActionPage> {
  final _financialEngine = FinancialEngine();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _source = 'cash'; // 'cash' or 'bank'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descController.text = widget.action == 'withdraw' 
        ? "سحب شخصي - ${widget.account.name}" 
        : "إيداع شخصي - ${widget.account.name}";
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    final isWithdraw = widget.action == 'withdraw';
    final actionName = isWithdraw ? "سحب" : "إيداع";
    final sourceName = _source == 'cash' ? 'نقد (الخزنة)' : 'الحساب البنكي';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: "مراجعة عملية ال$actionName",
          items: [
            ReviewItem(label: "الحساب", value: widget.account.name),
            ReviewItem(label: "نوع العملية", value: actionName, color: isWithdraw ? Colors.red : Colors.green),
            ReviewItem(label: "المبلغ", value: "${NumberFormat("#,##0.##").format(amount)} ريال", color: isWithdraw ? Colors.red : Colors.green),
            ReviewItem(label: "المصدر/الوجهة", value: sourceName),
            ReviewItem(label: "البيان", value: _descController.text),
          ],
          onConfirm: () async {
            await _financialEngine.recordPersonalAction(
              hotelId: widget.hotel.id!,
              personCategory: widget.account.category,
              amount: amount,
              action: widget.action,
              source: _source,
              description: _descController.text,
            );
            if (mounted) {
              Navigator.pop(context); // Close Review
              Navigator.pop(context, true); // Close Action Page
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    final isWithdraw = widget.action == 'withdraw';
    final actionColor = isWithdraw ? AppColors.danger : Colors.green;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: isWithdraw ? "سحب أموال" : "إيداع أموال", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          AppCard(
            child: Column(
              children: [
                Text(widget.account.name, style: AppTextStyles.bodyBold),
                Text("الرصيد الحالي: ${NumberFormat("#,##0.##").format(widget.account.balance)}", style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text(isWithdraw ? "تفاصيل السحب" : "تفاصيل الإيداع", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _amountController,
            hint: "المبلغ",
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
          Text(isWithdraw ? "يخصم من" : "يضاف إلى", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          _buildSourceToggle(),
          const SizedBox(height: AppSizes.xl),
          AppButton(
            text: isWithdraw ? "تأكيد السحب" : "تأكيد الإيداع",
            onPressed: _submit,
            isLoading: _isLoading,
            backgroundColor: actionColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceToggle() {
    return Row(
      children: [
        Expanded(child: _buildSourceItem("نقد (الخزنة)", 'cash', Icons.money)),
        const SizedBox(width: AppSizes.md),
        Expanded(child: _buildSourceItem("الحساب البنكي", 'bank', Icons.account_balance)),
      ],
    );
  }

  Widget _buildSourceItem(String label, String id, IconData icon) {
    final isSelected = _source == id;
    final color = id == 'cash' ? Colors.green : Colors.blue;
    return InkWell(
      onTap: () => setState(() => _source = id),
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
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
