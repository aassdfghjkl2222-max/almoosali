import 'package:intl/intl.dart';

import '../core/app_preferences.dart';
import '../core/database/database_service.dart';
import 'hotel_sync_service.dart';

/// هيكلية المزامنة السحابية — الآن مفعَّلة فعلياً للفنادق فقط (المرحلة
/// التجريبية الأولى)، عبر [HotelSyncService]. الواجهة (BackupPage) تبقى
/// كما صُمِّمت أصلاً بلا أي تغيير هيكلي — فقط جسم الدوال هنا صار حقيقياً.
class SyncService {
  SyncService._();

  static const bool isCloudSyncImplemented = true;

  static Future<String> getLastSyncLabel() async {
    final raw = await AppPreferences.getString(AppPreferences.keyLastSyncAt);
    if (raw.isEmpty) return 'لم تتم أي مزامنة بعد';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('yyyy/MM/dd — HH:mm', 'ar').format(date);
  }

  static Future<List<String>> getLinkedDevices() async {
    // لا يوجد نظام ربط أجهزة فعلي بعد؛ قائمة فارغة بشكل صادق حتى تُبنى
    // آلية تسجيل الأجهزة الحقيقية مع الخدمة السحابية.
    return const [];
  }

  /// عدد الفنادق المحلية التي بها تعديلات لم تُرفَع للسحابة بعد.
  static Future<int> getPendingCount() async {
    final db = await DatabaseService().database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM hotels WHERE pending_sync = 1');
    return (result.first['c'] as int?) ?? 0;
  }

  static Future<String> getLastSyncLog() async {
    return AppPreferences.getString(AppPreferences.keySyncLog);
  }

  static Future<void> _appendLog(String line) async {
    final existing = await AppPreferences.getString(AppPreferences.keySyncLog);
    final stamp = DateFormat('yyyy/MM/dd HH:mm', 'ar').format(DateTime.now());
    final entries = existing.isEmpty ? <String>[] : existing.split('\n');
    entries.insert(0, '[$stamp] $line');
    await AppPreferences.setString(AppPreferences.keySyncLog, entries.take(50).join('\n'));
  }

  /// مزامنة الآن — تُشغِّل [HotelSyncService.sync] فعلياً، وتُحدِّث وقت آخر
  /// مزامنة والسجل عند النجاح أو الفشل معاً. لا تُلقي أي استثناء أبداً —
  /// تعيد رسالة نصية جاهزة للعرض مباشرة في الواجهة (نفس عقد الواجهة القديم).
  static Future<String> syncNow() async {
    final result = await HotelSyncService.sync();

    if (!result.isSuccess) {
      await _appendLog('فشل: ${result.error}');
      return result.error!;
    }

    await AppPreferences.setString(AppPreferences.keyLastSyncAt, DateTime.now().toIso8601String());
    final buffer = StringBuffer('تمت المزامنة: ${result.pushed} فندق مرفوع، ${result.pulled} فندق مُحدَّث محلياً.');
    if (result.skippedNewHotels > 0) {
      buffer.write(
        ' تعذّر رفع ${result.skippedNewHotels} فندق جديد — الفنادق الجديدة تُنشَأ في الخدمة السحابية عبر لوحة التحكم أولاً.',
      );
    }
    final message = buffer.toString();
    await _appendLog(message);
    return message;
  }
}
