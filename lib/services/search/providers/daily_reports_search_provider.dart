import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/financial/financial_summary_page.dart';
import '../../../repositories/financial_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

/// يغطي التقارير المالية اليومية (الإيرادات/المصروفات مجتمعة في تقرير
/// واحد لكل يوم) — يستخدم getReportsFiltered الموجودة أصلاً (بلا نص بحث،
/// فقط حدّ أقصى احترازي) ثم يُطبِّق التطابق المطبَّع بجانب Dart.
class DailyReportsSearchProvider implements GlobalSearchProvider {
  final _repository = FinancialRepository();

  @override
  String get moduleKey => 'daily_reports';
  @override
  String get moduleLabel => 'التقارير اليومية';
  @override
  IconData get moduleIcon => Icons.receipt_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final hotelIds = allHotels.where((h) => h.id != null).map((h) => h.id!).toList();
    if (hotelIds.isEmpty) return [];
    final reports = await _repository.getReportsFiltered(hotelIds: hotelIds, limit: 500);
    final hotelById = {for (final h in allHotels) if (h.id != null) h.id!: h};

    final matches = reports.where((r) =>
        globalSearchMatches(r.notes, normalizedQuery) ||
        globalSearchMatches(r.increaseDesc, normalizedQuery) ||
        globalSearchMatches(r.shortageDesc, normalizedQuery) ||
        globalSearchMatches(r.employeeName, normalizedQuery) ||
        globalSearchMatches(r.date, normalizedQuery));

    final results = <GlobalSearchResult>[];
    for (final r in matches) {
      final hotel = hotelById[r.hotelId];
      if (hotel == null) continue;
      results.add(GlobalSearchResult(
        moduleKey: moduleKey,
        title: 'تقرير ${r.date}',
        subtitle: r.notes ?? r.employeeName,
        relatedHotelName: hotel.arabicName,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FinancialSummaryPage(hotel: hotel, initialDate: DateTime.tryParse(r.date))),
        ),
      ));
    }
    return results;
  }
}
