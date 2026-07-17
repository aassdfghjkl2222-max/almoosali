import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/pending_expense.dart';
import '../suppliers/supplier_picker_sheet.dart';

/// نتيجة اختيار مصدر التمويل — [paymentMethod] هو النص النهائي الجاهز
/// للتخزين مباشرة في أي عمود `payment_method`/`method` حر (نفس الاصطلاح
/// المستخدم في كل أنحاء المشروع)، و[supplierId] غير null فقط عند اختيار
/// "آجل (دين)".
typedef FundingSourceSelection = ({String paymentMethod, int? supplierId});

/// نافذة موحّدة لاختيار مصدر تمويل — مصدر وحيد للحقيقة لكل شاشة في التطبيق
/// تحتاج هذا الاختيار (المصروفات المعلقة، بنود التقرير اليومي الحرة، بنود
/// الإيراد الجديدة)، بدل تكرار نفس القائمة في كل شاشة على حدة. إضافة مصدر
/// تمويل جديد مستقبلاً تعني تعديل هذا الملف فقط — كل الشاشات المستخدمة له
/// تستفيد فوراً بلا أي تعديل إضافي (قابلية التوسع).
///
/// [allowBankTransfer] يُفعَّل فقط لبنود الإيراد (حيث "تحويل بنكي" مصدر
/// أصيل)، أما للمصروفات فيبقى معطّلاً افتراضياً (لا تخلط مع تسميته الفرعية
/// الظاهرة داخل نص المشاركة لاحقاً كمصدر "غير مسحوب من الصندوق").
/// [allowDeferred] يُفعَّل فقط للمصروفات (آجل (دين) لا معنى له كمصدر إيراد).
Future<FundingSourceSelection?> showFundingSourcePicker(
  BuildContext context, {
  required int hotelId,
  required List<Hotel> otherHotels,
  bool allowDeferred = true,
  bool allowBankTransfer = false,
}) {
  return showModalBottomSheet<FundingSourceSelection>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => _FundingSourcePickerSheet(
      hotelId: hotelId,
      otherHotels: otherHotels,
      allowDeferred: allowDeferred,
      allowBankTransfer: allowBankTransfer,
    ),
  );
}

class _FundingSourcePickerSheet extends StatelessWidget {
  final int hotelId;
  final List<Hotel> otherHotels;
  final bool allowDeferred;
  final bool allowBankTransfer;

  const _FundingSourcePickerSheet({
    required this.hotelId,
    required this.otherHotels,
    required this.allowDeferred,
    required this.allowBankTransfer,
  });

  Future<void> _pickDeferred(BuildContext context) async {
    final supplier = await showSupplierPicker(context, hotelId: hotelId);
    if (supplier == null || !context.mounted) return;
    final FundingSourceSelection result = (paymentMethod: PendingExpense.fundingSourceDeferred, supplierId: supplier.id);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Text("مصدر التمويل", style: AppTextStyles.title.copyWith(fontSize: 17)),
            ),
            const SizedBox(height: AppSizes.sm),
            const Divider(height: 1),
            _tile(context, Icons.money, "نقد", 'نقد'),
            _tile(context, Icons.credit_card, "شبكة", 'شبكة'),
            if (allowBankTransfer) _tile(context, Icons.account_balance, "تحويل بنكي", 'تحويل بنكي'),
            if (otherHotels.isNotEmpty) ...[
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, 4),
                child: Text("ممول من فندق آخر", style: AppTextStyles.caption),
              ),
              for (final h in otherHotels) ...[
                _tile(context, Icons.money, "نقد - ${h.arabicName}", 'نقد - ${h.arabicName}'),
                _tile(context, Icons.credit_card, "شبكة - ${h.arabicName}", 'شبكة - ${h.arabicName}'),
              ],
            ],
            const Divider(height: 1),
            _tile(context, Icons.person_add_alt, "شخصي (من مال المالك)", 'شخصي'),
            _tile(context, Icons.person_off_outlined, "مصروف خاص (لصالح المالك)", 'مصروف خاص'),
            if (allowDeferred) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.hourglass_bottom_outlined),
                title: const Text("⏳ آجل (دين)"),
                subtitle: const Text("يتطلب اختيار مورد", style: AppTextStyles.caption),
                onTap: () => _pickDeferred(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        final FundingSourceSelection result = (paymentMethod: value, supplierId: null);
        Navigator.pop(context, result);
      },
    );
  }
}
