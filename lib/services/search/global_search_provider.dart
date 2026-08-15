import 'package:flutter/material.dart';

import '../../models/hotel.dart';
import 'global_search_result.dart';

/// عقد موحَّد لأي وحدة قابلة للبحث الشامل. لإضافة وحدة جديدة مستقبلاً بأقل
/// جهد ممكن: نفِّذ هذا الصنف في ملف جديد داخل providers/، ثم أضِف نسخة منه
/// إلى القائمة الثابتة GlobalSearchService.providers — بلا أي تعديل آخر في
/// أي مكان (لا الصفحة، لا المحرّك نفسه).
abstract class GlobalSearchProvider {
  /// مفتاح ثابت فريد للوحدة (لا يظهر للمستخدم) — يُستخدَم للتجميع.
  String get moduleKey;

  /// الاسم المعروض في عنوان مجموعة النتائج.
  String get moduleLabel;

  IconData get moduleIcon;

  /// [normalizedQuery] مُطبَّع مسبقاً (بلا تشكيل عربي ولا حساسية لحالة
  /// الأحرف) عبر core/text_similarity.dart — لا تُطبِّق أي تطبيع إضافي هنا،
  /// فقط استخدم globalSearchMatches. [allHotels] مُحمَّلة مسبقاً مرة واحدة
  /// لكل جلسة بحث (وليس لكل ضغطة مفتاح) لتفادي استعلام مكرَّر في كل مزوّد.
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels});
}

/// اسم فندق بمعرّفه من القائمة المحمَّلة مسبقاً — null إن كان المعرّف null
/// (بند غير مرتبط بفندق معيّن) أو غير موجود ضمن القائمة (نادراً، فندق حُذف).
String? hotelNameFor(int? hotelId, List<Hotel> allHotels) {
  if (hotelId == null) return null;
  for (final h in allHotels) {
    if (h.id == hotelId) return h.arabicName;
  }
  return null;
}
