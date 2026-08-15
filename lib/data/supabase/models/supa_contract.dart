/// يطابق `contracts`/`contract_payments` — راجع
/// supabase/migrations/20260730000004_phase4_people_and_contracts.sql.
library;

class SupaContract {
  static const statusActive = 'active';
  static const statusExpired = 'expired';

  final String? id;
  final String hotelId;
  final String name;
  final String contractorName;
  final String startDate;
  final String duration;
  final String endDate;
  final double totalValue;
  final String paymentMethod;
  final String status;
  final String? archivedAt;
  final String? createdAt;
  final String? updatedAt;

  const SupaContract({
    this.id,
    required this.hotelId,
    required this.name,
    required this.contractorName,
    required this.startDate,
    required this.duration,
    required this.endDate,
    required this.totalValue,
    required this.paymentMethod,
    this.status = statusActive,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  Map<String, dynamic> toInsertMap() => {
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

  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'contractor_name': contractorName,
        'start_date': startDate,
        'duration': duration,
        'end_date': endDate,
        'total_value': totalValue,
        'payment_method': paymentMethod,
        'status': status,
      };

  factory SupaContract.fromMap(Map<String, dynamic> map) {
    return SupaContract(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      name: map['name'] as String,
      contractorName: map['contractor_name'] as String,
      startDate: map['start_date'] as String,
      duration: map['duration'] as String,
      endDate: map['end_date'] as String,
      totalValue: (map['total_value'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      status: map['status'] as String? ?? statusActive,
      archivedAt: map['archived_at'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}

class SupaContractPayment {
  static const statusPending = 'pending';
  static const statusPaid = 'paid';

  final String? id;
  final String contractId;
  final double amount;
  final String paymentDate;
  final String status;
  final String? fundingSource;

  const SupaContractPayment({
    this.id,
    required this.contractId,
    required this.amount,
    required this.paymentDate,
    this.status = statusPending,
    this.fundingSource,
  });

  Map<String, dynamic> toInsertMap() => {
        'contract_id': contractId,
        'amount': amount,
        'payment_date': paymentDate,
        'status': status,
        'funding_source': fundingSource,
      };

  factory SupaContractPayment.fromMap(Map<String, dynamic> map) {
    return SupaContractPayment(
      id: map['id'] as String?,
      contractId: map['contract_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: map['payment_date'] as String,
      status: map['status'] as String? ?? statusPending,
      fundingSource: map['funding_source'] as String?,
    );
  }
}
