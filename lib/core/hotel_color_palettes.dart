import 'package:flutter/material.dart';

/// لوحة ألوان فاخرة جاهزة لاختيار هوية الفندق — راجع HotelWizardPage. القيم
/// ثابتة الآن (15 خياراً)، لكن القائمة قابلة للتوسعة مستقبلاً بلا أي تغيير
/// في شكل الاستخدام (مجرد إضافة عناصر جديدة لهذه القائمة).
class HotelColorOption {
  final String name;
  final Color color;
  const HotelColorOption(this.name, this.color);
}

class HotelColorPalettes {
  HotelColorPalettes._();

  static const List<HotelColorOption> all = [
    HotelColorOption('عنابي فاخر', Color(0xFF7A1E2C)),
    HotelColorOption('زمردي ملكي', Color(0xFF0B6E4F)),
    HotelColorOption('ذهبي فاخر', Color(0xFFB8913F)),
    HotelColorOption('أزرق محيطي', Color(0xFF1565C0)),
    HotelColorOption('كحلي عميق', Color(0xFF1A2744)),
    HotelColorOption('أسود منتصف الليل', Color(0xFF1C1B1A)),
    HotelColorOption('أخضر الغابة', Color(0xFF1B4332)),
    HotelColorOption('أحمر ياقوتي', Color(0xFFB01030)),
    HotelColorOption('شامبانيا', Color(0xFFC9A66B)),
    HotelColorOption('نحاسي برونزي', Color(0xFFB56B45)),
    HotelColorOption('رملي صحراوي', Color(0xFFC2A878)),
    HotelColorOption('بنفسجي ملكي', Color(0xFF5B2C83)),
    HotelColorOption('فحمي', Color(0xFF36454F)),
    HotelColorOption('لؤلؤي أبيض', Color(0xFFE8E6E1)),
    HotelColorOption('أزرق ياقوتي (سفير)', Color(0xFF0F52BA)),
  ];

  static const int defaultColorValue = 0xFF7A1E2C;

  /// أقرب اسم مطابق للون مخزَّن (للعرض فقط) — إن لم يطابق أي خيار جاهز حرفياً
  /// (كالألوان القديمة المخصَّصة قبل هذه اللوحة) يُعرض "مخصَّص" بدل اسم خاطئ.
  static String nameForValue(int? value) {
    if (value == null) return 'مخصَّص';
    for (final o in all) {
      if (o.color.toARGB32() == value) return o.name;
    }
    return 'مخصَّص';
  }
}

/// حالة الفندق التشغيلية — راجع Hotel.status. أرشفة الفندق ('archived') لها
/// مسارها الخاص بالكامل (HotelRepository.archiveHotel) ولا تُختار يدوياً من
/// هذه القائمة داخل نموذج التعديل العادي.
class HotelStatusInfo {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  const HotelStatusInfo(this.value, this.label, this.color, this.icon);
}

class HotelStatuses {
  HotelStatuses._();

  static const active = HotelStatusInfo('active', 'نشط', Color(0xFF0B7A47), Icons.check_circle_rounded);
  static const inactive = HotelStatusInfo('inactive', 'غير نشط', Color(0xFF757575), Icons.pause_circle_rounded);
  static const maintenance = HotelStatusInfo('maintenance', 'تحت الصيانة', Color(0xFFD18B00), Icons.build_circle_rounded);
  static const openingSoon = HotelStatusInfo('opening_soon', 'قريباً', Color(0xFF1565C0), Icons.schedule_rounded);
  static const archived = HotelStatusInfo('archived', 'مؤرشَف', Color(0xFFB0413E), Icons.archive_rounded);

  /// القابلة للاختيار من نموذج التعديل العادي فقط (الأرشفة مسار مستقل).
  static const List<HotelStatusInfo> selectable = [active, inactive, maintenance, openingSoon];

  static const List<HotelStatusInfo> all = [active, inactive, maintenance, openingSoon, archived];

  static HotelStatusInfo fromValue(String value) {
    return all.firstWhere((s) => s.value == value, orElse: () => active);
  }
}
