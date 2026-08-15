import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/category_display_preferences.dart';
import '../../models/financial_category.dart';

/// عنصر عرض فئة واحد — مصدر الترسيم الوحيد المشترك بين المُنتقي الفعلي
/// (financial_category_picker.dart) وصفحة "تفضيلات العرض" (المعاينة الحيّة)،
/// حتى تتطابق المعاينة مع الشكل الحقيقي دائماً بلا أي منطق واجهة مكرَّر.
/// يقرأ [prefs.buttonSize]/[prefs.appearance] فقط (الترتيب/التخطيط يُقرَّران
/// خارج هذا العنصر من قِبل الحاوية المستدعية: ListView أو GridView).
class FinancialCategoryTile extends StatelessWidget {
  final FinancialCategory category;
  final CategoryDisplayPreferences prefs;
  final CategoryPickerLayout layout;
  final bool isSelected;
  final VoidCallback? onTap;

  const FinancialCategoryTile({
    super.key,
    required this.category,
    required this.prefs,
    required this.layout,
    this.isSelected = false,
    this.onTap,
  });

  double get _iconSize {
    switch (prefs.buttonSize) {
      case CategoryButtonSize.small:
        return 18;
      case CategoryButtonSize.medium:
        return 22;
      case CategoryButtonSize.large:
        return 28;
    }
  }

  double get _fontSize {
    switch (prefs.buttonSize) {
      case CategoryButtonSize.small:
        return 12;
      case CategoryButtonSize.medium:
        return 14;
      case CategoryButtonSize.large:
        return 16;
    }
  }

  EdgeInsets get _padding {
    switch (prefs.buttonSize) {
      case CategoryButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
      case CategoryButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
      case CategoryButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 16);
    }
  }

  bool get _showIcon => prefs.appearance != CategoryAppearance.nameOnly;
  bool get _showName => prefs.appearance != CategoryAppearance.iconOnly;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    final icon = Icon(IconData(category.iconCode, fontFamily: 'MaterialIcons'), color: color, size: _iconSize);

    if (layout == CategoryPickerLayout.list) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: _padding,
          child: Row(
            children: [
              if (_showIcon) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: icon,
                ),
                const SizedBox(width: 12),
              ],
              if (_showName)
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(fontSize: _fontSize, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              if (category.isPinned) const Icon(Icons.star, size: 15, color: Colors.amber),
              if (isSelected) ...[const SizedBox(width: 6), Icon(Icons.check_circle, color: color, size: 20)],
            ],
          ),
        ),
      );
    }

    // شبكة: الأيقونة فوق الاسم، بطاقة مربّعة تقريباً.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: _padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
          color: isSelected ? color.withValues(alpha: 0.06) : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showIcon) icon,
                if (_showIcon && _showName) const SizedBox(height: 6),
                if (_showName)
                  Text(
                    category.name,
                    style: TextStyle(fontSize: _fontSize, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            if (category.isPinned)
              const Positioned(top: 0, left: 0, child: Icon(Icons.star, size: 13, color: Colors.amber)),
          ],
        ),
      ),
    );
  }
}
