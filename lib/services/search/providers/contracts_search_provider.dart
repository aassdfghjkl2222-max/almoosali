import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/contracts/contract_details_page.dart';
import '../../../repositories/contract_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

class ContractsSearchProvider implements GlobalSearchProvider {
  final _repository = ContractRepository();

  @override
  String get moduleKey => 'contracts';
  @override
  String get moduleLabel => 'العقود';
  @override
  IconData get moduleIcon => Icons.assignment_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final contracts = await _repository.getAllContractsAcrossHotels();
    final hotelById = {for (final h in allHotels) if (h.id != null) h.id!: h};

    final matches = contracts.where((c) =>
        globalSearchMatches(c.name, normalizedQuery) ||
        globalSearchMatches(c.contractorName, normalizedQuery) ||
        globalSearchMatches(c.paymentMethod, normalizedQuery));

    final results = <GlobalSearchResult>[];
    for (final c in matches) {
      final hotel = hotelById[c.hotelId];
      if (hotel == null) continue;
      results.add(GlobalSearchResult(
        moduleKey: moduleKey,
        title: c.name,
        subtitle: c.contractorName,
        relatedHotelName: hotel.arabicName,
        onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => ContractDetailsPage(hotel: hotel, contract: c))),
      ));
    }
    return results;
  }
}
