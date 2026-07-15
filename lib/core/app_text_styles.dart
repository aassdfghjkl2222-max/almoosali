import 'package:flutter/material.dart';

/// أنماط النص المشتركة. الأحجام والأوزان فقط هنا — الألوان مقصودة الحذف
/// عمداً (بلا `color:`) لتُستمَد تلقائياً من Theme.of(context) عبر
/// DefaultTextStyle عند البناء، فتتبع الوضع الفاتح/الداكن دون أي تعديل في
/// أي شاشة تستخدم هذه الأنماط. استخدم `.copyWith(color: ...)` فقط عند
/// الحاجة الفعلية للون هوية الفندق (Theme.of(context).colorScheme.primary)
/// أو لون حالة (AppColors.success/danger/...).
class AppTextStyles {
  AppTextStyles._();

  static const display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static const headline = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
  );

  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    fontSize: 16,
  );

  static const bodyBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const caption = TextStyle(
    fontSize: 14,
  );

  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}