import '../core/database/database_service.dart';
import '../core/hotel_visual_identity.dart';
import '../models/hotel.dart';

class HotelRepository {
  final _dbService = DatabaseService();

  /// كل الفنادق (مؤرشَفة وغير مؤرشَفة معاً) — يبقى بلا تغيير لأي استخدام
  /// يحتاج تحليل بيانات تاريخية (تسوية/تقرير قديم) قد يشير لفندق أُرشِف لاحقاً.
  Future<List<Hotel>> getAllHotels() async {
    final data = await _dbService.getHotels();
    return data.map((map) => Hotel.fromMap(map)).toList();
  }

  /// الفنادق النشطة فقط (غير المؤرشَفة) — لقائمة الفنادق الرئيسية.
  Future<List<Hotel>> getActiveHotels() async {
    final data = await _dbService.getHotels(active: true);
    return data.map((map) => Hotel.fromMap(map)).toList();
  }

  /// الفنادق المؤرشَفة فقط — لسلة المحذوفات.
  Future<List<Hotel>> getArchivedHotels() async {
    final data = await _dbService.getHotels(active: false);
    return data.map((map) => Hotel.fromMap(map)).toList();
  }

  /// أرشفة فندق: بلا حذف أي بيانات، فقط يختفي من القائمة الرئيسية ويظهر في
  /// سلة المحذوفات — يمكن استعادته في أي وقت عبر [restoreHotel].
  Future<int> archiveHotel(int id, {required String archivedBy}) async {
    return await _dbService.archiveHotel(id, archivedBy: archivedBy);
  }

  Future<int> restoreHotel(int id) async {
    return await _dbService.restoreHotel(id);
  }

  Future<void> seedData() async {
    final hotels = await getAllHotels();
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

  Future<int> addHotel(Hotel hotel) async {
    // هوية الفندق يجب أن تكون ما اختاره المستخدم فعلياً عند الإضافة.
    // لا نستبدلها هنا أبداً؛ فقط نؤمّن لوناً افتراضياً إن لم يُحدَّد أي لون.
    final hotelWithIdentity = hotel.identityColorValue == null
        ? hotel.copyWith(identityColorValue: HotelVisualIdentity.defaultColorValue)
        : hotel;
    return await _dbService.insertHotel(hotelWithIdentity.toMap());
  }

  Future<int> updateHotel(Hotel hotel) async {
    if (hotel.id == null) return 0;
    return await _dbService.updateHotel(hotel.toMap(), hotel.id!);
  }

  /// حذف نهائي حقيقي — لا رجعة عنه إطلاقاً، يحذف كل البيانات المالية
  /// والتشغيلية المرتبطة بالفندق. لا يُستدعى إلا من RecycleBinPage بعد تأكيد
  /// صريح متعدد المراحل (كلمة تأكيد + رمز PIN) على فندق مؤرشَف مسبقاً فقط.
  Future<int> deleteHotel(int id) async {
    return await _dbService.deleteHotel(id);
  }
}
