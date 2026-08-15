import 'package:flutter/material.dart';

import '../../../core/text_similarity.dart';
import '../../../models/hotel.dart';
import '../../../pages/employees/employee_details_page.dart';
import '../../../repositories/employee_repository.dart';
import '../global_search_provider.dart';
import '../global_search_result.dart';

class EmployeesSearchProvider implements GlobalSearchProvider {
  final _repository = EmployeeRepository();

  @override
  String get moduleKey => 'employees';
  @override
  String get moduleLabel => 'الموظفون';
  @override
  IconData get moduleIcon => Icons.badge_outlined;

  @override
  Future<List<GlobalSearchResult>> search(String normalizedQuery, {required List<Hotel> allHotels}) async {
    final employees = await _repository.getAllEmployees();
    final hotelById = {for (final h in allHotels) if (h.id != null) h.id!: h};

    final matches = employees.where((e) =>
        globalSearchMatches(e.name, normalizedQuery) ||
        globalSearchMatches(e.position, normalizedQuery) ||
        globalSearchMatches(e.employeeNumber, normalizedQuery) ||
        globalSearchMatches(e.phone, normalizedQuery));

    // فندق مؤرشَف أو محذوف يعني تعذُّر فتح الشاشة الأصلية — تُستبعَد هذه
    // النتيجة كلياً بدل عرض عنصر لا يفعل شيئاً عند الضغط عليه.
    final results = <GlobalSearchResult>[];
    for (final e in matches) {
      final hotel = hotelById[e.hotelId];
      if (hotel == null) continue;
      results.add(GlobalSearchResult(
        moduleKey: moduleKey,
        title: e.name,
        subtitle: e.position,
        relatedHotelName: hotel.arabicName,
        onTap: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetailsPage(hotel: hotel, employee: e))),
      ));
    }
    return results;
  }
}
