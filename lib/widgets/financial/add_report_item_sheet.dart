import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/financial_category.dart';
import '../../models/hotel.dart';
import 'financial_category_picker.dart';
import 'funding_source_picker.dart';

/// نتيجة "إضافة بند" — [categoryId] هو مصدر الحقيقة (يُخزَّن في details_json
/// الآن)، و[name] نسخة عرض فقط (تبقى العروض/التصدير القديمة تعمل بلا تغيير).
typedef AddReportItemResult = ({int categoryId, String name, String fundingSource});

/// إضافة بند (إيراد أو مصروف) إلى التقرير الحالي — خطوتان متتاليتان: اختيار
/// فئة عبر المُنتقي الموحّد [showFinancialCategoryPicker] (بحث/مفضّلة/أحدث
/// استخداماً، بلا أي إمكانية لكتابة اسم حر — راجع "Core Principle")، ثم
/// اختيار مصدر التمويل. لإضافة فئة غير موجودة بعد: الإعدادات ← الفئات المالية.
Future<AddReportItemResult?> showAddReportItemSheet(
  BuildContext context, {
  required String itemType,
  required int hotelId,
  required List<Hotel> otherHotels,
}) async {
  final category = await showFinancialCategoryPicker(context, type: itemType);
  if (category == null || !context.mounted) return null;
  return showModalBottomSheet<AddReportItemResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => _AddReportItemFundingSheet(category: category, itemType: itemType, hotelId: hotelId, otherHotels: otherHotels),
  );
}

class _AddReportItemFundingSheet extends StatefulWidget {
  final FinancialCategory category;
  final String itemType;
  final int hotelId;
  final List<Hotel> otherHotels;
  const _AddReportItemFundingSheet({required this.category, required this.itemType, required this.hotelId, required this.otherHotels});

  @override
  State<_AddReportItemFundingSheet> createState() => _AddReportItemFundingSheetState();
}

class _AddReportItemFundingSheetState extends State<_AddReportItemFundingSheet> {
  String? _fundingSource;

  bool get _isRevenue => widget.itemType == FinancialCategory.typeRevenue;

  @override
  void initState() {
    super.initState();
    _fundingSource = widget.category.defaultFundingSource;
  }

  Future<void> _pickFundingSource() async {
    final result = await showFundingSourcePicker(
      context,
      hotelId: widget.hotelId,
      otherHotels: widget.otherHotels,
      allowDeferred: false,
      allowBankTransfer: _isRevenue,
    );
    if (result != null) setState(() => _fundingSource = result.paymentMethod);
  }

  void _confirm() {
    if (_fundingSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار مصدر التمويل")));
      return;
    }
    final result = (categoryId: widget.category.id!, name: widget.category.name, fundingSource: _fundingSource!);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Color(category.colorValue).withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(IconData(category.iconCode, fontFamily: 'MaterialIcons'), color: Color(category.colorValue), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(category.name, style: AppTextStyles.title.copyWith(fontSize: 17), overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: AppSizes.sm),
              InkWell(
                onTap: _pickFundingSource,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_fundingSource ?? "اختيار مصدر التمويل", style: _fundingSource == null ? AppTextStyles.caption : AppTextStyles.bodyBold.copyWith(fontSize: 13))),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              ElevatedButton(onPressed: _confirm, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text("إضافة")),
              const SizedBox(height: AppSizes.sm),
            ],
          ),
        ),
      ),
    );
  }
}
