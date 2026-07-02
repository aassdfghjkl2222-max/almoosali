import '../models/hotel.dart';

class HotelRepository {
  final List<Hotel> hotels = [
    const Hotel(
      id: "1",
      arabicName: "فندق ذاخر بلازا",
      englishName: "Dhakher Plaza Hotel",
      city: "مكة المكرمة",
      active: true,
    ),
    const Hotel(
      id: "2",
      arabicName: "فندق جوهرة ذاخر",
      englishName: "Jawharat Dhakher Hotel",
      city: "مكة المكرمة",
      active: true,
    ),
  ];
}