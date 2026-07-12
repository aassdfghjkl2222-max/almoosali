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
  static const keyNotificationsEnabled = 'pref_notifications_enabled';
  static const keySoundEnabled = 'pref_sound_enabled';
  static const keyVibrationEnabled = 'pref_vibration_enabled';
  static const keyCriticalNotifications = 'pref_critical_notifications';
  static const keySilentNotifications = 'pref_silent_notifications';

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
