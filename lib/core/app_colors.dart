import 'package:flutter/material.dart';

/// ألوان الهوية والحالات الثابتة فقط (لا تتغير بين الوضع الفاتح والداكن).
/// خلفيات الشاشات والبطاقات والنصوص والحدود أصبحت جميعها تتبع الثيم عبر
/// Theme.of(context) (راجع core/app_theme.dart) بدل قيم ثابتة هنا، حتى
/// يتحول التطبيق بأكمله فعلياً عند تبديل الوضع الداكن من الإعدادات.
class AppColors {
  AppColors._();

  // ===========================
  // الهوية الافتراضية (Default Identity)
  // تستخدم عند عدم وجود فندق محدد أو كقيم افتراضية
  // ===========================

  static const primary = Color(0xff7A1E2C); // العنابي (الافتراضي)
  static const secondary = Color(0xffB8913F); // الذهبي (الافتراضي)

  // ===========================
  // الحالات
  // ===========================

  static const success = Color(0xff0B7A47);
  static const warning = Color(0xffD18B00);
  static const danger = Color(0xffD32F2F);
  static const info = Color(0xff1565C0);

  // ===========================
  // الظلال
  // ===========================

  static const shadow = Color(0x14000000);
}