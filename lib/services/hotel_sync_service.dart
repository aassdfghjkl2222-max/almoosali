import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/database/database_service.dart';
import '../data/supabase/supabase_config.dart';
import 'supabase_auth_service.dart';

/// نتيجة تشغيل مزامنة واحدة — يستهلكها [SyncService] لبناء رسالة/سجل نصي
/// للمستخدم دون كشف تفاصيل هذه الطبقة له.
class HotelSyncResult {
  const HotelSyncResult({required this.pushed, required this.pulled, this.skippedNewHotels = 0, this.error});

  final int pushed;
  final int pulled;

  /// عدد الفنادق الجديدة محلياً (بلا cloud_id) التي تعذَّر رفعها — راجع
  /// تعليق [HotelSyncService._push] لسبب هذا القيد البنيوي في المخطط المعتمَد
  /// حالياً (لا سياسة INSERT لـ authenticated على جدول hotels عمداً).
  final int skippedNewHotels;

  /// null يعني نجاح تام. غير null يعني فشل الدورة كاملة (لم يُغيَّر شيء
  /// محلياً ولا سحابياً بعد نقطة الفشل — راجع تعليق [sync] لسبب هذا الترتيب).
  final String? error;

  bool get isSuccess => error == null;
}

/// مزامنة ثنائية الاتجاه لجدول الفنادق فقط (المرحلة التجريبية الأولى —
/// راجع خطة المزامنة). النمط: سحب أولاً ثم رفع، حسم التعارضات بالكتابة
/// الأخيرة تفوز (Last-Write-Wins) بالاعتماد على updated_at.
///
/// هذه الطبقة الوحيدة في التطبيق التي تتحدث مباشرة إلى Supabase لجدول
/// hotels — لا تتصل بها أي شاشة مباشرة، فقط [SyncService].
class HotelSyncService {
  HotelSyncService._();

  static const _table = 'hotels';

  static Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  static Future<HotelSyncResult> sync() async {
    if (!SupabaseConfig.isConfigured) {
      return const HotelSyncResult(pushed: 0, pulled: 0, error: 'الاتصال بالخدمة السحابية غير مُهيَّأ في هذا الإصدار.');
    }
    if (!await _isOnline()) {
      return const HotelSyncResult(pushed: 0, pulled: 0, error: 'لا يوجد اتصال بالإنترنت حالياً.');
    }

    final authError = await SupabaseAuthService.instance.ensureSignedIn();
    if (authError != null) {
      return HotelSyncResult(pushed: 0, pulled: 0, error: authError);
    }
    if (!SupabaseAuthService.instance.isSignedIn) {
      return const HotelSyncResult(
        pushed: 0,
        pulled: 0,
        error: 'لم يتم تسجيل الدخول للخدمة السحابية بعد.',
      );
    }

    try {
      final pulled = await _pull();
      final pushResult = await _push();
      return HotelSyncResult(
        pushed: pushResult.pushed,
        pulled: pulled,
        skippedNewHotels: pushResult.skippedNewHotels,
      );
    } catch (e) {
      return HotelSyncResult(pushed: 0, pulled: 0, error: 'فشلت المزامنة: $e');
    }
  }

  // ------------------------- سحب (Supabase → محلي) -------------------------

