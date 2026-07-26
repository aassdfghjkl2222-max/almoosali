import '../core/database/database_service.dart';
import '../core/hotel_visual_identity.dart';
import '../models/hotel.dart';
import '../models/hotel_audit_log.dart';

class HotelRepository {
  final _dbService = DatabaseService();

  /// المصدر الوحيد الموثوق لأي قائمة فنادق تُعرَض للمستخدم للاختيار منها في
  /// أي مكان بالتطبيق (قوائم منسدلة، حوارات اختيار، Autocomplete، بحث،
  /// فلاتر، إحصائيات، تقارير، مصروف/إيراد جديد، خزينة، تحويلات، مستندات،
  /// عقود، موردون، موظفون...) — يستثني الفنادق المؤرشَفة تلقائياً وبصمت.
  /// هذا هو الاسم "البديهي" الذي يكتبه أي مطوّر جديد بلا تفكير، لذا يجب أن
  /// يكون آمناً افتراضياً؛ لا تُضِف فلترة أرشفة يدوية في أي شاشة، استخدم هذه
  /// الدالة مباشرة. راجع [getAllHotelsIncludingArchived] للحالات النادرة
  /// المشروعة التي تحتاج فنادق مؤرشَفة أيضاً (سجل تدقيق، تسوية/فاتورة تاريخية
  /// تُشير لفندق أُرشِف لاحقاً، التحقق من تكرار الاسم/الكود).
  Future<List<Hotel>> getAllHotels() async {
    final data = await _dbService.getHotels(active: true);
    return data.map((map) => Hotel.fromMap(map)).toList();
  }

  /// كل الفنادق (مؤرشَفة وغير مؤرشَفة معاً) — لا تُستخدَم إلا في الحالات
  /// الموثَّقة أعلاه في تعليق [getAllHotels]. أي استخدام جديد لهذه الدالة في
  /// شاشة يختار منها المستخدم فندقاً هو خطأ معماري يُعيد تسريب فنادق مؤرشَفة
  /// للواجهة.
  Future<List<Hotel>> getAllHotelsIncludingArchived() async {
    final data = await _dbService.getHotels();
    return data.map((map) => Hotel.fromMap(map)).toList();
  }

  /// اسم بديل لـ [getAllHotels] فقط لتوضيح النيّة في الشاشات التي تعرض حالات
  /// تشغيلية متعددة (نشط/تحت الصيانة/قريباً) عمداً — نفس البيانات تماماً.
  Future<List<Hotel>> getActiveHotels() => getAllHotels();

  /// الفنادق التشغيلية فعلياً فقط (status = 'active') — لشاشة اختيار الفندق
  /// الرئيسية (HotelsPage) التي يستخدمها الموظفون فعلياً؛ فندق تحت الصيانة أو
  /// "قريباً" لا يجب أن يظهر هناك حتى لو كان غير مؤرشَف.
  Future<List<Hotel>> getOperationalHotels() async {
    final hotels = await getActiveHotels();
    return hotels.where((h) => h.status == 'active').toList();
  }

  /// الفنادق المؤرشَفة فقط — لسلة المحذوفات.
  Future<List<Hotel>> getArchivedHotels() async {
    final data = await _dbService.getHotels(active: false);
    return data.map((map) => Hotel.fromMap(map)).toList();
  }

  /// أرشفة فندق: بلا حذف أي بيانات، فقط يختفي من القائمة الرئيسية ويظهر في
  /// سلة المحذوفات — يمكن استعادته في أي وقت عبر [restoreHotel].
  Future<int> archiveHotel(int id, {required String archivedBy, String? reason}) async {
    final result = await _dbService.archiveHotel(id, archivedBy: archivedBy, reason: reason);
    await _logAuditByName(id, HotelAuditLog.actionArchived, archivedBy, details: reason);
    return result;
  }

  Future<int> restoreHotel(int id, {required String performedBy}) async {
    final result = await _dbService.restoreHotel(id);
    await _logAuditByName(id, HotelAuditLog.actionRestored, performedBy);
    return result;
  }

  Future<void> seedData() async {
    final hotels = await getAllHotelsIncludingArchived();
    if (hotels.isEmpty) {
      await addHotel(const Hotel(
        arabicName: "فندق ذاخر بلازا",
        englishName: "Dhakher Plaza Hotel",
        city: "مكة المكرمة",
        hasParking: true,
      ));
      await addHotel(const Hotel(
        arabicName: "فندق جوهرة ذاخر",
        englishName: "Jawharat Dhakher Hotel",
        city: "مكة المكرمة",
      ));
    }
  }

