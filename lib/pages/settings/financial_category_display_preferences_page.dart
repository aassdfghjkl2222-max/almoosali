import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/category_display_preferences.dart';
import '../../models/financial_category.dart';
import '../../repositories/financial_category_repository.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/financial/financial_category_tile.dart';

/// الإعدادات ← الفئات المالية ← تفضيلات العرض — يتحكم فقط في *كيف* تظهر
/// الفئات (تخطيط/ترتيب/حجم/محتوى الزر) في كل مُنتقي فئة بالتطبيق (راجع
/// showFinancialCategoryPicker) — لا يمس sort_order الفعلي في قاعدة البيانات
/// ولا أي بيانات مالية أو تقرير إطلاقاً. كل تغيير يُحفَظ فوراً (بلا زر حفظ
/// منفصل، بنفس أسلوب بقية مفاتيح SettingsPage)، والمعاينة أسفل الصفحة تعكسه
/// حيّاً عبر نفس عنصر الترسيم المستخدَم في المُنتقي الحقيقي (FinancialCategoryTile)
/// حتى تبقى المعاينة مطابقة للشكل الفعلي دائماً بلا منطق واجهة مكرَّر.
class FinancialCategoryDisplayPreferencesPage extends StatefulWidget {
  const FinancialCategoryDisplayPreferencesPage({super.key});

  @override
  State<FinancialCategoryDisplayPreferencesPage> createState() => _FinancialCategoryDisplayPreferencesPageState();
}

