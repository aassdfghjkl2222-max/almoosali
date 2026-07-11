import 'package:flutter/foundation.dart';

import '../models/hotel.dart';

/// الفندق الحالي الذي يتصفّحه المستخدم — المصدر الوحيد للحقيقة الذي
/// يعتمد عليه ثيم التطبيق بأكمله (راجع main.dart).
///
/// يُضبط عند الدخول إلى فندق من HotelsPage، ويُصفَّر عند العودة إليها،
/// فتتبع كل شاشة تُفتح بينهما هوية هذا الفندق تلقائياً دون أي تعديل فيها.
class HotelSession {
  HotelSession._();

  static final ValueNotifier<Hotel?> current = ValueNotifier<Hotel?>(null);
}
