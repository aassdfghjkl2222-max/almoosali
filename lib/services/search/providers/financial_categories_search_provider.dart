import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/settings/financial_categories_page.dart';
import '../../../repositories/financial_category_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

class FinancialCategoriesSearchProvider implements GlobalSearchProvider {
  final _repository = FinancialCategoryRepository();

  @override
  String get moduleKey => 'financial_categories';
  @override
  String get moduleLabel => 'الفئات المالية';
  @override
  IconData get moduleIcon => Icons.category_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final categories = await _repository.getAllCategories();

    final matches = categories.where((c) =>
        globalSearchMatches(c.name, normalizedQuery) ||
        globalSearchMatches(c.code, normalizedQuery) ||
        globalSearchMatches(c.description, normalizedQuery));

    return matches
        .map((c) => GlobalSearchResult(
              moduleKey: moduleKey,
              title: c.name,
              subtitle: c.isRevenue ? 'فئة إيراد' : 'فئة مصروف',
              onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialCategoriesPage())),
            ))
        .toList();
  }
}
