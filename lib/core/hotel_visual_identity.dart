import 'package:flutter/material.dart';

import '../models/hotel.dart';
import 'app_colors.dart';
import 'hotel_identity.dart';

class HotelVisualIdentity {
  HotelVisualIdentity._();

  /// اللون المستخدم عندما لا يملك الفندق لوناً محفوظاً بعد (بيانات قديمة/فندق جديد لم يُحفظ اختياره).
  static const int defaultColorValue = 0xFF7A1E2C;

  static const Color _gold = Color(0xffB8913F);

  /// يبني هوية بصرية كاملة لفندق اعتماداً على لون واحد فقط (اللون المحفوظ في قاعدة البيانات).
  static HotelIdentity identityFromColor(Color primary) {
    return HotelIdentity(
      primary: primary,
      secondary: _gold,
      accent: _gold,
      scaffoldBackground: Color.alphaBlend(primary.withOpacity(0.03), Colors.white),
      cardBackground: Colors.white,
      appBarBackground: primary,
      appBarForeground: Colors.white,
      buttonBackground: primary,
      buttonForeground: Colors.white,
      iconColor: primary,
      dividerColor: primary.withOpacity(0.12),
      hotelIndicatorColor: _gold,
      success: AppColors.success,
      warning: AppColors.warning,
      danger: AppColors.danger,
      info: AppColors.info,
      hotelTableHeaderBackground: primary.withOpacity(0.05),
      hotelTableRowBackground: Colors.white,
      hotelChartPalette: [primary, _gold],
    );
  }

  /// المصدر الوحيد للحقيقة: هوية كل فندق تُشتق من `hotel.identityColorValue`
  /// المحفوظ في قاعدة البيانات — لا يُعتمد إطلاقاً على اسم الفندق.
  static HotelIdentity identityForHotel(Hotel? hotel) {
    final colorValue = hotel?.identityColorValue ?? defaultColorValue;
    return identityFromColor(Color(colorValue));
  }

  static Color colorForHotel(Hotel? hotel) => identityForHotel(hotel).primary;

  static Color surfaceTint(Color color) => color.withOpacity(0.08);
}
