/// حركة واحدة في السجل الوظيفي للموظف — السجل الرسمي والدائم لحياته الوظيفية.
/// هذا الجدول Append-Only: لا يوجد تعديل أو حذف لأي حركة بعد إنشائها.
class EmployeeEvent {
  final int? id;
  final int employeeId;
  final int hotelId;
  final String eventType;
  final String eventDate;
  final String? reason;
  final String? performedBy;
  final String? notes;
  final String? oldValue;
  final String? newValue;
  final String createdAt;

  const EmployeeEvent({
    this.id,
    required this.employeeId,
    required this.hotelId,
    required this.eventType,
    required this.eventDate,
    this.reason,
    this.performedBy,
    this.notes,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });

  static const typeHire = 'hire';
  static const typeSalaryChange = 'salary_change';
  static const typePositionChange = 'position_change';
  static const typeTransfer = 'transfer';
  static const typeSuspend = 'suspend';
  static const typeReturn = 'return';
  static const typePromotion = 'promotion';
  static const typeResignation = 'resignation';
  static const typeTermination = 'termination';
  static const typeAllowanceAdded = 'allowance_added';
  static const typeDeductionAdded = 'deduction_added';
  static const typeArchived = 'archived';

  static String typeLabel(String type) {
    switch (type) {
      case typeHire:
        return 'تعيين';
      case typeSalaryChange:
        return 'تعديل الراتب';
      case typePositionChange:
        return 'تعديل الوظيفة';
      case typeTransfer:
        return 'نقل بين الفنادق';
      case typeSuspend:
        return 'إيقاف مؤقت';
      case typeReturn:
        return 'عودة للعمل';
      case typePromotion:
        return 'ترقية';
      case typeResignation:
        return 'استقالة';
      case typeTermination:
        return 'إنهاء خدمة';
      case typeAllowanceAdded:
        return 'إضافة بدل';
      case typeDeductionAdded:
        return 'إضافة خصم';
      case typeArchived:
        return 'أرشفة';
      default:
        return type;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'hotel_id': hotelId,
      'event_type': eventType,
      'event_date': eventDate,
      'reason': reason,
      'performed_by': performedBy,
      'notes': notes,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': createdAt,
    };
  }

  factory EmployeeEvent.fromMap(Map<String, dynamic> map) {
    return EmployeeEvent(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      hotelId: map['hotel_id'] as int,
      eventType: map['event_type'] as String,
      eventDate: map['event_date'] as String,
      reason: map['reason'] as String?,
      performedBy: map['performed_by'] as String?,
      notes: map['notes'] as String?,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
