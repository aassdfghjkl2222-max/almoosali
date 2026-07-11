class EmployeeAllowance {
  final int? id;
  final int hotelId;
  final int employeeId;
  final String name;
  final double amount;
  final String createdAt;

  const EmployeeAllowance({
    this.id,
    required this.hotelId,
    required this.employeeId,
    required this.name,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'employee_id': employeeId,
      'name': name,
      'amount': amount,
      'created_at': createdAt,
    };
  }

  factory EmployeeAllowance.fromMap(Map<String, dynamic> map) {
    return EmployeeAllowance(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      employeeId: map['employee_id'] as int,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      createdAt: map['created_at'] as String,
    );
  }
}
