import '../core/app_preferences.dart';

/// نقطة الربط المستقبلية بين إعدادات المستخدم المحفوظة محلياً
/// (AppPreferences/SharedPreferences) وبين Firebase Authentication +
/// Cloud Firestore، حسب قرار العمارة المعتمَد لتطبيق منازل.
///
/// المرحلة الحالية: التخزين محلي بالكامل (يعمل بلا إنترنت)، ولا يوجد أي
/// اتصال شبكي فعلي هنا — [pushToCloud] و[pullFromCloud] عمليتان صوريتان
/// (no-op) موثَّقتان بوضوح. عند إضافة تسجيل الدخول وربط Firebase مستقبلاً:
///   1) `pushToCloud` تكتب هذه المفاتيح إلى مستند Firestore خاص بـ
///      uid المستخدم الحالي من FirebaseAuth (مثلاً users/{uid}/settings).
///   2) `pullFromCloud` تُستدعى بعد تسجيل الدخول من أي جهاز لتحميل نفس
///      الإعدادات وتطبيقها محلياً عبر AppThemeController.
/// لا حاجة لتعديل أي شاشة تستهلك هذه الإعدادات (SettingsPage/main.dart)
/// عند تنفيذ ذلك — فقط تعبئة جسم الدالتين هنا.
class SettingsSyncService {
  SettingsSyncService._();

  static const bool isCloudSyncImplemented = false;

  /// أسماء الإعدادات المشمولة بالمزامنة السحابية مستقبلاً.
  static const List<String> syncedKeys = [
    AppPreferences.keyDarkMode,
    AppPreferences.keyFontScale,
    AppPreferences.keyAnimationSpeed,
    AppPreferences.keyAppLocale,
  ];

  /// يرفع الإعدادات المحلية الحالية إلى Firestore (صوري حالياً).
  static Future<void> pushToCloud() async {
    // ينتظر ربط Firebase Authentication + Cloud Firestore.
  }

  /// يحمّل إعدادات المستخدم من Firestore ويطبّقها محلياً (صوري حالياً).
  static Future<void> pullFromCloud() async {
    // ينتظر ربط Firebase Authentication + Cloud Firestore.
  }
}
