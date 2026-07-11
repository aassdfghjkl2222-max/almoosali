import '../core/database/database_service.dart';
import '../models/financial_report.dart';

class FinancialRepository {
  final DatabaseService _dbService = DatabaseService();

  Future<int> addFinancialReport(FinancialReport report) async {
    return await _dbService.insertFinancialReport(report.toMap());
  }

  Future<List<FinancialReport>> getFinancialReports(int? hotelId) async {
    if (hotelId == null) return [];
    final List<Map<String, dynamic>> maps = await _dbService.getFinancialReports(hotelId: hotelId);
    return maps.map((map) => FinancialReport.fromMap(map)).toList();
  }

  Future<List<FinancialReport>> getUnpostedReports(int hotelId) async {
    final List<Map<String, dynamic>> maps = await _dbService.getUnpostedReports(hotelId);
    return maps.map((map) => FinancialReport.fromMap(map)).toList();
  }

  Future<FinancialReport?> getMainReportForDate(int hotelId, String date) async {
    final map = await _dbService.getMainReportForDate(hotelId, date);
    return map != null ? FinancialReport.fromMap(map) : null;
  }

  Future<List<FinancialReport>> getFinancialReportsInRange({
    required int? hotelId,
    required String startDate,
    required String endDate,
  }) async {
    if (hotelId == null) return [];
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'financial_reports',
      where: 'hotel_id = ? AND date >= ? AND date <= ?',
      whereArgs: [hotelId, startDate, endDate],
      orderBy: 'date ASC',
    );
    return maps.map((map) => FinancialReport.fromMap(map)).toList();
  }

  Future<int> updateFinancialReport(FinancialReport report) async {
    if (report.id == null) return 0;
    return await _dbService.updateById('financial_reports', report.toMap(), report.id!);
  }

  Future<int> deleteFinancialReport(int id) async {
    return await _dbService.deleteById('financial_reports', id);
  }
}
