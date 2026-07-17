import '../core/database/database_service.dart';
import '../models/financial_report_item.dart';

class FinancialReportItemRepository {
  final _dbService = DatabaseService();

  Future<List<FinancialReportItem>> getItems({String? type, bool includeHidden = false}) async {
    final data = await _dbService.getFinancialReportItems(type: type, includeHidden: includeHidden);
    return data.map((map) => FinancialReportItem.fromMap(map)).toList();
  }

  /// بحث فوري بالاسم ضمن نوع معيّن — لمنتقي "اختيار بند محفوظ".
  Future<List<FinancialReportItem>> searchItems(String query, {required String type}) async {
    final all = await getItems(type: type, includeHidden: true);
    if (query.trim().isEmpty) return all;
    final q = query.trim();
    return all.where((i) => i.name.contains(q)).toList();
  }

  Future<FinancialReportItem?> getItemByName(String name, String type) async {
    final items = await getItems(type: type, includeHidden: true);
    for (final i in items) {
      if (i.name == name) return i;
    }
    return null;
  }

  Future<int> addItem(FinancialReportItem item) async {
    return await _dbService.insertFinancialReportItem(item.toMap());
  }

  Future<int> updateItem(FinancialReportItem item) async {
    if (item.id == null) return 0;
    return await _dbService.updateById('financial_report_items', item.toMap(), item.id!);
  }

  Future<int> deleteItem(int id) async {
    return await _dbService.deleteById('financial_report_items', id);
  }

  Future<void> updateItemsOrder(List<FinancialReportItem> items) async {
    for (var i = 0; i < items.length; i++) {
      await updateItem(items[i].copyWith(sortOrder: i));
    }
  }
}
