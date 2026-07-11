class Employee {
  final int? id;
  final int? hotelId;
  final String name;
  final String position;
  final double salary;
  final String hiredAt;
  final String? phone;
  final String status; // 'active' | 'suspended' | 'resigned' | 'terminated'
  final String? notes;
  final String? employeeNumber; // EMP-000001 — ثابت، يولَّد تلقائياً عند الإنشاء ولا يتغير أبداً
  final bool isArchived;

  const Employee({
    this.id,
    this.hotelId,
    required this.name,
    required this.position,
    required this.salary,
    required this.hiredAt,
    this.phone,
    this.status = 'active',
    this.notes,
    this.employeeNumber,
    this.isArchived = false,
  });

  static const statusActive = 'active';
  static const statusSuspended = 'suspended';
  static const statusResigned = 'resigned';
  static const statusTerminated = 'terminated';

  static String statusLabel(String status) {
    switch (status) {
      case statusSuspended:
        return 'موقوف';
      case statusResigned:
        return 'مستقيل';
      case statusTerminated:
        return 'منتهي الخدمة';
      default:
        return 'على رأس العمل';
    }
  }

  Employee copyWith({
    int? id,
    int? hotelId,
    String? name,
    String? position,
    double? salary,
    String? hiredAt,
    String? phone,
    String? status,
    String? notes,
    String? employeeNumber,
    bool? isArchived,
  }) {
    return Employee(
      id: id ?? this.id,
      hotelId: hotelId ?? this.hotelId,
      name: name ?? this.name,
      position: position ?? this.position,
      salary: salary ?? this.salary,
      hiredAt: hiredAt ?? this.hiredAt,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'name': name,
      'position': position,
      'salary': salary,
      'hired_at': hiredAt,
      'phone': phone,
      'status': status,
      'notes': notes,
      if (employeeNumber != null) 'employee_number': employeeNumber,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int?,
      name: map['name'] as String,
      position: map['position'] as String,
      salary: (map['salary'] as num).toDouble(),
      hiredAt: map['hired_at'] as String,
      phone: map['phone'] as String?,
      status: (map['status'] as String?) ?? statusActive,
      notes: map['notes'] as String?,
      employeeNumber: map['employee_number'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
    );
  }
}
