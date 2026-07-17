import 'package:flutter/material.dart';

import 'app_preferences.dart';

/// الحالة العامة التفاعلية لوضع التدريب — بنفس نمط [AppThemeController]:
/// ValueNotifier وحيد يُقرأ من main.dart لعرض الشريط الثابت "🎓 وضع التدريب"
/// فوق كل شاشة/حوار/BottomSheet في التطبيق دون لمس أي صفحة على حدة.
///
/// AppPreferences (keyTrainingModeActive) هي مصدر الحقيقة الدائم عبر
/// إعادة تشغيل التطبيق؛ هذا الـ ValueNotifier هو المرآة التفاعلية له في
/// الذاكرة أثناء تشغيل التطبيق. راجع lib/services/training_mode_service.dart.
class TrainingModeController {
  TrainingModeController._();

  static final ValueNotifier<bool> isActive = ValueNotifier(false);

  static bool _bootstrapped = false;

  /// يُستدعى مرة واحدة عند إقلاع التطبيق (main.dart) قبل أول رسم للواجهة —
  /// يضمن استمرارية وضع التدريب تلقائياً إذا كان لا يزال مفعّلاً من جلسة
  /// سابقة (إغلاق التطبيق بالكامل ثم إعادة فتحه أثناء التدريب).
  static Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    isActive.value = await AppPreferences.getBool(AppPreferences.keyTrainingModeActive);
  }
}