  static Future<int> _pull() async {
    final client = SupabaseConfig.client;
    // RLS تُقيِّد النتائج تلقائياً على الفنادق المصرَّح للمستخدم الحالي بها —
    // بلا أي فلترة إضافية هنا.
    final cloudRows = await client.from(_table).select();

    final dbService = DatabaseService();
    final db = await dbService.database;
    var pulledCount = 0;

    for (final cloudRow in cloudRows) {
      final cloudId = cloudRow['id'] as String;
      final cloudUpdatedAt = DateTime.tryParse(cloudRow['updated_at'] as String? ?? '');

      final localMatches = await db.query('hotels', where: 'cloud_id = ?', whereArgs: [cloudId], limit: 1);

      final archivedAt = cloudRow['archived_at'] as String?;
      final partialFields = <String, dynamic>{
        'arabic_name': cloudRow['name_ar'],
        'english_name': cloudRow['name_en'] ?? '',
        'city': cloudRow['city'] ?? '',
        'identity_color_value': cloudRow['identity_color_value'],
        'phone': cloudRow['phone'],
        'mobile': cloudRow['mobile'],
        'whatsapp': cloudRow['whatsapp'],
        'address': cloudRow['address'],
        'archived_at': archivedAt,
        'active': archivedAt == null ? 1 : 0,
        'updated_at': cloudRow['updated_at'],
        'cloud_id': cloudId,
        'pending_sync': 0,
      };

      if (localMatches.isEmpty) {
        // صف جديد كلياً محلياً — لا نسخة محلية سابقة لـ status لنحافظ عليها هنا
        // (خلافاً لمسار التحديث أدناه)، فنشتقّه من archived_at بدل نسخ حالة
        // السحابة الثنائية (active/inactive) حرفياً: فندق مؤرشَف في السحابة
        // يجب أن يحمل status='archived' محلياً منذ أول ظهور له على هذا
        // الجهاز، وإلا ظهر بشارة "غير نشط" الرمادية بدل "مؤرشَف" الحمراء في
        // سلة المحذوفات رغم أن active=0 صحيح فعلاً (راجع HotelStatuses).
        final status = archivedAt != null ? 'archived' : (cloudRow['status'] ?? 'active');
        // insertHotel (وليس db.insert مباشرة) عمداً — يهيّئ الحسابات المالية
        // (financial_accounts) وأنواع المستندات الافتراضية لهذا الفندق تماماً
        // كما لو أُنشئ محلياً عبر HotelRepository.addHotel؛ فندق سُحب من
        // السحابة لأول مرة على هذا الجهاز يحتاج نفس التهيئة بالضبط، وإلا بقيت
        // شاشات الخزينة/المستندات معطوبة له بصمت.
        await dbService.insertHotel({...partialFields, 'status': status});
        pulledCount++;
        continue;
      }

      final local = localMatches.first;
      final localUpdatedAt = DateTime.tryParse(local['updated_at'] as String? ?? '');

      // Last-Write-Wins: لا نُحدِّث محلياً إلا إذا كانت نسخة السحابة أحدث
      // فعلاً من آخر تعديل محلي معروف — تعديل محلي معلَّق (pending_sync=1)
      // أحدث من نسخة السحابة يبقى كما هو هنا وسيفوز عند مرحلة الرفع أدناه.
      final cloudIsNewer = cloudUpdatedAt != null && (localUpdatedAt == null || cloudUpdatedAt.isAfter(localUpdatedAt));
      if (!cloudIsNewer) continue;

      // لا يُلمَس عمود status هنا عمداً — الحفاظ على أي دقة محلية إضافية
      // (صيانة/قريباً) لا يمتلك السحابي معادلاً لها. راجع خطة المزامنة.
      await db.update('hotels', partialFields, where: 'id = ?', whereArgs: [local['id']]);
      pulledCount++;
    }

    return pulledCount;
  }

  // ------------------------- رفع (محلي → Supabase) -------------------------

  static Future<({int pushed, int skippedNewHotels})> _push() async {
    final client = SupabaseConfig.client;
    final db = await DatabaseService().database;
    final pendingRows = await db.query('hotels', where: 'pending_sync = 1');

    var pushedCount = 0;
    var skippedNewCount = 0;
    for (final row in pendingRows) {
      final body = <String, dynamic>{
        'name_ar': row['arabic_name'],
        'name_en': (row['english_name'] as String?)?.isEmpty == true ? null : row['english_name'],
        'city': row['city'],
        'identity_color_value': row['identity_color_value'],
        'phone': row['phone'],
        'mobile': row['mobile'],
        'whatsapp': row['whatsapp'],
        'address': row['address'],
        'status': (row['active'] as int? ?? 1) == 1 ? 'active' : 'inactive',
        'archived_at': row['archived_at'],
      };

      final cloudId = row['cloud_id'] as String?;
      Map<String, dynamic> savedCloudRow;
      try {
        if (cloudId == null) {
          savedCloudRow = await client.from(_table).insert(body).select().single();
        } else {
          savedCloudRow = await client.from(_table).update(body).eq('id', cloudId).select().single();
        }
      } on PostgrestException catch (e) {
        if (cloudId == null && e.code == '42501') {
          // لا سياسة INSERT لـ authenticated على hotels عمداً في المخطط
          // المعتمَد حالياً — إنشاء فندق جديد في السحابة إجراء بصلاحية
          // service role فقط (راجع تعليق hotels_update في ترحيل Phase 1).
          // هذا الفندق يبقى pending_sync=1 وسيُعاد المحاولة في المزامنة
          // القادمة (لن ينجح إلا بعد إنشائه يدوياً في Supabase أولاً).
          skippedNewCount++;
          continue;
        }
        rethrow;
      }

      await db.update(
        'hotels',
        {
          'cloud_id': savedCloudRow['id'],
          'updated_at': savedCloudRow['updated_at'],
          'pending_sync': 0,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      pushedCount++;
    }

    return (pushed: pushedCount, skippedNewHotels: skippedNewCount);
  }
}
