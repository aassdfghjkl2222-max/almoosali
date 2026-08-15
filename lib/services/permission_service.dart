import '../models/user.dart';
import '../repositories/user_repository.dart';
import 'session_service.dart';

/// نقطة الفحص المركزية الوحيدة لصلاحيات المستخدم الحالي — تُستهلَك من الواجهة
/// (حجب أزرار/تنقّل) ومن الـ Repositories (فحص قبل التنفيذ الفعلي). راجع خطة
/// تنفيذ نظام المستخدمين للسبب المعماري الكامل.
///
/// لا يوجد مستخدم محمَّل = وضع PIN التقليدي بلا تفعيل تعدد المستخدمين بعد،
/// فتُعامَل كصلاحية كاملة (نفس سلوك التطبيق قبل هذه الميزة تماماً — بلا كسر
/// لأي تنصيب لم يُفعِّلها).
class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  final _userRepository = UserRepository();

  Set<int> _hotelIds = {};

  /// كل عنصر بصيغة "code|hotelId" أو "code|*" (منح عبر كل الفنادق المصرَّح بها).
  Set<String> _grants = {};

  User? get _currentUser => SessionService.instance.currentUser;

  bool get isManager => _currentUser?.isManager ?? false;

  bool get _noUserLoaded => _currentUser == null;

  /// يُستدعى بعد كل دخول ناجح، وبعد أي تعديل على صلاحيات/وصول المستخدم
  /// الحالي نفسه (راجع البند 14 من المتطلبات: لا حاجة لإعادة تثبيت التطبيق).
  Future<void> loadForCurrentUser() async {
    final user = _currentUser;
    if (user == null || user.id == null || user.isManager) {
      _hotelIds = {};
      _grants = {};
      return;
    }
    final hotelIds = await _userRepository.getUserHotelIds(user.id!);
    final permissions = await _userRepository.getUserPermissions(user.id!);
    _hotelIds = hotelIds.toSet();
    _grants = permissions.map((p) {
      final hotelId = p['hotel_id'] as int?;
      return '${p['permission_code']}|${hotelId ?? '*'}';
    }).toSet();
  }

  void clear() {
    _hotelIds = {};
    _grants = {};
  }

  bool hasPermission(String code, {int? hotelId}) {
    if (_noUserLoaded || isManager) return true;
    // منح "لكل الفنادق المصرَّح بها" (hotel_id=NULL) يجب ألا يتجاوز قائمة
    // الفنادق الفعلية المصرَّح بها للمستخدم — وإلا أصبح موظف بصلاحية على فندق
    // واحد فقط قادراً على تنفيذ نفس الفعل داخل فندق آخر لم يُمنَح الوصول إليه
    // إطلاقاً. وُجدت هذه الثغرة فعلياً أثناء اختبار السيناريو الكامل.
    if (hotelId != null && !canAccessHotel(hotelId)) return false;
    if (_grants.contains('$code|*')) return true;
    if (hotelId != null && _grants.contains('$code|$hotelId')) return true;
    return false;
  }

  bool canAccessHotel(int hotelId) {
    if (_noUserLoaded || isManager) return true;
    return _hotelIds.contains(hotelId);
  }

  /// الفنادق المصرَّح بها لمستخدم غير مدير — null تعني "بلا قيد" (مدير أو
  /// وضع PIN بلا تفعيل تعدد مستخدمين)، وليس "صفر فنادق".
  Set<int>? get allowedHotelIds => (_noUserLoaded || isManager) ? null : _hotelIds;
}
