import 'package:supabase_flutter/supabase_flutter.dart';

/// نقطة الدخول الوحيدة لتهيئة اتصال Supabase — **غير مُستدعاة من main.dart
/// بعد**، وبلا أي تأثير على تشغيل التطبيق الحالي (المحلي بالكامل عبر
/// sqflite) حتى يُقرَّر صراحةً ربط شاشة حقيقية بهذه الطبقة. راجع
/// docs/database_architecture/supabase_schema_design.md للسياق الكامل.
///
/// القيم تُقرأ من متغيرات بيئة وقت البناء (`--dart-define`) — لا يوجد أي
/// مفتاح أو رابط مكتوب هنا أو في أي ملف بالمستودع:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=xxxxxxxx
/// ```
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// يُهيّئ عميل Supabase العام — يجب استدعاؤه مرة واحدة فقط، ولن يُستدعى
  /// تلقائياً من أي مكان حتى تقرر شاشة أو خدمة حقيقية استخدام هذه الطبقة.
  static Future<void> initialize() async {
    if (!isConfigured) {
      throw StateError(
        'SupabaseConfig: SUPABASE_URL/SUPABASE_ANON_KEY غير مُعرَّفين. '
        'مرِّرهما عبر --dart-define عند التشغيل/البناء قبل استدعاء initialize().',
      );
    }
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
