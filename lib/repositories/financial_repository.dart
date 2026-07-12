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

  String _fmtDate(DateTime d) => "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Map<String, dynamic> _buildReportsWhere({
    List<int>? hotelIds,
    DateTime? fromDate,
    DateTime? toDate,
    bool? isPosted,
    String? reportType,
    String? employeeName,
    int? reportId,
    String? searchText,
  }) {
    final where = <String>['1=1'];
    final args = <dynamic>[];
    if (hotelIds != null && hotelIds.isNotEmpty) {
      where.add('fr.hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})');
      args.addAll(hotelIds);
    }
    if (fromDate != null) {
      where.add('fr.date >= ?');
      args.add(_fmtDate(fromDate));
    }
    if (toDate != null) {
      where.add('fr.date <= ?');
      args.add(_fmtDate(toDate));
    }
    if (isPosted != null) {
      where.add('fr.is_posted = ?');
      args.add(isPosted ? 1 : 0);
    }
    if (reportType != null) {
      where.add('fr.report_type = ?');
      args.add(reportType);
    }
    if (employeeName != null) {
      where.add('fr.employee_name = ?');
      args.add(employeeName);
    }
    if (reportId != null) {
      where.add('fr.id = ?');
      args.add(reportId);
    }
    if (searchText != null && searchText.trim().isNotEmpty) {
      where.add('(h.arabic_name LIKE ? OR fr.date LIKE ?)');
      args.add('%$searchText%');
      args.add('%$searchText%');
    }
    return {'where': where.join(' AND '), 'args': args};
  }

  /// استعلام مُصفَّى ومُقسَّم على صفحات (Pagination) عبر كل الفنادق — يُستخدم في
  /// قسم "التقارير" داخل مركز التحليل، ولا يوجد استعلام مشابه في مكان آخر من التطبيق
  /// (بقية الشاشات مقصورة على فندق واحد وتحمّل كل النتائج دفعة واحدة).
  Future<List<FinancialReport>> getReportsFiltered({
    List<int>? hotelIds,
    DateTime? fromDate,
    DateTime? toDate,
    bool? isPosted,
    String? reportType,
    String? employeeName,
    int? reportId,
    String? searchText,
    int limit = 25,
    int offset = 0,
  }) async {
    final db = await _dbService.database;
    final built = _buildReportsWhere(
      hotelIds: hotelIds,
      fromDate: fromDate,
      toDate: toDate,
      isPosted: isPosted,
      reportType: reportType,
      employeeName: employeeName,
      reportId: reportId,
      searchText: searchText,
    );
    final rows = await db.rawQuery(
      '''
      SELECT fr.* FROM financial_reports fr
      JOIN hotels h ON h.id = fr.hotel_id
      WHERE ${built['where']}
      ORDER BY fr.date DESC, fr.id DESC
      LIMIT ? OFFSET ?
      ''',
      [...(built['args'] as List), limit, offset],
    );
    return rows.map((e) => FinancialReport.fromMap(e)).toList();
  }

  Future<int> countReportsFiltered({
    List<int>? hotelIds,
    DateTime? fromDate,
    DateTime? toDate,
    bool? isPosted,
    String? reportType,
    String? employeeName,
  }) async {
    final db = await _dbService.database;
    final built = _buildReportsWhere(
      hotelIds: hotelIds,
      fromDate: fromDate,
      toDate: toDate,
      isPosted: isPosted,
      reportType: reportType,
      employeeName: employeeName,
    );
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM financial_reports fr JOIN hotels h ON h.id = fr.hotel_id WHERE ${built['where']}',
      built['args'] as List,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// إجمالي الإيرادات والمصروفات عبر الفنادق المختارة خلال فترة — يُستخدم في
  /// بطاقات الملخص ومقارنة الفترات داخل قسم "التحليل المالي".
  Future<Map<String, double>> getTotals({
    required List<int> hotelIds,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (hotelIds.isEmpty) return {'income': 0, 'expenses': 0};
    final db = await _dbService.database;
    final where = <String>['hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})'];
    final args = <dynamic>[...hotelIds];
    if (fromDate != null) {
      where.add('date >= ?');
      args.add(_fmtDate(fromDate));
    }
    if (toDate != null) {
      where.add('date <= ?');
      args.add(_fmtDate(toDate));
    }
    final result = await db.rawQuery(
      'SELECT SUM(income) as inc, SUM(expenses) as exp FROM financial_reports WHERE ${where.join(' AND ')}',
      args,
    );
    return {
      'income': (result.first['inc'] as num?)?.toDouble() ?? 0,
      'expenses': (result.first['exp'] as num?)?.toDouble() ?? 0,
    };
  }

  /// كل صفوف التقارير (بما فيها details_json) عبر عدة فنادق خلال فترة — تُستخدم
  /// لتفصيل الإيرادات حسب الفندق/الشهر/اليوم/النوع/المصدر داخل "التحليل المالي".
  Future<List<FinancialReport>> getReportsInRangeMultiHotel({
    required List<int> hotelIds,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (hotelIds.isEmpty) return [];
    final db = await _dbService.database;
    final where = <String>['hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})'];
    final args = <dynamic>[...hotelIds];
    if (fromDate != null) {
      where.add('date >= ?');
      args.add(_fmtDate(fromDate));
    }
    if (toDate != null) {
      where.add('date <= ?');
      args.add(_fmtDate(toDate));
    }
    final rows = await db.query('financial_reports', where: where.join(' AND '), whereArgs: args, orderBy: 'date ASC');
    return rows.map((e) => FinancialReport.fromMap(e)).toList();
  }

  /// أسماء الموظفين الموجودة فعلياً داخل بيانات التقارير المحفوظة (قد تكون
  /// فارغة إن لم يكن أي تقرير مرتبطاً باسم موظف بعد) — لا تُقرأ من جدول
  /// الموظفين لأن ذلك سيقترح أسماء لا ترتبط عملياً بأي تقرير.
  Future<List<String>> getDistinctReportEmployeeNames({List<int>? hotelIds}) async {
    final db = await _dbService.database;
    final where = <String>["employee_name IS NOT NULL", "employee_name != ''"];
    final args = <dynamic>[];
    if (hotelIds != null && hotelIds.isNotEmpty) {
      where.add('hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})');
      args.addAll(hotelIds);
    }
    final rows = await db.rawQuery(
      'SELECT DISTINCT employee_name FROM financial_reports WHERE ${where.join(' AND ')} ORDER BY employee_name ASC',
      args,
    );
    return rows.map((e) => e['employee_name'] as String).toList();
  }
}
