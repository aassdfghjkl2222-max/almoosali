import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/document_types/document_types_page.dart';
import '../../../repositories/document_type_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

/// أنواع المستندات مرجع مشترك لكل الفنادق (بلا hotel_id) — لا يوجد شاشة
/// تفاصيل مستقلة لكل نوع، فالنتيجة تفتح شاشة الإدارة نفسها (المكان الوحيد
/// لعرض/تعديل الأنواع، تماماً كالفئات المالية).
class DocumentTypesSearchProvider implements GlobalSearchProvider {
  final _repository = DocumentTypeRepository();

  @override
  String get moduleKey => 'document_types';
  @override
  String get moduleLabel => 'أنواع المستندات';
  @override
  IconData get moduleIcon => Icons.description_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final types = await _repository.getTypes();

    final matches = types.where((t) => globalSearchMatches(t.name, normalizedQuery) || globalSearchMatches(t.description, normalizedQuery));

    return matches
        .map((t) => GlobalSearchResult(
              moduleKey: moduleKey,
              title: t.name,
              subtitle: t.categoryName ?? t.description,
              onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentTypesPage())),
            ))
        .toList();
  }
}