  Future<int> addHotel(Hotel hotel, {String performedBy = "مدير النظام"}) async {
    // هوية الفندق يجب أن تكون ما اختاره المستخدم فعلياً عند الإضافة.
    // لا نستبدلها هنا أبداً؛ فقط نؤمّن لوناً افتراضياً إن لم يُحدَّد أي لون.
    final hotelWithIdentity = hotel.identityColorValue == null
        ? hotel.copyWith(identityColorValue: HotelVisualIdentity.defaultColorValue)
        : hotel;
    final id = await _dbService.insertHotel(hotelWithIdentity.toMap());
    await _dbService.insertHotelAuditLog(HotelAuditLog(
      hotelId: id,
      hotelName: hotel.arabicName,
      action: HotelAuditLog.actionCreated,
      performedBy: performedBy,
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());
    return id;
  }

  Future<int> updateHotel(Hotel hotel, {String performedBy = "مدير النظام", Hotel? previous}) async {
    if (hotel.id == null) return 0;
    final result = await _dbService.updateHotel(hotel.toMap(), hotel.id!);
    final changedColors = previous != null && previous.identityColorValue != hotel.identityColorValue;
    final changedStatus = previous != null && previous.status != hotel.status;
    await _dbService.insertHotelAuditLog(HotelAuditLog(
      hotelId: hotel.id!,
      hotelName: hotel.arabicName,
      action: changedStatus
          ? HotelAuditLog.actionStatusChanged
          : changedColors
              ? HotelAuditLog.actionColorsChanged
              : HotelAuditLog.actionEdited,
      performedBy: performedBy,
      details: changedStatus ? "${previous.status} ← ${hotel.status}" : null,
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());
    return result;
  }

  /// نسخ فندق قائم — مفيد عند افتتاح فرع جديد بنفس الهوية/الإعدادات. الاسم
  /// الجديد يُلحَق بلاحقة تمييزية والكود الداخلي يُمسَح (يجب أن يبقى فريداً،
  /// راجع [isCodeTaken])، وتبقى الهوية اللونية والإعدادات الأخرى كما هي.
  Future<int> duplicateHotel(Hotel source, {String performedBy = "مدير النظام"}) async {
    final copy = source.copyWith(
      id: null,
      arabicName: "${source.arabicName} (نسخة)",
      englishName: source.englishName.isEmpty ? source.englishName : "${source.englishName} (Copy)",
      hotelCode: null,
      active: true,
      status: 'active',
      archivedAt: null,
      archivedBy: null,
      archiveReason: null,
    );
    final id = await _dbService.insertHotel(copy.toMap());
    await _dbService.insertHotelAuditLog(HotelAuditLog(
      hotelId: id,
      hotelName: copy.arabicName,
      action: HotelAuditLog.actionDuplicated,
      performedBy: performedBy,
      details: "نسخة عن: ${source.arabicName}",
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());
    return id;
  }

  /// حذف نهائي حقيقي — لا رجعة عنه إطلاقاً، يحذف كل البيانات المالية
  /// والتشغيلية المرتبطة بالفندق. لا يُستدعى إلا من RecycleBinPage بعد تأكيد
  /// صريح متعدد المراحل (كلمة تأكيد + سبب + رمز PIN) على فندق مؤرشَف مسبقاً فقط.
  /// سجل التدقيق يُكتب *قبل* الحذف عمداً (بعده لن يبقى شيء يُشير إلى الفندق
  /// سوى هذا السجل نفسه — راجع تعليق جدول hotel_audit_log لماذا لا FOREIGN KEY).
  Future<int> deleteHotel(int id, {required String hotelName, required String performedBy, String? reason}) async {
    await _dbService.insertHotelAuditLog(HotelAuditLog(
      hotelId: id,
      hotelName: hotelName,
      action: HotelAuditLog.actionPermanentlyDeleted,
      performedBy: performedBy,
      details: reason,
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());
    return await _dbService.deleteHotel(id);
  }

  // ---------------- التحقق (Validation) ----------------

  /// هل يوجد فندق آخر بنفس الاسم العربي؟ (بلا حساسية لحالة الأحرف/المسافات
  /// الزائدة) — [excludeId] يُستثنى عند التعديل (الفندق نفسه ليس تكراراً لنفسه).
  /// يشمل الفنادق المؤرشَفة عمداً حتى لا يتكرر الاسم مع فندق قد يُستعاد لاحقاً.
  Future<bool> isNameTaken(String arabicName, {int? excludeId}) async {
    final all = await getAllHotelsIncludingArchived();
    final normalized = arabicName.trim();
    return all.any((h) => h.id != excludeId && h.arabicName.trim() == normalized);
  }

  Future<bool> isCodeTaken(String code, {int? excludeId}) async {
    if (code.trim().isEmpty) return false;
    final all = await getAllHotelsIncludingArchived();
    final normalized = code.trim().toLowerCase();
    return all.any((h) => h.id != excludeId && (h.hotelCode?.trim().toLowerCase() ?? '') == normalized);
  }

  // ---------------- سجل التدقيق ----------------

  Future<List<HotelAuditLog>> getAuditLog({int? hotelId}) async {
    final data = await _dbService.getHotelAuditLog(hotelId: hotelId);
    return data.map((map) => HotelAuditLog.fromMap(map)).toList();
  }

  Future<void> _logAuditByName(int hotelId, String action, String performedBy, {String? details}) async {
    // تُستخدَم هذه الدالة بعد archiveHotel/restoreHotel أحياناً — أي بعد أن
    // يكون الفندق مؤرشَفاً فعلياً في قاعدة البيانات، لذا يجب أن تشمل الفنادق
    // المؤرشَفة حتى لا يُفقَد اسم الفندق من سجل التدقيق.
    final hotels = await getAllHotelsIncludingArchived();
    final matches = hotels.where((h) => h.id == hotelId);
    final hotelName = matches.isEmpty ? "فندق #$hotelId" : matches.first.arabicName;
    await _dbService.insertHotelAuditLog(HotelAuditLog(
      hotelId: hotelId,
      hotelName: hotelName,
      action: action,
      performedBy: performedBy,
      details: details,
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());
  }
}
