class ContractPayment {
  final int? id;
  final int contractId;
  final double amount;
  final String date;
  final String status;
  final String amountSource;

  const ContractPayment({
    this.id,
    required this.contractId,
    required this.amount,
    required this.date,
    required this.status,
    this.amountSource = 'خارج النظام',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'contract_id': contractId,
      'amount': amount,
      'date': date,
      'status': status,
      'amount_source': amountSource,
    };
  }

  factory ContractPayment.fromMap(Map<String, dynamic> map) {
    return ContractPayment(
      id: map['id'] as int?,
      contractId: map['contract_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      status: map['status'] as String,
      amountSource: map['amount_source'] ?? 'خارج النظام',
    );
  }

  ContractPayment copyWith({
    int? id,
    int? contractId,
    double? amount,
    String? date,
    String? status,
    String? amountSource,
  }) {
    return ContractPayment(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      status: status ?? this.status,
      amountSource: amountSource ?? this.amountSource,
    );
  }
}
