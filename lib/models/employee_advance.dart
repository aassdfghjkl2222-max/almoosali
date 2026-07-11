class EmployeeAdvance {
  final int? id;
  final int hotelId;
  final int employeeId;
  final double amount;
  final String date;
  final String? notes;
  final bool isSettled;
  final int? payrollId;
  final String createdAt;

  /// توزيع مصادر تمويل السلفة — يجب أن يساوي مجموعها [amount].
  final double cashAmount;
  final double bankAmount;
  final double personalAmount;
  final double entityAmount;
  final int? entityHotelId; // الفندق الآخر عند التمويل من "منشأة أخرى"

  const EmployeeAdvance({
    this.id,
    required this.hotelId,
    required this.employeeId,
    required this.amount,
    required this.date,
    this.notes,
    this.isSettled = false,
    this.payrollId,
    required this.createdAt,
    this.cashAmount = 0,
    this.bankAmount = 0,
    this.personalAmount = 0,
    this.entityAmount = 0,
    this.entityHotelId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'employee_id': employeeId,
      'amount': amount,
      'date': date,
      'notes': notes,
      'is_settled': isSettled ? 1 : 0,
      'payroll_id': payrollId,
      'created_at': createdAt,
      'cash_amount': cashAmount,
      'bank_amount': bankAmount,
      'personal_amount': personalAmount,
      'entity_amount': entityAmount,
      'entity_hotel_id': entityHotelId,
    };
  }

  factory EmployeeAdvance.fromMap(Map<String, dynamic> map) {
    return EmployeeAdvance(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      employeeId: map['employee_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      notes: map['notes'] as String?,
      isSettled: (map['is_settled'] as int? ?? 0) == 1,
      payrollId: map['payroll_id'] as int?,
      createdAt: map['created_at'] as String,
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0,
      bankAmount: (map['bank_amount'] as num?)?.toDouble() ?? 0,
      personalAmount: (map['personal_amount'] as num?)?.toDouble() ?? 0,
      entityAmount: (map['entity_amount'] as num?)?.toDouble() ?? 0,
      entityHotelId: map['entity_hotel_id'] as int?,
    );
  }
}
