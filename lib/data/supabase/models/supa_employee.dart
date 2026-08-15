/// يطابق جدول `employees` — راجع
/// supabase/migrations/20260730000004_phase4_people_and_contracts.sql.
/// employee_number يُولَّد تلقائياً بواسطة قاعدة البيانات (تسلسل)، لا يُرسَل
/// عند الإنشاء أبداً.
class SupaEmployee {
  static const statusActive = 'active';
  static const statusSuspended = 'suspended';
  static const statusResigned = 'resigned';
  static const statusTerminated = 'terminated';

  final String? id;
  final String hotelId;
  final String? employeeNumber;
  final String name;
  final String position;
  final double salary;
  final String hiredAt;
  final String? phone;
  final String status;
  final String? notes;
  final String? archivedAt;
  final String? createdAt;
  final String? updatedAt;

  const SupaEmployee({
    this.id,
    required this.hotelId,
    this.employeeNumber,
    required this.name,
    required this.position,
    required this.salary,
    required this.hiredAt,
    this.phone,
    this.status = statusActive,
    this.notes,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  Map<String, dynamic> toInsertMap() => {
        'hotel_id': hotelId,
        'name': name,
        'position': position,
        'salary': salary,
        'hired_at': hiredAt,
        'phone': phone,
        'status': status,
        'notes': notes,
      };

  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'position': position,
        'salary': salary,
        'phone': phone,
        'status': status,
        'notes': notes,
      };

  factory SupaEmployee.fromMap(Map<String, dynamic> map) {
    return SupaEmployee(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      employeeNumber: map['employee_number'] as String?,
      name: map['name'] as String,
      position: map['position'] as String,
      salary: (map['salary'] as num).toDouble(),
      hiredAt: map['hired_at'] as String,
      phone: map['phone'] as String?,
      status: map['status'] as String? ?? statusActive,
      notes: map['notes'] as String?,
      archivedAt: map['archived_at'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}

class SupaEmployeeEvent {
  final String? id;
  final String employeeId;
  final String hotelId;
  final String eventType;
  final String eventDate;
  final String? reason;
  final String? oldValue;
  final String? newValue;

  const SupaEmployeeEvent({
    this.id,
    required this.employeeId,
    required this.hotelId,
    required this.eventType,
    required this.eventDate,
    this.reason,
    this.oldValue,
    this.newValue,
  });

  Map<String, dynamic> toInsertMap() => {
        'employee_id': employeeId,
        'hotel_id': hotelId,
        'event_type': eventType,
        'event_date': eventDate,
        'reason': reason,
        'old_value': oldValue,
        'new_value': newValue,
      };

  factory SupaEmployeeEvent.fromMap(Map<String, dynamic> map) {
    return SupaEmployeeEvent(
      id: map['id'] as String?,
      employeeId: map['employee_id'] as String,
      hotelId: map['hotel_id'] as String,
      eventType: map['event_type'] as String,
      eventDate: map['event_date'] as String,
      reason: map['reason'] as String?,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
    );
  }
}
