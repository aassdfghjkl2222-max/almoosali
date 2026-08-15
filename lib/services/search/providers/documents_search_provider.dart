import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/dashboard/pages/hotel_document_edit_page.dart';
import '../../../repositories/document_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

class DocumentsSearchProvider implements GlobalSearchProvider {
  final _repository = DocumentRepository();

  @override
  String get moduleKey => 'documents';
  @override
  String get moduleLabel => 'المستندات';
  @override
  IconData get moduleIcon => Icons.folder_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final documents = await _repository.getAllDocuments();
    final hotelById = {for (final h in allHotels) if (h.id != null) h.id!: h};

    final matches = documents.where((d) =>
        globalSearchMatches(d.name, normalizedQuery) ||
        globalSearchMatches(d.documentNumber, normalizedQuery) ||
        globalSearchMatches(d.notes, normalizedQuery) ||
        globalSearchMatches(d.typeName, normalizedQuery));

    // HotelDocumentEditPage يتطلب Hotel محدَّداً دائماً — مستند بلا فندق
    // (مشترك) أو فندقه أُرشِف/حُذف لا يمكن فتح شاشة تعديله فعلياً، فيُستبعَد
    // من النتائج بدل عرض عنصر لا يفعل شيئاً عند الضغط عليه.
    final results = <GlobalSearchResult>[];
    for (final d in matches) {
      if (d.hotelId == null) continue;
      final hotel = hotelById[d.hotelId];
      if (hotel == null) continue;
      results.add(GlobalSearchResult(
        moduleKey: moduleKey,
        title: d.name,
        subtitle: d.typeName ?? d.documentNumber,
        relatedHotelName: d.hotelName ?? hotel.arabicName,
        onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelDocumentEditPage(hotel: hotel, document: d))),
      ));
    }
    return results;
  }
}
