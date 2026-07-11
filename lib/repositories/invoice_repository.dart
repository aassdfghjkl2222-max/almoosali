import '../core/database/database_service.dart';
import '../models/invoice.dart';

class InvoiceRepository {
  final _dbService = DatabaseService();

  Future<List<Invoice>> getAllInvoices(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getInvoices(hotelId);
    return data.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<int> addInvoice(Invoice invoice) async {
    return await _dbService.insertInvoice(invoice.toMap());
  }

  Future<int> deleteInvoice(int id) async {
    return await _dbService.deleteById('invoices', id);
  }

  Future<int> updateInvoice(Invoice invoice) async {
    if (invoice.id == null) return 0;
    return await _dbService.updateById('invoices', invoice.toMap(), invoice.id!);
  }

  Future<List<Invoice>> getInvoicesBySupplier({
    required int? hotelId,
    required String companyName,
    String? startDate,
    String? endDate,
  }) async {
    if (hotelId == null) return [];
    final data = await _dbService.getInvoicesBySupplier(
      hotelId: hotelId,
      companyName: companyName,
      startDate: startDate,
      endDate: endDate,
    );
    return data.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<List<Invoice>> getFilteredInvoices({
    required int? hotelId,
    String? startDate,
    String? endDate,
  }) async {
    if (hotelId == null) return [];
    final data = await _dbService.getFilteredInvoices(
      hotelId: hotelId,
      startDate: startDate,
      endDate: endDate,
    );
    return data.map((map) => Invoice.fromMap(map)).toList();
  }
}
