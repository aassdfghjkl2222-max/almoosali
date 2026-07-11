class DepositedFund {
  final int? id;
  final int hotelId;
  final int? reportId;
  final String date;
  final double cashAmount;
  final double networkAmount;
  final String cashStatus;
  final String networkStatus;
  final bool isArchived;
  final String? postedAt;
  final String? postedBy;

  DepositedFund({
    this.id,
    required this.hotelId,
    this.reportId,
    required this.date,
    required this.cashAmount,
    required this.networkAmount,
    this.cashStatus = 'pending',
    this.networkStatus = 'pending',
    this.isArchived = false,
    this.postedAt,
    this.postedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotel_id': hotelId,
      'report_id': reportId,
      'date': date,
      'cash_amount': cashAmount,
      'network_amount': networkAmount,
      'cash_status': cashStatus,
      'network_status': networkStatus,
      'is_archived': isArchived ? 1 : 0,
      'posted_at': postedAt,
      'posted_by': postedBy,
    };
  }

  factory DepositedFund.fromMap(Map<String, dynamic> map) {
    return DepositedFund(
      id: map['id'],
      hotelId: map['hotel_id'] ?? 0,
      reportId: map['report_id'],
      date: map['date'] ?? '',
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0.0,
      networkAmount: (map['network_amount'] as num?)?.toDouble() ?? 0.0,
      cashStatus: map['cash_status'] ?? 'pending',
      networkStatus: map['network_status'] ?? 'pending',
      isArchived: (map['is_archived'] ?? 0) == 1,
      postedAt: map['posted_at'],
      postedBy: map['posted_by'],
    );
  }

  DepositedFund copyWith({
    int? id,
    int? hotelId,
    int? reportId,
    String? date,
    double? cashAmount,
    double? networkAmount,
    String? cashStatus,
    String? networkStatus,
    bool? isArchived,
    String? postedAt,
    String? postedBy,
  }) {
    return DepositedFund(
      id: id ?? this.id,
      hotelId: hotelId ?? this.hotelId,
      reportId: reportId ?? this.reportId,
      date: date ?? this.date,
      cashAmount: cashAmount ?? this.cashAmount,
      networkAmount: networkAmount ?? this.networkAmount,
      cashStatus: cashStatus ?? this.cashStatus,
      networkStatus: networkStatus ?? this.networkStatus,
      isArchived: isArchived ?? this.isArchived,
      postedAt: postedAt ?? this.postedAt,
      postedBy: postedBy ?? this.postedBy,
    );
  }
}
