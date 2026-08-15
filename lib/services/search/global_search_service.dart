import '../../core/text_similarity.dart';
import '../../models/hotel.dart';
import 'global_search_provider.dart';
import 'global_search_result.dart';
import 'providers/contracts_search_provider.dart';
import 'providers/daily_reports_search_provider.dart';
import 'providers/document_types_search_provider.dart';
import 'providers/documents_search_provider.dart';
import 'providers/employees_search_provider.dart';
import 'providers/financial_categories_search_provider.dart';
import 'providers/hotels_search_provider.dart';
import 'providers/invoices_search_provider.dart';
import 'providers/notes_search_provider.dart';
import 'providers/pending_expenses_search_provider.dart';
import 'providers/settings_search_provider.dart';
import 'providers/suppliers_search_provider.dart';

class GlobalSearchModuleResults {
  final GlobalSearchProvider provider;
  final List<GlobalSearchResult> results;
  const GlobalSearchModuleResults({required this.provider, required this.results});
}

/// المحرك المركزي للبحث الشامل — يُشغِّل كل مزوّد وحدة بالتوازي (Future.wait)
/// ثم يجمع النتائج غير الفارغة فقط. لإضافة وحدة جديدة: أضِف مزوّداً جديداً
/// (يُنفِّذ GlobalSearchProvider) إلى [providers] هنا فقط — بلا أي تعديل آخر
/// في هذا الملف أو في صفحة البحث.
class GlobalSearchService {
  static final List<GlobalSearchProvider> providers = [
    HotelsSearchProvider(),
    EmployeesSearchProvider(),
    DocumentsSearchProvider(),
    DocumentTypesSearchProvider(),
    ContractsSearchProvider(),
    SuppliersSearchProvider(),
    FinancialCategoriesSearchProvider(),
    PendingExpensesSearchProvider(),
    DailyReportsSearchProvider(),
    InvoicesSearchProvider(),
    NotesSearchProvider(),
    SettingsSearchProvider(),
  ];

  /// [allHotels] يُحمَّل مرة واحدة لكل جلسة بحث (وليس لكل ضغطة مفتاح) من
  /// طرف الصفحة، ويُمرَّر هنا — راجع تعليق GlobalSearchProvider.search.
  Future<List<GlobalSearchModuleResults>> search(String rawQuery, {required List<Hotel> allHotels}) async {
    final query = normalizeForCategoryNameComparison(rawQuery);
    if (query.isEmpty) return [];

    final resultsPerProvider = await Future.wait(providers.map((p) => p.search(query, allHotels: allHotels)));

    final grouped = <GlobalSearchModuleResults>[];
    for (var i = 0; i < providers.length; i++) {
      if (resultsPerProvider[i].isNotEmpty) {
        grouped.add(GlobalSearchModuleResults(provider: providers[i], results: resultsPerProvider[i]));
      }
    }
    return grouped;
  }
}
