import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;

import 'app_preferences.dart';
import '../services/settings_sync_service.dart';

/// الحالة العامة التفاعلية لإعدادات المظهر (الوضع الداكن، حجم الخط، سرعة
/// الحركة) — بنفس نمط [HotelSession] (ValueNotifier وحيد بلا مكتبة إدارة
/// حالة): يُقرأ من main.dart لبناء MaterialApp تفاعلياً فيتّبعه أي عنصر
/// يعتمد على Theme.of(context) في أي شاشة، مهما كان عمقها داخل التنقّل،
/// دون الحاجة لإعادة تشغيل التطبيق.
///
/// طبقة التخزين المحلي (AppPreferences) هي مصدر الحقيقة الحالي. عند ربط
/// Firebase Authentication + Cloud Firestore مستقبلاً، تُستدعى
/// [SettingsSyncService] من نفس الـ setters هنا دون أي تعديل على أي شاشة
/// تستهلك هذه القيم — راجع lib/services/settings_sync_service.dart.
class AppThemeController {
  AppThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<double> fontScale = ValueNotifier(1.0);
  static final ValueNotifier<String> animationSpeed = ValueNotifier('normal');

  /// لغة التطبيق — 'ar' هي القيمة الوحيدة المتاحة فعلياً حالياً (لا توجد
  /// ملفات ترجمة إنجليزية بعد ولا واجهة اختيار لغة)، لكن الحالة تفاعلية
  /// وجاهزة بالكامل: أي شاشة تعتمد على Locale.of(context)/main.dart تتبعها
  /// تلقائياً فور توفر ترجمة فعلية وواجهة اختيار دون إعادة تصميم.
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar', 'SA'));

  static const Map<String, double> _speedFactors = {'slow': 1.6, 'normal': 1.0, 'fast': 0.6};

  static bool _bootstrapped = false;

  /// يُستدعى مرة واحدة عند إقلاع التطبيق (main.dart) لاستعادة الإعدادات
  /// المحفوظة قبل أول رسم للواجهة.
  static Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final dark = await AppPreferences.getBool(AppPreferences.keyDarkMode);
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;

    fontScale.value = await AppPreferences.getDouble(AppPreferences.keyFontScale, defaultValue: 1.0);

    final speed = await AppPreferences.getString(AppPreferences.keyAnimationSpeed, defaultValue: 'normal');
    animationSpeed.value = speed;
    timeDilation = _speedFactors[speed] ?? 1.0;

    final localeCode = await AppPreferences.getString(AppPreferences.keyAppLocale, defaultValue: 'ar');
    locale.value = localeCode == 'en' ? const Locale('en', 'US') : const Locale('ar', 'SA');
  }

  static Future<void> setDarkMode(bool enabled) async {
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    await AppPreferences.setBool(AppPreferences.keyDarkMode, enabled);
    SettingsSyncService.pushToCloud();
  }

  static Future<void> setFontScale(double scale) async {
    fontScale.value = scale;
    await AppPreferences.setDouble(AppPreferences.keyFontScale, scale);
    SettingsSyncService.pushToCloud();
  }

  static Future<void> setAnimationSpeed(String speed) async {
    animationSpeed.value = speed;
    timeDilation = _speedFactors[speed] ?? 1.0;
    await AppPreferences.setString(AppPreferences.keyAnimationSpeed, speed);
    SettingsSyncService.pushToCloud();
  }

  /// غير مستخدَمة من أي واجهة حالياً (لا توجد لغة أخرى مترجَمة بعد) —
  /// جاهزة ليستدعيها منتقي لغة مستقبلاً دون أي تعديل في main.dart.
  static Future<void> setLocale(String languageCode) async {
    locale.value = languageCode == 'en' ? const Locale('en', 'US') : const Locale('ar', 'SA');
    await AppPreferences.setString(AppPreferences.keyAppLocale, languageCode);
    SettingsSyncService.pushToCloud();
  }
}
