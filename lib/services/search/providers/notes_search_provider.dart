import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/notes/notes_page.dart';
import '../../../repositories/note_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

class NotesSearchProvider implements GlobalSearchProvider {
  final _repository = NoteRepository();

  @override
  String get moduleKey => 'notes';
  @override
  String get moduleLabel => 'الملاحظات';
  @override
  IconData get moduleIcon => Icons.sticky_note_2_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final notes = await _repository.getAllNotesAcrossHotels();
    final hotelById = {for (final h in allHotels) if (h.id != null) h.id!: h};

    final matches = notes.where((n) => globalSearchMatches(n.title, normalizedQuery) || globalSearchMatches(n.content, normalizedQuery));

    final results = <GlobalSearchResult>[];
    for (final n in matches) {
      final hotel = hotelById[n.hotelId];
      if (hotel == null) continue;
      results.add(GlobalSearchResult(
        moduleKey: moduleKey,
        title: n.title,
        subtitle: n.content,
        relatedHotelName: hotel.arabicName,
        onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => NotesPage(hotel: hotel))),
      ));
    }
    return results;
  }
}
