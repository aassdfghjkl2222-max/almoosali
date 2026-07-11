class EmployeeDeduction {
  final int? id;
  final int hotelId;
  final int employeeId;
  final String name;
  final double amount;
  final String? notes;
  final String createdAt;

  const EmployeeDeduction({
    this.id,
    required this.hotelId,
    required this.employeeId,
    required this.name,
    required this.amount,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'employee_id': employeeId,
      'name': name,
      'amount': amount,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory EmployeeDeduction.fromMap(Map<String, dynamic> map) {
    return EmployeeDeduction(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      employeeId: map['employee_id'] as int,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
