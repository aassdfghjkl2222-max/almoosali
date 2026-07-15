import '../../../models/document.dart';
import '../../../models/hotel.dart';

/// نص "اسم الفندق" المعروض لأي مستند حسب نطاقه (hotel_scope) — قاعدة تصميم
/// موحّدة لكل شاشة في محرك المستندات تعرض مستندات عبر أكثر من فندق، حتى لا
/// يتكرر نفس منطق القراءة (كل الفنادق / فنادق محددة / فندق واحد) في كل شاشة.
String documentHotelLabel(Document d, {required List<Hotel> hotels, required Map<int, List<int>> specificHotelLinks}) {
  switch (d.hotelScope) {
    case Document.hotelScopeAll:
      return "كل الفنادق";
    case Document.hotelScopeSpecific:
      final ids = specificHotelLinks[d.id] ?? [];
      final names = hotels.where((h) => ids.contains(h.id)).map((h) => h.arabicName).toList();
      return names.isEmpty ? "فنادق محددة" : names.join('، ');
    default:
      return d.hotelName ?? "—";
  }
}
