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

/// "مسحوبات المالك" (مسار قديم مُستبدَل) — الفندق يدفع مبلغاً للمالك فوراً
/// عند الحفظ (عكس "عهدة على الفندق" في اتجاه القيد)، بلا انتظار تقرير يومي
/// أو ترحيل. هذا يخالف دورة الحياة المحاسبية المعتمَدة الآن (معلّق ← تقرير
/// يومي ← ترحيل)، فلم يعد أي زر "إضافة" في التطبيق يفتح هذه الشاشة — الإضافة
/// الجديدة تمر عبر AddPendingExpensePage(lockToOwnerDrawing: true) بدلاً من
/// ذلك (راجع pending_expenses_list_page.dart._openAdd). تبقى هذه الشاشة فقط
/// لعرض/تعديل/حذف سحوبات قديمة أُنشئت بهذا المسار الفوري قبل التغيير.
///
/// [editWithdrawal] يفتح الشاشة بوضع التعديل (يُملأ النموذج مسبقاً، ويظهر
/// زر حذف) — مسموح فقط إن لم يُرحَّل تقرير يوم هذا المسحوب بعد؛ راجع
/// VaultRepository.updateOwnerWithdrawal/deleteOwnerWithdrawal للحماية
/// الفعلية على مستوى طبقة الأعمال (لا تعتمد على إخفاء الأزرار هنا فقط).
class AddOwnerWithdrawalPage extends StatefulWidget {
  final Hotel hotel;
  final AdvanceWithdrawal? editWithdrawal;
  const AddOwnerWithdrawalPage({super.key, required this.hotel, this.editWithdrawal});

  @override
  State<AddOwnerWithdrawalPage> createState() => _AddOwnerWithdrawalPageState();
}

class _AddOwnerWithdrawalPageState extends State<AddOwnerWithdrawalPage> {
  final _repository = VaultRepository();
  final _formKey = GlobalKey<FormState>();
  final _statementController = TextEditingController();
  final _amountController = TextEditingController();
  String _fundingSource = 'نقد';

  bool get _isEditing => widget.editWithdrawal != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editWithdrawal;
    if (edit != null) {
      _statementController.text = edit.statement;
      _amountController.text = NumberFormat("#,##0.##").format(edit.amount);
      _fundingSource = edit.method;
    }
  }

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

    final edit = widget.editWithdrawal;
    final now = DateTime.now();
    final withdrawal = AdvanceWithdrawal(
      id: edit?.id,
      hotelId: widget.hotel.id!,
      amount: amount,
      statement: _statementController.text.trim(),
      method: _fundingSource,
      date: edit?.date ?? DateFormat('yyyy-MM-dd').format(now),
      time: edit?.time ?? DateFormat('HH:mm:ss').format(now),
      createdAt: edit?.createdAt ?? now.toIso8601String(),
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
          title: _isEditing ? "مراجعة تعديل المسحوب" : "مراجعة مسحوبات المالك",
          items: reviewItems,
          onConfirm: () async {
            if (edit != null) {
              await _repository.updateOwnerWithdrawal(edit, withdrawal);
            } else {
              await _repository.addOwnerWithdrawal(withdrawal);
            }
            if (mounted) {
              Navigator.pop(context); // Close Review
              Navigator.pop(context, true); // Close Add/Edit Page
            }
          },
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final edit = widget.editWithdrawal;
    if (edit == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف مسحوب المالك"),
        content: const Text("هل أنت متأكد من حذف هذا المسحوب؟ سيُعكَس أثره المحاسبي بالكامل."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("حذف"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteOwnerWithdrawal(edit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('StateError: ', '')), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: _isEditing ? "تعديل مسحوب مالك" : "إضافة مسحوب مالك", hotel: widget.hotel),
        centerTitle: true,
        actions: _isEditing ? [IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: "حذف", onPressed: _delete)] : null,
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
