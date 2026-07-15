import '../core/database/database_service.dart';
import '../models/employee.dart';
import '../models/employee_allowance.dart';
import '../models/employee_deduction.dart';
import '../models/employee_advance.dart';
import '../models/employee_event.dart';
import '../models/payroll_record.dart';

class EmployeeRepository {
  final _dbService = DatabaseService();

  Future<List<Employee>> getEmployees(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getEmployees(hotelId);
    return data.map((map) => Employee.fromMap(map)).toList();
  }

  Future<List<Employee>> getArchivedEmployees(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getArchivedEmployees(hotelId);
    return data.map((map) => Employee.fromMap(map)).toList();
  }

  /// كل موظفي كل الفنادق — تُستخدم في قسم "مستندات الموظفين" الذي يعرض
  /// ويصفّي عبر كل الفنادق دفعة واحدة، بخلاف بقية دوال هذا المستودع المقيَّدة بفندق واحد.
  Future<List<Employee>> getAllEmployees() async {
    final data = await _dbService.getAllEmployees();
    return data.map((map) => Employee.fromMap(map)).toList();
  }

  Future<Employee?> getEmployeeById(int id) async {
    final map = await _dbService.getEmployeeById(id);
    return map != null ? Employee.fromMap(map) : null;
  }

  Future<int> addEmployee(Employee employee) async {
    return await _dbService.insertEmployee(employee.toMap());
  }

  Future<int> updateEmployee(Employee employee) async {
    if (employee.id == null) return 0;
    return await _dbService.updateById('employees', employee.toMap(), employee.id!);
  }

  /// أرشفة الموظف (لا يوجد حذف نهائي في النظام) مع تسجيل حركة في سجله الوظيفي.
  Future<void> archiveEmployee(int employeeId, EmployeeEvent event) async {
    await _dbService.archiveEmployee(employeeId: employeeId, eventData: event.toMap());
  }

  /// نقل الموظف إلى فندق آخر: نفس السجل، نفس الرقم الوظيفي، تنتقل معه كل بياناته.
  Future<void> transferEmployee(int employeeId, int newHotelId, EmployeeEvent event) async {
    await _dbService.transferEmployee(employeeId: employeeId, newHotelId: newHotelId, eventData: event.toMap());
  }

  /// تغيير حالة الموظف (إيقاف/عودة/استقالة/إنهاء خدمة) مع تسجيل حركة.
  Future<void> changeStatus(int employeeId, String newStatus, EmployeeEvent event) async {
    await _dbService.applyEmployeeStatusChange(employeeId: employeeId, newStatus: newStatus, eventData: event.toMap());
  }

  /// تعديل حقل في بيانات الموظف (الراتب أو الوظيفة) مع تسجيل القيمة القديمة والجديدة.
  Future<void> applyFieldChange(int employeeId, Map<String, dynamic> fieldUpdate, EmployeeEvent event) async {
    await _dbService.applyEmployeeFieldChange(employeeId: employeeId, fieldUpdate: fieldUpdate, eventData: event.toMap());
  }

  // --- سجل الحركة ---
  Future<List<EmployeeEvent>> getEvents(int employeeId) async {
    final data = await _dbService.getEmployeeEvents(employeeId);
    return data.map((map) => EmployeeEvent.fromMap(map)).toList();
  }

  Future<int> addEvent(EmployeeEvent event) async {
    return await _dbService.insertEmployeeEvent(event.toMap());
  }

  /// كل حركات السجل الوظيفي لكل موظفي فندق معيّن (وليس موظفاً واحداً) — تُستخدم
  /// في مركز التحليل لعرض "النقل بين المنشآت"/"الإيقاف" على مستوى الفندق كاملاً.
  Future<List<Map<String, dynamic>>> getEventsForHotel(int? hotelId, {String? eventType}) async {
    if (hotelId == null) return [];
    return await _dbService.getEmployeeEventsByHotel(hotelId, eventType: eventType);
  }

