import '../core/database/database_service.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final _dbService = DatabaseService();

  Future<int> addSupplier(Supplier supplier) async {
    return await _dbService.insertSupplier(supplier.toMap());
  }

  Future<Supplier?> getSupplierByOfficialName(int hotelId, String name) async {
    final map = await _dbService.getSupplierByOfficialName(hotelId, name);
    if (map == null) return null;
    return Supplier.fromMap(map);
  }

  Future<List<Supplier>> searchSuppliers(int hotelId, String query) async {
    final results = await _dbService.searchSuppliers(hotelId, query);
    return results.map((e) => Supplier.fromMap(e)).toList();
  }
}
