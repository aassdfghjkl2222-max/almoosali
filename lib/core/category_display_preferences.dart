import 'app_preferences.dart';
import '../models/financial_category.dart';

enum CategoryPickerLayout { list, grid }

enum CategoryPickerSortMode { manual, alphabetical, favorites, recent }

enum CategoryButtonSize { small, medium, large }

enum CategoryAppearance { iconAndName, nameOnly, iconOnly }

/// خدمة تفضيلات العرض المركزية الوحيدة لمُنتقي الفئة المالية — مصدر واحد
/// يقرأه كل مُنتقي فئة في التطبيق (financial_category_picker.dart) وصفحة
/// معاينتها الحيّة (financial_category_display_preferences_page.dart)، بدل
/// أن تحمل كل شاشة إدخال أسلوب عرضها الخاص. تخصيص بصري بحت فقط — [applyOrder]
/// يُعيد ترتيب نسخة معروضة من القائمة، ولا يكتب شيئاً في قاعدة البيانات ولا
/// يمس sort_order الفعلي (ذلك يبقى محصوراً في "وضع الترتيب" بشاشة الإدارة).
class CategoryDisplayPreferences {
  final CategoryPickerLayout layout;
  final int gridColumns;
  final CategoryPickerSortMode sortMode;
  final CategoryButtonSize buttonSize;
  final CategoryAppearance appearance;
  final bool showFavoritesFirst;
  final bool rememberRecentlyUsed;

  const CategoryDisplayPreferences({
    this.layout = CategoryPickerLayout.list,
    this.gridColumns = 3,
    this.sortMode = CategoryPickerSortMode.manual,
    this.buttonSize = CategoryButtonSize.medium,
    this.appearance = CategoryAppearance.iconAndName,
    this.showFavoritesFirst = true,
    this.rememberRecentlyUsed = true,
  });

  static Future<CategoryDisplayPreferences> load() async {
    final layoutStr = await AppPreferences.getString(AppPreferences.keyCategoryPickerLayout, defaultValue: 'list');
    final columns = await AppPreferences.getInt(AppPreferences.keyCategoryPickerGridColumns, defaultValue: 3);
    final sortStr = await AppPreferences.getString(AppPreferences.keyCategoryPickerSortMode, defaultValue: 'manual');
    final sizeStr = await AppPreferences.getString(AppPreferences.keyCategoryPickerButtonSize, defaultValue: 'medium');
    final appearanceStr = await AppPreferences.getString(AppPreferences.keyCategoryPickerAppearance, defaultValue: 'icon_name');
    final favoritesFirst = await AppPreferences.getBool(AppPreferences.keyCategoryPickerShowFavoritesFirst, defaultValue: true);
    final rememberRecent = await AppPreferences.getBool(AppPreferences.keyCategoryPickerRememberRecent, defaultValue: true);

    return CategoryDisplayPreferences(
      layout: layoutStr == 'grid' ? CategoryPickerLayout.grid : CategoryPickerLayout.list,
      gridColumns: columns.clamp(2, 5),
      sortMode: CategoryPickerSortMode.values.firstWhere((m) => m.name == sortStr, orElse: () => CategoryPickerSortMode.manual),
      buttonSize: CategoryButtonSize.values.firstWhere((s) => s.name == sizeStr, orElse: () => CategoryButtonSize.medium),
      appearance: _appearanceFromKey(appearanceStr),
      showFavoritesFirst: favoritesFirst,
      rememberRecentlyUsed: rememberRecent,
    );
  }

  static CategoryAppearance _appearanceFromKey(String key) {
    switch (key) {
      case 'name_only':
        return CategoryAppearance.nameOnly;
      case 'icon_only':
        return CategoryAppearance.iconOnly;
      default:
        return CategoryAppearance.iconAndName;
    }
  }

  static String _appearanceToKey(CategoryAppearance a) {
    switch (a) {
      case CategoryAppearance.nameOnly:
        return 'name_only';
      case CategoryAppearance.iconOnly:
        return 'icon_only';
      case CategoryAppearance.iconAndName:
        return 'icon_name';
    }
  }

