import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/category_display_preferences.dart';
import '../../models/financial_category.dart';
import '../../repositories/financial_category_repository.dart';
import 'financial_category_tile.dart';

/// المُنتقي الموحّد الوحيد لاختيار فئة مالية (مصروف أو إيراد) في أي شاشة
/// تُنشئ عملية مالية — مصدر وحيد للحقيقة بدل تكرار Wrap من ChoiceChip أو
/// DropdownButton في كل شاشة على حدة (راجع Core Principle: لا كتابة اسم حر،
/// لا قائمة فئات محلية منفصلة). بحث فوري بالاسم/الرمز، والتخطيط/الترتيب/حجم
/// الزر/المحتوى المعروض كلها تُقرأ حصراً من CategoryDisplayPreferences —
/// الإعدادات ← الفئات المالية ← تفضيلات العرض هي المكان الوحيد لتغييرها.
/// المؤرشَف مستبعَد دائماً (getCategories الافتراضي).
Future<FinancialCategory?> showFinancialCategoryPicker(
  BuildContext context, {
  required String type,
  FinancialCategory? current,
}) {
  return showModalBottomSheet<FinancialCategory>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => _FinancialCategoryPickerSheet(type: type, current: current),
  );
}

class _FinancialCategoryPickerSheet extends StatefulWidget {
  final String type;
  final FinancialCategory? current;
  const _FinancialCategoryPickerSheet({required this.type, this.current});

  @override
  State<_FinancialCategoryPickerSheet> createState() => _FinancialCategoryPickerSheetState();
}

class _FinancialCategoryPickerSheetState extends State<_FinancialCategoryPickerSheet> {
  final _repository = FinancialCategoryRepository();
  final _searchController = TextEditingController();
  List<FinancialCategory> _all = [];
  CategoryDisplayPreferences _prefs = const CategoryDisplayPreferences();
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _repository.getCategories(type: widget.type),
      CategoryDisplayPreferences.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _all = results[0] as List<FinancialCategory>;
      _prefs = results[1] as CategoryDisplayPreferences;
      _isLoading = false;
    });
  }

  List<FinancialCategory> get _filtered {
    final q = _query.trim();
    final source = q.isEmpty ? _all : _all.where((c) => c.name.contains(q) || (c.code?.contains(q) ?? false)).toList();
    return _prefs.applyOrder(source);
  }

  /// يُسجَّل الاستخدام فوراً عند الاختيار (بلا انتظار) — راجع تعليق
  /// DatabaseService.recordFinancialCategoryUsage لسبب قبول هذا التوقيت
  /// التقريبي هنا تحديداً.
  void _select(FinancialCategory category) {
    _repository.recordUsage(category.id!);
    Navigator.pop(context, category);
  }

  @override
  Widget build(BuildContext context) {
    final isRevenue = widget.type == FinancialCategory.typeRevenue;
    final list = _filtered;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRevenue ? "اختر فئة الإيراد" : "اختر فئة المصروف", style: AppTextStyles.title.copyWith(fontSize: 17)),
                  const SizedBox(height: AppSizes.sm),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: "بحث بالاسم أو الرمز",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _searchController.clear(); _query = ''; })),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(AppSizes.xl), child: Center(child: CircularProgressIndicator()))
                  : list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSizes.lg),
                          child: Center(
                            child: Text(
                              _all.isEmpty ? "لا توجد فئات بعد — أضفها من الإعدادات ← الفئات المالية" : "لا توجد فئة مطابقة",
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _buildList(list),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<FinancialCategory> list) {
    if (_prefs.layout == CategoryPickerLayout.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppSizes.md),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _prefs.gridColumns,
          mainAxisSpacing: AppSizes.sm,
          crossAxisSpacing: AppSizes.sm,
          childAspectRatio: 0.95,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final c = list[index];
          return FinancialCategoryTile(
            category: c,
            prefs: _prefs,
            layout: CategoryPickerLayout.grid,
            isSelected: widget.current?.id == c.id,
            onTap: () => _select(c),
          );
        },
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final c = list[index];
        return FinancialCategoryTile(
          category: c,
          prefs: _prefs,
          layout: CategoryPickerLayout.list,
          isSelected: widget.current?.id == c.id,
          onTap: () => _select(c),
        );
      },
    );
  }
}
