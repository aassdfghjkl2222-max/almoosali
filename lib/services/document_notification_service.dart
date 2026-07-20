import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/app_preferences.dart';
import '../models/document.dart';

/// تنبيهات انتهاء المستندات — محلية بالكامل (بلا خادم)، تُحسَب حياً من
/// expiry_date كل مستند بدل جدول تنبيهات منفصل (لا مشكلة تزامن بين الاثنين
/// عند تعديل/حذف مستند). عتبات ثابتة: 30/10/5/0 يوم قبل الانتهاء — تُجدوَل
/// فقط العتبات المستقبلية (عتبة فات وقتها لا تُجدوَل بأثر رجعي). جدولة غير
/// دقيقة زمنياً ([AndroidScheduleMode.inexactAllowWhileIdle]) عمداً لتفادي
/// حاجة صلاحية "المنبّهات الدقيقة" الخاصة في أندرويد 12+ — دقة اليوم كافية
/// هنا. المنطقة الزمنية ثابتة `Asia/Riyadh` (يطابق `locale: ar_SA` الثابت
/// في main.dart لبقية التطبيق، بلا حاجة لحزمة كشف منطقة زمنية إضافية).
class DocumentNotificationService {
  DocumentNotificationService._();

  static const List<int> _thresholdDays = [30, 10, 5, 0];
  static const _timeZoneName = 'Asia/Riyadh';
  static const _channelId = 'document_expiry';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidSettings));
    _initialized = true;
  }

  /// تُستدعى عند أول تفعيل للإشعارات من الإعدادات — لا تأثير إن كانت
  /// الصلاحية ممنوحة أصلاً أو على أندرويد أقدم من 13 (لا حاجة لها هناك).
  static Future<void> requestPermissionIfNeeded() async {
    await _ensureInitialized();
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  static int _notificationId(int documentId, int thresholdIndex) => documentId * 10 + thresholdIndex;

  static Future<void> cancelForDocument(int documentId) async {
    await _ensureInitialized();
    for (var i = 0; i < _thresholdDays.length; i++) {
      await _plugin.cancel(_notificationId(documentId, i));
    }
  }

  static Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// تُلغي أي تنبيهات سابقة لهذا المستند وتُعيد جدولة كل عتبة مستقبلية —
  /// تُستدعى من DocumentRepository عند كل إنشاء/تعديل/حذف، فتغطي كل شاشات
  /// الإنشاء/التعديل تلقائياً بلا أي استدعاء إضافي متفرّق.
  static Future<void> rescheduleForDocument(Document document) async {
    if (document.id == null) return;
    await cancelForDocument(document.id!);

    final enabled = await AppPreferences.getBool(AppPreferences.keyNotificationsEnabled, defaultValue: true);
    if (!enabled) return;

    final expiry = DateTime.tryParse(document.expiryDate);
    if (expiry == null) return;

    await _ensureInitialized();
    final location = tz.getLocation(_timeZoneName);
    final now = tz.TZDateTime.now(location);
    final title = document.typeName ?? document.name;

    for (var i = 0; i < _thresholdDays.length; i++) {
      final daysBefore = _thresholdDays[i];
      final notifyDate = expiry.subtract(Duration(days: daysBefore));
      final scheduled = tz.TZDateTime(location, notifyDate.year, notifyDate.month, notifyDate.day, 9);
      if (!scheduled.isAfter(now)) continue;

      final body = daysBefore == 0 ? "ينتهي \"$title\" اليوم" : "ينتهي \"$title\" خلال $daysBefore يوماً";

      await _plugin.zonedSchedule(
        _notificationId(document.id!, i),
        "تذكير بانتهاء مستند",
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(_channelId, "تنبيهات انتهاء المستندات", importance: Importance.high, priority: Priority.high),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// مزامنة شاملة لكل مستندات النظام — عند إقلاع التطبيق، أو عند تفعيل/تعطيل
  /// مفتاح الإشعارات من الإعدادات (تعطيل يُلغي الكل بدلاً من إعادة الجدولة).
  static Future<void> rescheduleAll(List<Document> documents) async {
    await _ensureInitialized();
    final enabled = await AppPreferences.getBool(AppPreferences.keyNotificationsEnabled, defaultValue: true);
    if (!enabled) {
      await cancelAll();
      return;
    }
    for (final document in documents) {
      await rescheduleForDocument(document);
    }
  }
}