  Future<void> save() async {
    await AppPreferences.setString(AppPreferences.keyCategoryPickerLayout, layout == CategoryPickerLayout.grid ? 'grid' : 'list');
    await AppPreferences.setInt(AppPreferences.keyCategoryPickerGridColumns, gridColumns);
    await AppPreferences.setString(AppPreferences.keyCategoryPickerSortMode, sortMode.name);
    await AppPreferences.setString(AppPreferences.keyCategoryPickerButtonSize, buttonSize.name);
    await AppPreferences.setString(AppPreferences.keyCategoryPickerAppearance, _appearanceToKey(appearance));
    await AppPreferences.setBool(AppPreferences.keyCategoryPickerShowFavoritesFirst, showFavoritesFirst);
    await AppPreferences.setBool(AppPreferences.keyCategoryPickerRememberRecent, rememberRecentlyUsed);
  }

  CategoryDisplayPreferences copyWith({
    CategoryPickerLayout? layout,
    int? gridColumns,
    CategoryPickerSortMode? sortMode,
    CategoryButtonSize? buttonSize,
    CategoryAppearance? appearance,
    bool? showFavoritesFirst,
    bool? rememberRecentlyUsed,
  }) {
    return CategoryDisplayPreferences(
      layout: layout ?? this.layout,
      gridColumns: gridColumns ?? this.gridColumns,
      sortMode: sortMode ?? this.sortMode,
      buttonSize: buttonSize ?? this.buttonSize,
      appearance: appearance ?? this.appearance,
      showFavoritesFirst: showFavoritesFirst ?? this.showFavoritesFirst,
      rememberRecentlyUsed: rememberRecentlyUsed ?? this.rememberRecentlyUsed,
    );
  }

  /// يبني ترتيب عرض جديد (نسخة) فوق [categories] — لا يُعدِّل القائمة الأصلية
  /// ولا أي شيء في قاعدة البيانات. الأساس هو [sortMode]، ثم طبقتا تعزيز
  /// مستقلتان اختياريتان تُطبَّقان فوقه بالترتيب: المفضّلة أولاً (كتلة واحدة
  /// مستقرة في المقدمة) ثم الأحدث استخداماً (كتلة مستقرة أخرى فوقها) — كلا
  /// التعزيزين يحافظان على الترتيب النسبي داخل كل كتلة كما أنتجه [sortMode]
  /// (Iterable.where مستقر بطبعه)، فلا يتعارضان مع بعضهما ولا مع الوضع الأساسي
  /// حتى لو اختار المدير "الأحدث استخداماً" كوضع أساسي *و* فعَّل نفس التبديل.
  List<FinancialCategory> applyOrder(List<FinancialCategory> categories) {
    final base = List<FinancialCategory>.from(categories);
    switch (sortMode) {
      case CategoryPickerSortMode.alphabetical:
        base.sort((a, b) => a.name.compareTo(b.name));
        break;
      case CategoryPickerSortMode.favorites:
        base.sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return a.sortOrder.compareTo(b.sortOrder);
        });
        break;
      case CategoryPickerSortMode.recent:
        base.sort((a, b) {
          final aUsed = a.lastUsedAt, bUsed = b.lastUsedAt;
          if (aUsed == null && bUsed == null) return a.sortOrder.compareTo(b.sortOrder);
          if (aUsed == null) return 1;
          if (bUsed == null) return -1;
          return bUsed.compareTo(aUsed);
        });
        break;
      case CategoryPickerSortMode.manual:
        base.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        break;
    }

    var ordered = base;
    if (showFavoritesFirst) {
      final pinned = ordered.where((c) => c.isPinned).toList();
      final rest = ordered.where((c) => !c.isPinned).toList();
      ordered = [...pinned, ...rest];
    }
    if (rememberRecentlyUsed) {
      final recent = ordered.where((c) => c.lastUsedAt != null).toList();
      final rest = ordered.where((c) => c.lastUsedAt == null).toList();
      ordered = [...recent, ...rest];
    }
    return ordered;
  }
}