  // --- البدلات ---
  Future<List<EmployeeAllowance>> getAllowances(int employeeId) async {
    final data = await _dbService.getEmployeeAllowances(employeeId);
    return data.map((map) => EmployeeAllowance.fromMap(map)).toList();
  }

  Future<int> addAllowance(EmployeeAllowance allowance) async {
    return await _dbService.insertEmployeeAllowance(allowance.toMap());
  }

  Future<int> deleteAllowance(int id) async {
    return await _dbService.deleteById('employee_allowances', id);
  }

  // --- الخصومات ---
  Future<List<EmployeeDeduction>> getDeductions(int employeeId) async {
    final data = await _dbService.getEmployeeDeductions(employeeId);
    return data.map((map) => EmployeeDeduction.fromMap(map)).toList();
  }

  Future<int> addDeduction(EmployeeDeduction deduction) async {
    return await _dbService.insertEmployeeDeduction(deduction.toMap());
  }

  Future<int> deleteDeduction(int id) async {
    return await _dbService.deleteById('employee_deductions', id);
  }

  // --- السلف ---
  Future<List<EmployeeAdvance>> getAdvances(int employeeId) async {
    final data = await _dbService.getEmployeeAdvances(employeeId);
    return data.map((map) => EmployeeAdvance.fromMap(map)).toList();
  }

  Future<int> addAdvance(EmployeeAdvance advance) async {
    return await _dbService.insertEmployeeAdvance(advance.toMap());
  }

  Future<int> deleteAdvance(int id) async {
    return await _dbService.deleteById('employee_advances', id);
  }

  // --- بيانات التقارير (على مستوى الفندق بالكامل) ---
  Future<List<Map<String, dynamic>>> getAllowancesForHotel(int? hotelId) async {
    if (hotelId == null) return [];
    return await _dbService.getEmployeeAllowancesByHotel(hotelId);
  }

  Future<List<Map<String, dynamic>>> getDeductionsForHotel(int? hotelId) async {
    if (hotelId == null) return [];
    return await _dbService.getEmployeeDeductionsByHotel(hotelId);
  }

  Future<List<Map<String, dynamic>>> getAdvancesForHotel(int? hotelId) async {
    if (hotelId == null) return [];
    return await _dbService.getEmployeeAdvancesByHotel(hotelId);
  }

  // --- الرواتب ---
  Future<List<PayrollRecord>> getPayrollRecords({
    required int? hotelId,
    int? employeeId,
    String? startPeriod,
    String? endPeriod,
  }) async {
    if (hotelId == null) return [];
    final data = await _dbService.getPayrollRecords(
      hotelId: hotelId,
      employeeId: employeeId,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
    );
    return data.map((map) => PayrollRecord.fromMap(map)).toList();
  }

  /// كل سجلات الرواتب لموظف معيّن، بلا قيد فندق (تُستخدم في تبويب الحركة المالية
  /// الذي يعرض تاريخ الموظف الكامل حتى لو تنقّل بين عدة فنادق).
  Future<List<PayrollRecord>> getPayrollRecordsForEmployee(int employeeId) async {
    final data = await _dbService.getPayrollRecordsByEmployee(employeeId);
    return data.map((map) => PayrollRecord.fromMap(map)).toList();
  }

  Future<PayrollRecord?> getLatestPayrollForEmployee(int employeeId) async {
    final map = await _dbService.getLatestPayrollForEmployee(employeeId);
    return map != null ? PayrollRecord.fromMap(map) : null;
  }

  Future<int> approvePayroll(PayrollRecord record, List<int> advanceIdsToSettle) async {
    return await _dbService.approvePayroll(record.toMap(), advanceIdsToSettle);
  }

  Future<int> markPayrollPaid(int payrollId, Map<String, dynamic> paymentData) async {
    return await _dbService.updateById('payroll_records', paymentData, payrollId);
  }
}
