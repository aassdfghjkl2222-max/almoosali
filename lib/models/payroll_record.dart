class PayrollRecord {
  final int? id;
  final int hotelId;
  final int employeeId;
  final String period; // 'YYYY-MM'
  final double baseSalary;
  final double allowancesTotal;
  final double deductionsTotal;
  final double advancesTotal;
  final double netSalary;
  final String status; // 'approved' | 'paid'
  final String? paymentSource; // 'نقد' | 'شبكة' | 'شخصي' | 'موزع'
  final double cashAmount;
  final double bankAmount;
  final double personalAmount;
  final String approvedAt;
  final String? paidAt;
  final String createdAt;

  /// حساب الراتب الجزئي حسب أيام العمل الفعلية داخل الفترة (تعيين/نقل/إيقاف منتصف الشهر).
  final String? periodStart;
  final String? periodEnd;
  final int daysWorked;
  final int totalDaysInPeriod;
  final double proratedBase;

  const PayrollRecord({
    this.id,
    required this.hotelId,
    required this.employeeId,
    required this.period,
    required this.baseSalary,
    this.allowancesTotal = 0,
    this.deductionsTotal = 0,
    this.advancesTotal = 0,
    required this.netSalary,
    this.status = 'approved',
    this.paymentSource,
    this.cashAmount = 0,
    this.bankAmount = 0,
    this.personalAmount = 0,
    required this.approvedAt,
    this.paidAt,
    required this.createdAt,
    this.periodStart,
    this.periodEnd,
    this.daysWorked = 0,
    this.totalDaysInPeriod = 30,
    this.proratedBase = 0,
  });

  static const statusApproved = 'approved';
  static const statusPaid = 'paid';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'employee_id': employeeId,
      'period': period,
      'base_salary': baseSalary,
      'allowances_total': allowancesTotal,
      'deductions_total': deductionsTotal,
      'advances_total': advancesTotal,
      'net_salary': netSalary,
      'status': status,
      'payment_source': paymentSource,
      'cash_amount': cashAmount,
      'bank_amount': bankAmount,
      'personal_amount': personalAmount,
      'approved_at': approvedAt,
      'paid_at': paidAt,
      'created_at': createdAt,
      'period_start': periodStart,
      'period_end': periodEnd,
      'days_worked': daysWorked,
      'total_days_in_period': totalDaysInPeriod,
      'prorated_base': proratedBase,
    };
  }

  factory PayrollRecord.fromMap(Map<String, dynamic> map) {
    return PayrollRecord(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      employeeId: map['employee_id'] as int,
      period: map['period'] as String,
      baseSalary: (map['base_salary'] as num).toDouble(),
      allowancesTotal: (map['allowances_total'] as num?)?.toDouble() ?? 0,
      deductionsTotal: (map['deductions_total'] as num?)?.toDouble() ?? 0,
      advancesTotal: (map['advances_total'] as num?)?.toDouble() ?? 0,
      netSalary: (map['net_salary'] as num).toDouble(),
      status: (map['status'] as String?) ?? statusApproved,
      paymentSource: map['payment_source'] as String?,
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0,
      bankAmount: (map['bank_amount'] as num?)?.toDouble() ?? 0,
      personalAmount: (map['personal_amount'] as num?)?.toDouble() ?? 0,
      approvedAt: map['approved_at'] as String,
      paidAt: map['paid_at'] as String?,
      createdAt: map['created_at'] as String,
      periodStart: map['period_start'] as String?,
      periodEnd: map['period_end'] as String?,
      daysWorked: (map['days_worked'] as int?) ?? 0,
      totalDaysInPeriod: (map['total_days_in_period'] as int?) ?? 30,
      proratedBase: (map['prorated_base'] as num?)?.toDouble() ?? 0,
    );
  }
}
