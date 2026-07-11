import 'package:flutter/material.dart';
import 'hotel_identity.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => createTheme(HotelIdentity.defaultIdentity());

  static ThemeData createTheme(HotelIdentity identity) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: identity.scaffoldBackground,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: identity.primary,
        primary: identity.primary,
        secondary: identity.secondary,
        surface: identity.cardBackground,
        error: identity.danger,
        outline: identity.dividerColor,
      ),

      // ثيم AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: identity.appBarBackground,
        foregroundColor: identity.appBarForeground,
        iconTheme: IconThemeData(color: identity.appBarForeground),
      ),

      // ثيم البطاقات
      cardTheme: CardThemeData(
        color: identity.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ثيم الأزرار الرئيسية
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: identity.buttonBackground,
          foregroundColor: identity.buttonForeground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // ثيم التبويبات (Tabs)
      tabBarTheme: TabBarThemeData(
        labelColor: identity.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: identity.hotelIndicatorColor,
      ),

      // ثيم الجداول (DataTable)
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(identity.hotelTableHeaderBackground),
        dataRowColor: WidgetStateProperty.all(identity.hotelTableRowBackground),
        headingTextStyle: TextStyle(color: identity.primary, fontWeight: FontWeight.bold),
      ),

      // ثيم الأيقونات
      iconTheme: IconThemeData(
        color: identity.iconColor,
      ),

      dividerTheme: DividerThemeData(
        color: identity.dividerColor,
        thickness: 1,
      ),

      // ثيم شريط التنقل السفلي
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: identity.cardBackground,
        selectedItemColor: identity.primary,
        unselectedItemColor: Colors.grey,
      ),

      splashColor: identity.primary.withOpacity(0.1),
    );
  }
}
