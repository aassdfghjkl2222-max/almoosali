class FinancialReport {
  final int? id;
  final int hotelId;
  final String date;
  final double income;
  final double expenses;
  final String? notes;
  final String? increaseDesc;
  final String? shortageDesc;
  final String? employeeName;
  final String? detailsJson;
  final String createdAt;
  final bool isPosted;
  final String reportType; // 'main' or 'additional'
  final bool isLocked;

  FinancialReport({
    this.id,
    required this.hotelId,
    required this.date,
    required this.income,
    required this.expenses,
    this.notes,
    this.increaseDesc,
    this.shortageDesc,
    this.employeeName,
    this.detailsJson,
    required this.createdAt,
    this.isPosted = false,
    this.reportType = 'main',
    this.isLocked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotel_id': hotelId,
      'date': date,
      'income': income,
      'expenses': expenses,
      'notes': notes,
      'increase_desc': increaseDesc,
      'shortage_desc': shortageDesc,
      'employee_name': employeeName,
      'details_json': detailsJson,
      'created_at': createdAt,
      'is_posted': isPosted ? 1 : 0,
      'report_type': reportType,
      'is_locked': isLocked ? 1 : 0,
    };
  }

  factory FinancialReport.fromMap(Map<String, dynamic> map) {
    return FinancialReport(
      id: map['id'],
      hotelId: map['hotel_id'],
      date: map['date'],
      income: map['income'],
      expenses: map['expenses'],
      notes: map['notes'],
      increaseDesc: map['increase_desc'],
      shortageDesc: map['shortage_desc'],
      employeeName: map['employee_name'],
      detailsJson: map['details_json'],
      createdAt: map['created_at'],
      isPosted: (map['is_posted'] ?? 0) == 1,
      reportType: map['report_type'] ?? 'main',
      isLocked: (map['is_locked'] ?? 0) == 1,
    );
  }

  FinancialReport copyWith({
    int? id,
    int? hotelId,
    String? date,
    double? income,
    double? expenses,
    String? notes,
    String? increaseDesc,
    String? shortageDesc,
    String? employeeName,
    String? detailsJson,
    String? createdAt,
    bool? isPosted,
    String? reportType,
    bool? isLocked,
  }) {
    return FinancialReport(
      id: id ?? this.id,
      hotelId: hotelId ?? this.hotelId,
      date: date ?? this.date,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
      notes: notes ?? this.notes,
      increaseDesc: increaseDesc ?? this.increaseDesc,
      shortageDesc: shortageDesc ?? this.shortageDesc,
      employeeName: employeeName ?? this.employeeName,
      detailsJson: detailsJson ?? this.detailsJson,
      createdAt: createdAt ?? this.createdAt,
      isPosted: isPosted ?? this.isPosted,
      reportType: reportType ?? this.reportType,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