class _FinancialCategoryDisplayPreferencesPageState extends State<FinancialCategoryDisplayPreferencesPage> {
  final _repository = FinancialCategoryRepository();
  CategoryDisplayPreferences _prefs = const CategoryDisplayPreferences();
  List<FinancialCategory> _previewCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      CategoryDisplayPreferences.load(),
      _repository.getCategories(type: FinancialCategory.typeExpense),
    ]);
    if (!mounted) return;
    setState(() {
      _prefs = results[0] as CategoryDisplayPreferences;
      _previewCategories = (results[1] as List<FinancialCategory>).take(6).toList();
      _isLoading = false;
    });
  }

  Future<void> _update(CategoryDisplayPreferences Function(CategoryDisplayPreferences) update) async {
    final next = update(_prefs);
    setState(() => _prefs = next);
    await next.save();
  }

  Future<void> _resetOrder() async {
    await AppDialog.confirmAction(
      context: context,
      title: "استعادة الترتيب الافتراضي",
      message: "سيُعاد ترتيب كل فئات المصروفات والإيرادات إلى ترتيب إنشائها الأصلي، ويُلغى أي ترتيب يدوي حالي. هذا لا يؤثر على أي بيانات أو تقارير مالية.",
      confirmLabel: "استعادة",
      isDangerous: true,
      onConfirm: () async {
        await _repository.resetToDefaultOrder(FinancialCategory.typeExpense);
        await _repository.resetToDefaultOrder(FinancialCategory.typeRevenue);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت استعادة الترتيب الافتراضي")));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("تفضيلات العرض", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildInfoBanner(),
                const SizedBox(height: AppSizes.lg),
                _sectionTitle("نمط العرض"),
                _buildCard([
                  _buildLayoutSelector(),
                  if (_prefs.layout == CategoryPickerLayout.grid) ...[
                    const Divider(height: 1),
                    _buildColumnsSelector(),
                  ],
                ]),
                const SizedBox(height: AppSizes.lg),
                _sectionTitle("ترتيب العرض الافتراضي"),
                _buildCard([
                  _sortModeTile("يدوي (حسب وضع الترتيب في شاشة الإدارة)", CategoryPickerSortMode.manual),
                  const Divider(height: 1),
                  _sortModeTile("أبجدي", CategoryPickerSortMode.alphabetical),
                  const Divider(height: 1),
                  _sortModeTile("المفضّلة أولاً", CategoryPickerSortMode.favorites),
                  const Divider(height: 1),
                  _sortModeTile("الأحدث استخداماً", CategoryPickerSortMode.recent),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restart_alt, color: Colors.blueGrey),
                    title: const Text("استعادة الترتيب الافتراضي"),
                    subtitle: const Text("يُعيد الترتيب اليدوي لكل الفئات إلى ترتيب إنشائها الأصلي", style: AppTextStyles.caption),
                    onTap: _resetOrder,
                  ),
                ]),
                const SizedBox(height: AppSizes.lg),
                _sectionTitle("حجم الزر"),
                _buildCard([_buildButtonSizeSelector()]),
                const SizedBox(height: AppSizes.lg),
                _sectionTitle("محتوى الزر"),
                _buildCard([_buildAppearanceSelector()]),
                const SizedBox(height: AppSizes.lg),
                _sectionTitle("المفضّلة والأحدث استخداماً"),
                _buildCard([
                  SwitchListTile(
                    title: const Text("إظهار المفضّلة أولاً"),
                    subtitle: const Text("الفئات المُعلَّمة بنجمة تظهر قبل غيرها دائماً", style: AppTextStyles.caption),
                    value: _prefs.showFavoritesFirst,
                    onChanged: (v) => _update((p) => p.copyWith(showFavoritesFirst: v)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("تذكّر الفئات الأخيرة الاستخدام"),
                    subtitle: const Text("لا يؤثر إطلاقاً على التقارير أو البيانات المحفوظة، تنظيم العرض فقط", style: AppTextStyles.caption),
                    value: _prefs.rememberRecentlyUsed,
                    onChanged: (v) => _update((p) => p.copyWith(rememberRecentlyUsed: v)),
                  ),
                ]),
                const SizedBox(height: AppSizes.lg),
                _sectionTitle("معاينة حيّة"),
                _buildPreview(),
                const SizedBox(height: AppSizes.xl),
              ],
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "تخصيص بصري بحت — لا يؤثر على البيانات المالية أو التقارير أو الحسابات إطلاقاً.",
              style: TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm, right: AppSizes.xs),
      child: Text(title, style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Column(children: children),
    );
  }

  Widget _buildLayoutSelector() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.sm),
      child: SegmentedButton<CategoryPickerLayout>(
        segments: const [
          ButtonSegment(value: CategoryPickerLayout.list, label: Text("قائمة"), icon: Icon(Icons.view_list_outlined)),
          ButtonSegment(value: CategoryPickerLayout.grid, label: Text("شبكة"), icon: Icon(Icons.grid_view_outlined)),
        ],
        selected: {_prefs.layout},
        onSelectionChanged: (s) => _update((p) => p.copyWith(layout: s.first)),
      ),
    );
  }

  Widget _buildColumnsSelector() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.sm),
      child: Row(
        children: [
          const Padding(padding: EdgeInsets.only(left: AppSizes.sm), child: Text("عدد الأعمدة:", style: AppTextStyles.caption)),
          Expanded(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text("2")),
                ButtonSegment(value: 3, label: Text("3")),
                ButtonSegment(value: 4, label: Text("4")),
                ButtonSegment(value: 5, label: Text("5")),
              ],
              selected: {_prefs.gridColumns},
              onSelectionChanged: (s) => _update((p) => p.copyWith(gridColumns: s.first)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortModeTile(String label, CategoryPickerSortMode mode) {
    return RadioListTile<CategoryPickerSortMode>(
      title: Text(label),
      value: mode,
      groupValue: _prefs.sortMode,
      onChanged: (v) => _update((p) => p.copyWith(sortMode: v)),
    );
  }

  Widget _buildButtonSizeSelector() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.sm),
      child: SegmentedButton<CategoryButtonSize>(
        segments: const [
          ButtonSegment(value: CategoryButtonSize.small, label: Text("صغير")),
          ButtonSegment(value: CategoryButtonSize.medium, label: Text("متوسط")),
          ButtonSegment(value: CategoryButtonSize.large, label: Text("كبير")),
        ],
        selected: {_prefs.buttonSize},
        onSelectionChanged: (s) => _update((p) => p.copyWith(buttonSize: s.first)),
      ),
    );
  }

  Widget _buildAppearanceSelector() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.sm),
      child: SegmentedButton<CategoryAppearance>(
        segments: const [
          ButtonSegment(value: CategoryAppearance.iconAndName, label: Text("أيقونة واسم")),
          ButtonSegment(value: CategoryAppearance.nameOnly, label: Text("اسم فقط")),
          ButtonSegment(value: CategoryAppearance.iconOnly, label: Text("أيقونة فقط")),
        ],
        selected: {_prefs.appearance},
        onSelectionChanged: (s) => _update((p) => p.copyWith(appearance: s.first)),
      ),
    );
  }

  Widget _buildPreview() {
    if (_previewCategories.isEmpty) {
      return _buildCard([
        const Padding(
          padding: EdgeInsets.all(AppSizes.md),
          child: Text("أضف فئات مصروفات أولاً لمعاينتها هنا", style: AppTextStyles.caption),
        ),
      ]);
    }
    final ordered = _prefs.applyOrder(_previewCategories);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: Theme.of(context).dividerColor)),
      padding: const EdgeInsets.all(AppSizes.sm),
      child: _prefs.layout == CategoryPickerLayout.grid
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _prefs.gridColumns,
                mainAxisSpacing: AppSizes.sm,
                crossAxisSpacing: AppSizes.sm,
                childAspectRatio: 0.95,
              ),
              itemCount: ordered.length,
              itemBuilder: (context, index) => FinancialCategoryTile(
                category: ordered[index],
                prefs: _prefs,
                layout: CategoryPickerLayout.grid,
              ),
            )
          : Column(
              children: ordered
                  .map((c) => FinancialCategoryTile(category: c, prefs: _prefs, layout: CategoryPickerLayout.list))
                  .toList(),
            ),
    );
  }
}
