class Contract {
  final int? id;
  final int hotelId;
  final String name;
  final String contractorName;
  final String startDate;
  final String duration;
  final String endDate;
  final double totalValue;
  final String paymentMethod;
  final String status;

  const Contract({
    this.id,
    required this.hotelId,
    required this.name,
    required this.contractorName,
    required this.startDate,
    required this.duration,
    required this.endDate,
    required this.totalValue,
    required this.paymentMethod,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'name': name,
      'contractor_name': contractorName,
      'start_date': startDate,
      'duration': duration,
      'end_date': endDate,
      'total_value': totalValue,
      'payment_method': paymentMethod,
      'status': status,
    };
  }

  factory Contract.fromMap(Map<String, dynamic> map) {
    return Contract(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] ?? 0,
      name: map['name'] as String,
      contractorName: map['contractor_name'] as String,
      startDate: map['start_date'] as String,
      duration: map['duration'] as String,
      endDate: map['end_date'] as String,
      totalValue: (map['total_value'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      status: map['status'] as String,
    );
  }

  Contract copyWith({
    int? id,
    int? hotelId,
    String? name,
    String? contractorName,
    String? startDate,
    String? duration,
    String? endDate,
    double? totalValue,
    String? paymentMethod,
    String? status,
  }) {
    return Contract(
      id: id ?? this.id,
      hotelId: hotelId ?? this.hotelId,
      name: name ?? this.name,
      contractorName: contractorName ?? this.contractorName,
      startDate: startDate ?? this.startDate,
      duration: duration ?? this.duration,
      endDate: endDate ?? this.endDate,
      totalValue: totalValue ?? this.totalValue,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
    );
  }
}
