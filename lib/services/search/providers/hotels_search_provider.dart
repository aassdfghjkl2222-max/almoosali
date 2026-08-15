import 'package:flutter/material.dart';

import '../../../core/app_page_route.dart';
import '../../../core/hotel_session.dart';
import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/dashboard/dashboard_page.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

class HotelsSearchProvider implements GlobalSearchProvider {
  @override
  String get moduleKey => 'hotels';
  @override
  String get moduleLabel => 'الفنادق';
  @override
  IconData get moduleIcon => Icons.apartment_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final matches = allHotels.where((h) =>
        globalSearchMatches(h.arabicName, normalizedQuery) ||
        globalSearchMatches(h.englishName, normalizedQuery) ||
        globalSearchMatches(h.city, normalizedQuery) ||
        globalSearchMatches(h.hotelCode, normalizedQuery) ||
        globalSearchMatches(h.address, normalizedQuery) ||
        globalSearchMatches(h.phone, normalizedQuery) ||
        globalSearchMatches(h.mobile, normalizedQuery));

    return matches
        .map((h) => GlobalSearchResult(
              moduleKey: moduleKey,
              title: h.arabicName,
              subtitle: h.city.isNotEmpty ? h.city : h.hotelCode,
              onTap: (context) {
                HotelSession.current.value = h;
                Navigator.push(context, premiumRoute(DashboardPage(hotel: h)));
              },
            ))
        .toList();
  }
}
