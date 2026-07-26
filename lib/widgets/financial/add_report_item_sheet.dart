import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/financial_category.dart';
import '../../models/hotel.dart';
import '../../repositories/financial_category_repository.dart';
import 'funding_source_picker.dart';

/// نتيجة "إضافة بند" — [categoryId] هو مصدر الحقيقة (يُخزَّن في details_json
/// الآن)، و[name] نسخة عرض فقط (تبقى العروض/التصدير القديمة تعمل بلا تغيير).
typedef AddReportItemResult = ({int categoryId, String name, String fundingSource});

/// نافذة موحّدة لإضافة بند (إيراد أو مصروف) إلى التقرير الحالي — اختيار فئة
/// من محرك الفئات المالية الموحَّد فقط، بلا أي إمكانية لكتابة اسم حر (راجع
/// "Core Principle": لا يجوز كتابة اسم تصنيف يدوياً في أي شاشة). لإضافة فئة
/// غير موجودة بعد: الإعدادات ← الفئات المالية.
Future<AddReportItemResult?> showAddReportItemSheet(
  BuildContext context, {
  required String itemType,
  required int hotelId,
  required List<Hotel> otherHotels,
}) {
  return showModalBottomSheet<AddReportItemResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => _AddReportItemSheet(itemType: itemType, hotelId: hotelId, otherHotels: otherHotels),
  );
}

class _AddReportItemSheet extends StatefulWidget {
  final String itemType;
  final int hotelId;
  final List<Hotel> otherHotels;
  const _AddReportItemSheet({required this.itemType, required this.hotelId, required this.otherHotels});

  @override
  State<_AddReportItemSheet> createState() => _AddReportItemSheetState();
}

class _AddReportItemSheetState extends State<_AddReportItemSheet> {
  final _repository = FinancialCategoryRepository();

  List<FinancialCategory> _categories = [];
  bool _isLoading = true;
  FinancialCategory? _selectedCategory;
  String? _fundingSource;

  bool get _isRevenue => widget.itemType == FinancialCategory.typeRevenue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repository.getCategories(type: widget.itemType);
    if (mounted) setState(() { _categories = items; _isLoading = false; });
  }

  void _pickCategory(FinancialCategory category) {
    setState(() {
      _selectedCategory = category;
      _fundingSource = category.defaultFundingSource;
    });
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
    final category = _selectedCategory;
    if (category == null) return;
    if (_fundingSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار مصدر التمويل")));
      return;
    }
    final result = (categoryId: category.id!, name: category.name, fundingSource: _fundingSource!);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategory == null ? (_isRevenue ? "اختيار فئة إيراد" : "اختيار فئة مصروف") : _selectedCategory!.name,
                      style: AppTextStyles.title.copyWith(fontSize: 17),
                    ),
                  ),
                  if (_selectedCategory != null)
                    IconButton(onPressed: () => setState(() { _selectedCategory = null; _fundingSource = null; }), icon: const Icon(Icons.arrow_back)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 1),
              Flexible(
                child: _isLoading
                    ? const Padding(padding: EdgeInsets.all(AppSizes.lg), child: Center(child: CircularProgressIndicator()))
                    : _selectedCategory == null
                        ? _buildCategoryList()
                        : _buildFundingStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
        child: Center(child: Text("لا توجد فئات بعد — أضفها من الإعدادات ← الفئات المالية", style: AppTextStyles.caption, textAlign: TextAlign.center)),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in _categories)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Color(c.colorValue).withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(IconData(c.iconCode, fontFamily: 'MaterialIcons'), color: Color(c.colorValue), size: 20),
              ),
              title: Text(c.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
              subtitle: c.description != null && c.description!.trim().isNotEmpty ? Text(c.description!, style: AppTextStyles.caption) : null,
              onTap: () => _pickCategory(c),
            ),
        ],
      ),
    );
  }

  Widget _buildFundingStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
    );
  }
}
