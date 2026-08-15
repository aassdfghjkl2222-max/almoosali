import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/settings/about_page.dart';
import '../../../pages/settings/ai_invoice_ocr_settings_page.dart';
import '../../../pages/settings/data_info_page.dart';
import '../../../pages/settings/hotel_management_page.dart';
import '../../../pages/settings/settings_page.dart';
import '../../../pages/settings/support_page.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

/// فهرس ثابت (بلا قاعدة بيانات) لأقسام الإعدادات — يسمح بالوصول المباشر
/// لأي قسم عبر اسمه دون تصفّح شاشة الإعدادات يدوياً. أضف سطراً واحداً هنا
/// عند إضافة قسم إعدادات جديد مستقبلاً.
class SettingsSearchProvider implements GlobalSearchProvider {
  @override
  String get moduleKey => 'settings';
  @override
  String get moduleLabel => 'الإعدادات';
  @override
  IconData get moduleIcon => Icons.settings_outlined;

  late final List<({String title, String subtitle, WidgetBuilder builder})> _entries = [
    (title: 'الأمان', subtitle: 'الرمز السري، البصمة، إخفاء الأرصدة', builder: (_) => const SettingsPage()),
    (title: 'إدارة الفنادق', subtitle: 'إضافة وتعديل وأرشفة الفنادق', builder: (_) => const HotelManagementPage()),
    (title: 'المظهر', subtitle: 'الوضع الداكن، حجم الخط، سرعة الحركة', builder: (_) => const SettingsPage()),
    (title: 'الإشعارات', subtitle: 'تفعيل الإشعارات والصوت والاهتزاز', builder: (_) => const SettingsPage()),
    (title: 'معلومات البيانات المخزَّنة', subtitle: 'حجم قاعدة البيانات وعدد السجلات', builder: (_) => const DataInfoPage()),
    (title: 'الذكاء الاصطناعي لقراءة الفواتير', subtitle: 'اختيار المزوّد ومفتاح API', builder: (_) => const AiInvoiceOcrSettingsPage()),
    (title: 'وضع التدريب', subtitle: 'بدء/إنهاء وضع التدريب', builder: (_) => const SettingsPage()),
    (title: 'الدعم والمساعدة', subtitle: 'الأسئلة الشائعة والإبلاغ عن مشكلة', builder: (_) => const SupportPage()),
    (title: 'حول التطبيق', subtitle: 'الإصدار ومعلومات الشركة', builder: (_) => const AboutPage()),
  ];

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    return _entries
        .where((e) => globalSearchMatches(e.title, normalizedQuery) || globalSearchMatches(e.subtitle, normalizedQuery))
        .map((e) => GlobalSearchResult(
              moduleKey: moduleKey,
              title: e.title,
              subtitle: e.subtitle,
              onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: e.builder)),
            ))
        .toList();
  }
}
