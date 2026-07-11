import 'package:flutter/material.dart';

class HotelIdentity {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color scaffoldBackground;
  final Color cardBackground;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color buttonBackground;
  final Color buttonForeground;
  final Color iconColor;
  final Color dividerColor;
  final Color hotelIndicatorColor;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color hotelTableHeaderBackground;
  final Color hotelTableRowBackground;
  final List<Color> hotelChartPalette;

  HotelIdentity({
    this.primary = Colors.black,
    this.secondary = Colors.black,
    this.accent = Colors.black,
    this.scaffoldBackground = Colors.black,
    this.cardBackground = Colors.black,
    this.appBarBackground = Colors.black,
    this.appBarForeground = Colors.black,
    this.buttonBackground = Colors.black,
    this.buttonForeground = Colors.black,
    this.iconColor = Colors.black,
    this.dividerColor = Colors.black,
    this.hotelIndicatorColor = Colors.black,
    this.success = Colors.black,
    this.warning = Colors.black,
    this.danger = Colors.black,
    this.info = Colors.black,
    this.hotelTableHeaderBackground = Colors.black,
    this.hotelTableRowBackground = Colors.black,
    this.hotelChartPalette = const [],
  });

  static HotelIdentity defaultIdentity() {
    return HotelIdentity(
      primary: const Color(0xff7A1E2C),
      secondary: const Color(0xffB8913F),
      accent: const Color(0xffB8913F),
      scaffoldBackground: const Color(0xffF8F6F2),
      cardBackground: Colors.white,
      appBarBackground: const Color(0xff7A1E2C),
      appBarForeground: Colors.white,
      buttonBackground: const Color(0xff7A1E2C),
      buttonForeground: Colors.white,
      iconColor: const Color(0xff7A1E2C),
      dividerColor: const Color(0xffE5E5E5),
      hotelIndicatorColor: const Color(0xffB8913F),
      success: const Color(0xff0B7A47),
      warning: const Color(0xffD18B00),
      danger: const Color(0xffD32F2F),
      info: const Color(0xff1565C0),
      hotelTableHeaderBackground: const Color(0xffF8F6F2),
      hotelTableRowBackground: Colors.white,
      hotelChartPalette: const [Color(0xff7A1E2C), Color(0xffB8913F)],
    );
  }
}
