import '../core/database/database_service.dart';
import '../core/hotel_visual_identity.dart';
import '../models/hotel.dart';

class HotelRepository {
  final _dbService = DatabaseService();

  Future<List<Hotel>> getAllHotels() async {
    final data = await _dbService.getHotels();
    return data.map((map) => Hotel.fromMap(map)).toList();
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

  Future<int> deleteHotel(int id) async {
    return await _dbService.deleteHotel(id);
  }
}
