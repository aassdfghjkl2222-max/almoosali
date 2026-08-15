/// يطابق `payroll_records`/`employee_allowances`/`employee_deductions`/
/// `employee_advances` — راجع
/// supabase/migrations/20260730000004_phase4_people_and_contracts.sql.
/// إنشاء سجل راتب لا يمرّ عبر إدراج مباشر — راجع
/// SupaPayrollRepository.createPayrollRecord (RPC create_payroll_record).
library;

class SupaPayrollRecord {
  static const statusApproved = 'approved';
  static const statusPaid = 'paid';

  final String? id;
  final String hotelId;
  final String employeeId;
  final String period;
  final double baseSalary;
  final double allowancesTotal;
  final double deductionsTotal;
  final double advancesTotal;
  final double netSalary;
  final String status;
  final String? paymentSource;
  final double cashAmount;
  final double bankAmount;
  final double personalAmount;
  final String? approvedAt;
  final String? paidAt;
  final String? periodStart;
  final String? periodEnd;
  final int daysWorked;
  final int totalDaysInPeriod;
  final double proratedBase;

  const SupaPayrollRecord({
    this.id,
    required this.hotelId,
    required this.employeeId,
    required this.period,
    required this.baseSalary,
    this.allowancesTotal = 0,
    this.deductionsTotal = 0,
    this.advancesTotal = 0,
    required this.netSalary,
    this.status = statusApproved,
    this.paymentSource,
    this.cashAmount = 0,
    this.bankAmount = 0,
    this.personalAmount = 0,
    this.approvedAt,
    this.paidAt,
    this.periodStart,
    this.periodEnd,
    this.daysWorked = 0,
    this.totalDaysInPeriod = 30,
    this.proratedBase = 0,
  });

  factory SupaPayrollRecord.fromMap(Map<String, dynamic> map) {
    return SupaPayrollRecord(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      employeeId: map['employee_id'] as String,
      period: map['period'] as String,
      baseSalary: (map['base_salary'] as num).toDouble(),
      allowancesTotal: (map['allowances_total'] as num?)?.toDouble() ?? 0,
      deductionsTotal: (map['deductions_total'] as num?)?.toDouble() ?? 0,
      advancesTotal: (map['advances_total'] as num?)?.toDouble() ?? 0,
      netSalary: (map['net_salary'] as num).toDouble(),
      status: map['status'] as String? ?? statusApproved,
      paymentSource: map['payment_source'] as String?,
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0,
      bankAmount: (map['bank_amount'] as num?)?.toDouble() ?? 0,
      personalAmount: (map['personal_amount'] as num?)?.toDouble() ?? 0,
      approvedAt: map['approved_at'] as String?,
      paidAt: map['paid_at'] as String?,
      periodStart: map['period_start'] as String?,
      periodEnd: map['period_end'] as String?,
      daysWorked: map['days_worked'] as int? ?? 0,
      totalDaysInPeriod: map['total_days_in_period'] as int? ?? 30,
      proratedBase: (map['prorated_base'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SupaEmployeeAllowance {
  final String? id;
  final String hotelId;
  final String employeeId;
  final String name;
  final double amount;

  const SupaEmployeeAllowance({this.id, required this.hotelId, required this.employeeId, required this.name, required this.amount});

  Map<String, dynamic> toInsertMap() => {'hotel_id': hotelId, 'employee_id': employeeId, 'name': name, 'amount': amount};

  factory SupaEmployeeAllowance.fromMap(Map<String, dynamic> map) {
    return SupaEmployeeAllowance(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      employeeId: map['employee_id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }
}

class SupaEmployeeDeduction {
  final String? id;
  final String hotelId;
  final String employeeId;
  final String name;
  final double amount;
  final String? notes;

  const SupaEmployeeDeduction({this.id, required this.hotelId, required this.employeeId, required this.name, required this.amount, this.notes});

  Map<String, dynamic> toInsertMap() => {'hotel_id': hotelId, 'employee_id': employeeId, 'name': name, 'amount': amount, 'notes': notes};

  factory SupaEmployeeDeduction.fromMap(Map<String, dynamic> map) {
    return SupaEmployeeDeduction(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      employeeId: map['employee_id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

class SupaEmployeeAdvance {
  final String? id;
  final String hotelId;
  final String employeeId;
  final double amount;
  final String advanceDate;
  final String? notes;
  final bool isSettled;
  final String? payrollId;
  final double cashAmount;
  final double bankAmount;
  final double personalAmount;
  final double entityAmount;
  final String? entityHotelId;

  const SupaEmployeeAdvance({
    this.id,
    required this.hotelId,
    required this.employeeId,
    required this.amount,
    required this.advanceDate,
    this.notes,
    this.isSettled = false,
    this.payrollId,
    this.cashAmount = 0,
    this.bankAmount = 0,
    this.personalAmount = 0,
    this.entityAmount = 0,
    this.entityHotelId,
  });

  Map<String, dynamic> toInsertMap() => {
        'hotel_id': hotelId,
        'employee_id': employeeId,
        'amount': amount,
        'advance_date': advanceDate,
        'notes': notes,
        'cash_amount': cashAmount,
        'bank_amount': bankAmount,
        'personal_amount': personalAmount,
        'entity_amount': entityAmount,
        'entity_hotel_id': entityHotelId,
      };

  factory SupaEmployeeAdvance.fromMap(Map<String, dynamic> map) {
    return SupaEmployeeAdvance(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      employeeId: map['employee_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      advanceDate: map['advance_date'] as String,
      notes: map['notes'] as String?,
      isSettled: map['is_settled'] as bool? ?? false,
      payrollId: map['payroll_id'] as String?,
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0,
      bankAmount: (map['bank_amount'] as num?)?.toDouble() ?? 0,
      personalAmount: (map['personal_amount'] as num?)?.toDouble() ?? 0,
      entityAmount: (map['entity_amount'] as num?)?.toDouble() ?? 0,
      entityHotelId: map['entity_hotel_id'] as String?,
    );
  }
}
