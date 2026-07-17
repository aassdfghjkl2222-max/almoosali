import 'package:shared_preferences/shared_preferences.dart';

/// تخزين تفضيلات واجهة عامة بسيطة (غير حساسة أمنياً — البيانات الحساسة
/// تبقى في FlutterSecureStorage عبر SecurityService). هذه المفاتيح تُقرأ
/// وتُكتب من صفحة "الإعدادات" فقط في هذه المرحلة؛ أي قسم آخر يريد قراءة
/// أحد هذه التفضيلات مستقبلاً (مثل إخفاء الأرصدة) يستطيع استخدام نفس
/// المفاتيح الثابتة أدناه دون إعادة تصميم.
class AppPreferences {
  AppPreferences._();

  static const keyDarkMode = 'pref_dark_mode';
  static const keyFontScale = 'pref_font_scale'; // 0.9 / 1.0 / 1.15
  static const keyAnimationSpeed = 'pref_animation_speed'; // 'slow' | 'normal' | 'fast'
  static const keyHideBalances = 'pref_hide_balances';
  // وضع التجربة: يخفّف قواعد التقرير المالي اليومي الرسمية (تكرار تقرير لنفس
  // الفندق/التاريخ، تعديل، حذف، إعادة إنشاء) لأغراض الاختبار أثناء التطوير —
  // لا يغيّر أبداً قفل التقرير بعد الترحيل الفعلي إلى الخزنة (قاعدة صارمة في
  // كلا الوضعين). راجع FinancialSummaryPage._reviewReport.
  static const keyTrialMode = 'pref_trial_mode';
  // وضع التدريب: نسخة كاملة منفصلة من ملف قاعدة البيانات (manazel_training.db)
  // يُستخدَم بدل الملف الحقيقي بالكامل بينما هذا العلم مفعّل — لا علاقة له
  // بـ keyTrialMode أعلاه. راجع TrainingModeService/TrainingModeController.
  static const keyTrainingModeActive = 'pref_training_mode_active';
  static const keyNotificationsEnabled = 'pref_notifications_enabled';
  static const keySoundEnabled = 'pref_sound_enabled';
  static const keyVibrationEnabled = 'pref_vibration_enabled';
  static const keyCriticalNotifications = 'pref_critical_notifications';
  static const keySilentNotifications = 'pref_silent_notifications';

  // النسخ الاحتياطي والمزامنة
  static const keyLastBackupAt = 'pref_last_backup_at';
  static const keyBackupLog = 'pref_backup_log';
  static const keyAutoBackupEnabled = 'pref_auto_backup_enabled';
  static const keyAutoBackupFrequency = 'pref_auto_backup_frequency'; // 'daily' | 'weekly' | 'monthly'
  static const keyLastSyncAt = 'pref_last_sync_at';
  static const keySyncLog = 'pref_sync_log';

  // لغة التطبيق — القيمة الوحيدة المتاحة حالياً 'ar' (لا تبديل لغة فعلي
  // بعد)، محفوظة وجاهزة ليقرأها main.dart فور توفر ملفات ترجمة إضافية.
  static const keyAppLocale = 'pref_app_locale';

  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<double> getDouble(String key, {double defaultValue = 1.0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key) ?? defaultValue;
  }

  static Future<void> setDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  static Future<String> getString(String key, {String defaultValue = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
