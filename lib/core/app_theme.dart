import 'package:flutter/material.dart';
import 'app_radius.dart';
import 'hotel_identity.dart';

/// المصدر الوحيد للحقيقة لثيم التطبيق (فاتح وداكن معاً) — أي شاشة تعتمد على
/// Theme.of(context) بدل ألوان ثابتة تتبع هذا الثيم تلقائياً، وتتحول فوراً
/// عند تبديل الوضع الداكن من الإعدادات دون إعادة تشغيل التطبيق.
class AppTheme {
  AppTheme._();

  static ThemeData get light => createTheme(HotelIdentity.defaultIdentity());

  static ThemeData get dark => createTheme(HotelIdentity.defaultIdentity(), brightness: Brightness.dark);

  /// يبني ثيماً كاملاً (فاتحاً أو داكناً) لهوية فندق معيّنة. في الوضع الفاتح
  /// يبقى الناتج مطابقاً تماماً لما كان عليه قبل دعم الوضع الداكن (لا تغيير
  /// بصري). في الوضع الداكن تُشتق كل الألوان من نفس لون هوية الفندق عبر
  /// ColorScheme.fromSeed حتى تبقى الهوية اللونية لكل فندق محفوظة حتى في
  /// الوضع الداكن.
  static ThemeData createTheme(HotelIdentity identity, {Brightness brightness = Brightness.light}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? ColorScheme.fromSeed(seedColor: identity.primary, brightness: Brightness.dark)
        : ColorScheme.fromSeed(
            seedColor: identity.primary,
            primary: identity.primary,
            secondary: identity.secondary,
            surface: identity.cardBackground,
            error: identity.danger,
            outline: identity.dividerColor,
          );

    final scaffoldBackground = isDark ? colorScheme.surface : identity.scaffoldBackground;
    final cardBackground = isDark ? colorScheme.surfaceContainerHigh : identity.cardBackground;
    final appBarBackground = isDark ? colorScheme.surfaceContainer : identity.appBarBackground;
    final appBarForeground = isDark ? colorScheme.onSurface : identity.appBarForeground;
    final iconColor = isDark ? colorScheme.onSurfaceVariant : identity.iconColor;
    final dividerColor = isDark ? colorScheme.outlineVariant : identity.dividerColor;
    final unselectedGrey = isDark ? Colors.grey.shade500 : Colors.grey;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: cardBackground,
      dividerColor: dividerColor,

      colorScheme: colorScheme,

      // نصوص التطبيق الافتراضية — أي Text بلا لون صريح (أو عبر AppTextStyles
      // بلا لون مضمَّن) يتبع هذا تلقائياً في كلا الوضعين.
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          ),

      // ثيم AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        iconTheme: IconThemeData(color: appBarForeground),
      ),

      // ثيم البطاقات
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ثيم الأزرار الرئيسية
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? colorScheme.primary : identity.buttonBackground,
          foregroundColor: isDark ? colorScheme.onPrimary : identity.buttonForeground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // ثيم التبويبات (Tabs)
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: unselectedGrey,
        indicatorColor: isDark ? colorScheme.primary : identity.hotelIndicatorColor,
      ),

      // ثيم الجداول (DataTable)
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(isDark ? colorScheme.surfaceContainerHigh : identity.hotelTableHeaderBackground),
        dataRowColor: WidgetStateProperty.all(isDark ? colorScheme.surfaceContainerHigh : identity.hotelTableRowBackground),
        headingTextStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
      ),

      // ثيم الأيقونات
      iconTheme: IconThemeData(
        color: iconColor,
      ),

      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),

      // ثيم شريط التنقل السفلي
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: unselectedGrey,
      ),

      splashColor: colorScheme.primary.withOpacity(0.1),

      // ثيم النوافذ المنبثقة (AlertDialog) الموحَّد — حواف دائرية فاخرة بشكل
      // افتراضي لكل نافذة في التطبيق، حتى تلك التي لا تُحدِّد shape صراحةً.
      // النوافذ الحالية التي تُكرِّر نفس الـ shape يدوياً تبقى تعمل كما هي
      // (قيمة مطابقة، لا تعارض) — هذا فقط يمنع أي نافذة جديدة من الظهور بحواف
      // حادة افتراضية بالخطأ.
      dialogTheme: DialogThemeData(
        backgroundColor: cardBackground,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),

      // ثيم النوافذ السفلية المنبثقة (BottomSheet) — حافة علوية دائرية فاخرة
      // موحَّدة، بنفس منطق dialogTheme أعلاه.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBackground,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      ),
    );
  }
}
