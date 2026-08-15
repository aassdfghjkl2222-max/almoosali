import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/invoices/supplier_statement_page.dart';
import '../../../repositories/supplier_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

class SuppliersSearchProvider implements GlobalSearchProvider {
  final _repository = SupplierRepository();

  @override
  String get moduleKey => 'suppliers';
  @override
  String get moduleLabel => 'الموردون';
  @override
  IconData get moduleIcon => Icons.local_shipping_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final suppliers = await _repository.getAllSuppliersAcrossHotels();
    final hotelById = {for (final h in allHotels) if (h.id != null) h.id!: h};

    final matches = suppliers.where((s) =>
        globalSearchMatches(s.officialName, normalizedQuery) ||
        globalSearchMatches(s.shortName, normalizedQuery) ||
        globalSearchMatches(s.taxNumber, normalizedQuery));

    final results = <GlobalSearchResult>[];
    for (final s in matches) {
      final hotel = hotelById[s.hotelId];
      if (hotel == null) continue;
      results.add(GlobalSearchResult(
        moduleKey: moduleKey,
        title: s.officialName,
        subtitle: s.taxNumber,
        relatedHotelName: hotel.arabicName,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SupplierStatementPage(hotel: hotel, companyName: s.officialName)),
        ),
      ));
    }
    return results;
  }
}
