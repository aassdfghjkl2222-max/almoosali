import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/advance_withdrawal.dart';
import '../../repositories/vault_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../common/transaction_review_page.dart';

/// "مسحوبات المالك" — الفندق يدفع مبلغاً للمالك (عكس "عهدة الفندق" تماماً):
/// نقص فوري في أصول الفندق (نقد/خزنة/شبكة) وزيادة في ذمة مستحقة على المالك
/// لصالح الفندق (راجع FinancialEngine.recordOwnerDrawing). بما أن الفندق هو
/// من يدفع فعلياً، يجب اختيار مصدر التمويل دائماً (بخلاف عهدة الفندق التي
/// لا تعرض أي اختيار لأن المالك هو المموِّل الثابت).
class AddOwnerWithdrawalPage extends StatefulWidget {
  final Hotel hotel;
  const AddOwnerWithdrawalPage({super.key, required this.hotel});

  @override
  State<AddOwnerWithdrawalPage> createState() => _AddOwnerWithdrawalPageState();
}

class _AddOwnerWithdrawalPageState extends State<AddOwnerWithdrawalPage> {
  final _repository = VaultRepository();
  final _formKey = GlobalKey<FormState>();
  final _statementController = TextEditingController();
  final _amountController = TextEditingController();
  String _fundingSource = 'نقد';

  @override
  void dispose() {
    _statementController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال مبلغ صحيح")));
      return;
    }

    final now = DateTime.now();
    final withdrawal = AdvanceWithdrawal(
      hotelId: widget.hotel.id!,
      amount: amount,
      statement: _statementController.text.trim(),
      method: _fundingSource,
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('HH:mm:ss').format(now),
      createdAt: now.toIso8601String(),
    );

    final reviewItems = [
      ReviewItem(label: "البيان", value: withdrawal.statement),
      ReviewItem(label: "المبلغ", value: "${NumberFormat("#,##0.##").format(withdrawal.amount)} ريال", color: AppColors.danger),
      ReviewItem(label: "مصدر التمويل", value: withdrawal.method, color: Colors.blue),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: "مراجعة مسحوبات المالك",
          items: reviewItems,
          onConfirm: () async {
            await _repository.addOwnerWithdrawal(withdrawal);
            if (mounted) {
              Navigator.pop(context); // Close Review
              Navigator.pop(context, true); // Close Add Page
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "إضافة مسحوب مالك", hotel: widget.hotel),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("تفاصيل المسحوب", style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    const Text("الفندق يدفع مبلغاً للمالك — تنقص أصول الفندق وتُنشأ ذمة مستحقة على المالك لصالح الفندق.", style: AppTextStyles.caption),
                    const SizedBox(height: AppSizes.md),
                    AppTextField(controller: _statementController, hint: "البيان", icon: Icons.description),
                    const SizedBox(height: AppSizes.md),
                    AppTextField(controller: _amountController, hint: "المبلغ", icon: Icons.attach_money, formatThousands: true),
                    const SizedBox(height: AppSizes.md),
                    const Text("مصدر التمويل", style: AppTextStyles.bodyBold),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: [
                        Expanded(child: _sourceChip('نقد', Icons.money)),
                        const SizedBox(width: 8),
                        Expanded(child: _sourceChip('الخزنة', Icons.lock_outline)),
                        const SizedBox(width: 8),
                        Expanded(child: _sourceChip('شبكة', Icons.credit_card)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xl),
              AppButton(text: "مراجعة وحفظ", onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceChip(String label, IconData icon) {
    final selected = _fundingSource == label;
    return ChoiceChip(
      label: Text(label, textAlign: TextAlign.center),
      avatar: Icon(icon, size: 16),
      selected: selected,
      onSelected: (_) => setState(() => _fundingSource = label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }
}
