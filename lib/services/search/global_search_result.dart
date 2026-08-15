import 'package:flutter/widgets.dart';

/// نتيجة بحث واحدة — [onTap] يفتح الشاشة الأصلية نفسها مباشرة (وليس نسخة
/// مبسَّطة)، بالضبط كما لو ضغط المستخدم على العنصر من شاشته المعتادة؛ كل
/// مزوّد بحث يبني هذا الاستدعاء بنفسه (البيانات اللازمة already في نطاقه
/// عند بناء النتيجة)، فلا حاجة لسجل توجيه عام (route registry) منفصل.
class GlobalSearchResult {
  final String moduleKey;
  final String title;
  final String? subtitle;
  final String? relatedHotelName;
  final void Function(BuildContext context) onTap;

  const GlobalSearchResult({
    required this.moduleKey,
    required this.title,
    this.subtitle,
    this.relatedHotelName,
    required this.onTap,
  });
}
