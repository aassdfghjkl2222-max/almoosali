import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/invoices/invoice_details_page.dart';
import '../../../repositories/invoice_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

class InvoicesSearchProvider implements GlobalSearchProvider {
  final _repository = InvoiceRepository();

  @override
  String get moduleKey => 'invoices';
  @override
  String get moduleLabel => 'الفواتير';
  @override
  IconData get moduleIcon => Icons.request_quote_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final hotelIds = allHotels.where((h) => h.id != null).map((h) => h.id!).toList();
    if (hotelIds.isEmpty) return [];
    final invoices = await _repository.getInvoicesPagedFiltered(hotelIds: hotelIds, limit: 500, offset: 0);
    final hotelById = {for (final h in allHotels) if (h.id != null) h.id!: h};

    final matches = invoices.where((i) =>
        globalSearchMatches(i.invoiceNumber, normalizedQuery) ||
        globalSearchMatches(i.companyName, normalizedQuery) ||
        globalSearchMatches(i.taxNumber, normalizedQuery) ||
        globalSearchMatches(i.expenseCategory, normalizedQuery));

    final results = <GlobalSearchResult>[];
    for (final i in matches) {
      final hotel = hotelById[i.hotelId];
      if (hotel == null) continue;
      results.add(GlobalSearchResult(
        moduleKey: moduleKey,
        title: 'فاتورة ${i.invoiceNumber}',
        subtitle: i.companyName,
        relatedHotelName: hotel.arabicName,
        onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailsPage(hotel: hotel, invoice: i))),
      ));
    }
    return results;
  }
}
