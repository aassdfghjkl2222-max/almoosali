import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_employee.dart';
import '../supabase_config.dart';

class SupaEmployeeRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaEmployee>> getEmployees({required String hotelId, bool includeArchived = false}) async {
    var query = _db.from('employees').select().eq('hotel_id', hotelId);
    if (!includeArchived) query = query.filter('archived_at', 'is', null);
    final rows = await query.order('name');
    return (rows as List).map((m) => SupaEmployee.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaEmployee?> getEmployeeById(String id) async {
    final row = await _db.from('employees').select().eq('id', id).maybeSingle();
    return row == null ? null : SupaEmployee.fromMap(row);
  }

  Future<SupaEmployee> addEmployee(SupaEmployee employee) async {
    final row = await _db.from('employees').insert(employee.toInsertMap()).select().single();
    return SupaEmployee.fromMap(row);
  }

  Future<SupaEmployee> updateEmployee(SupaEmployee employee) async {
    if (employee.id == null) throw ArgumentError('updateEmployee requires an existing employee.id');
    final row = await _db.from('employees').update(employee.toUpdateMap()).eq('id', employee.id!).select().single();
    return SupaEmployee.fromMap(row);
  }

  Future<void> archiveEmployee(String id) async {
    await _db.from('employees').update({'archived_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restoreEmployee(String id) async {
    await _db.from('employees').update({'archived_at': null}).eq('id', id);
  }

  Future<SupaEmployeeEvent> addEvent(SupaEmployeeEvent event) async {
    final row = await _db.from('employee_events').insert(event.toInsertMap()).select().single();
    return SupaEmployeeEvent.fromMap(row);
  }

  Future<List<SupaEmployeeEvent>> getEvents(String employeeId) async {
    final rows = await _db.from('employee_events').select().eq('employee_id', employeeId).order('event_date', ascending: false);
    return (rows as List).map((m) => SupaEmployeeEvent.fromMap(m as Map<String, dynamic>)).toList();
  }
}
