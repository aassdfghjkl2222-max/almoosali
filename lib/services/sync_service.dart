import '../core/app_preferences.dart';

/// هيكلية المزامنة السحابية — واجهة وبنية برمجية جاهزة للربط مع خدمة سحابية
/// فعلية مستقبلاً دون الحاجة لإعادة تصميم الصفحة أو النماذج المستخدمة.
///
/// لا تنفّذ هذه الخدمة أي اتصال شبكي حقيقياً في هذه المرحلة — [syncNow]
/// عملية صورية (no-op) تُسجَّل في السجل بوضوح كعملية "غير مفعَّلة"، ولا تُحدِّث
/// وقت "آخر مزامنة" الفعلي. عند ربط خدمة سحابية حقيقية مستقبلاً، يكفي تنفيذ
/// المنطق داخل هذه الدالة دون تغيير أي شيء آخر في الصفحات المستخدِمة لها.
class SyncService {
  SyncService._();

  static const bool isCloudSyncImplemented = false;

  static Future<String> getLastSyncLabel() async {
    final raw = await AppPreferences.getString(AppPreferences.keyLastSyncAt);
    if (raw.isEmpty) return 'لم تتم أي مزامنة بعد';
    return raw;
  }

  static Future<List<String>> getLinkedDevices() async {
    // لا يوجد نظام ربط أجهزة فعلي بعد؛ قائمة فارغة بشكل صادق حتى تُبنى
    // آلية تسجيل الأجهزة الحقيقية مع الخدمة السحابية.
    return const [];
  }

  /// محاولة مزامنة الآن — صورية حالياً، تعيد رسالة توضيحية للمستخدم فقط.
  static Future<String> syncNow() async {
    return 'المزامنة السحابية غير مفعَّلة بعد في هذا الإصدار — سيتم تفعيلها في مرحلة قادمة دون الحاجة لإعادة تصميم هذا القسم.';
  }
}
