import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/expenses/pending_expenses_list_page.dart';
import '../../../repositories/expense_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

/// لا شاشة تفاصيل مستقلة لمصروف معلَّق واحد — النتيجة تفتح قائمة المصروفات
/// المعلَّقة لفندقه (المكان الذي يظهر فيه فعلياً).
class PendingExpensesSearchProvider implements GlobalSearchProvider {
  final _repository = ExpenseRepository();

  @override
  String get moduleKey => 'pending_expenses';
  @override
  String get moduleLabel => 'المصروفات المعلَّقة';
  @override
  IconData get moduleIcon => Icons.receipt_long_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final expenses = await _repository.getAllPendingExpensesAcrossHotels();
    final hotelById = {for (final h in allHotels) if (h.id != null) h.id!: h};

    final matches = expenses.where((e) =>
        globalSearchMatches(e.statement, normalizedQuery) ||
        globalSearchMatches(e.notes, normalizedQuery) ||
        globalSearchMatches(e.categoryName, normalizedQuery));

    final results = <GlobalSearchResult>[];
    for (final e in matches) {
      final hotel = hotelById[e.hotelId];
      if (hotel == null) continue;
      results.add(GlobalSearchResult(
        moduleKey: moduleKey,
        title: e.statement,
        subtitle: e.categoryName,
        relatedHotelName: hotel.arabicName,
        onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => PendingExpensesListPage(hotel: hotel))),
      ));
    }
    return results;
  }
}
