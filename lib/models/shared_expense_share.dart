/// حصة منشأة واحدة ([hotelId]) ضمن مصروف مشترك ([sharedExpenseGroupId]) —
/// راجع [SharedExpenseGroup]. الحقول الإضافية (group*/fundingHotelName) حقول
/// عرض فقط من JOIN، لا تُكتب في toMap.
class SharedExpenseShare {
  final int? id;
  final int sharedExpenseGroupId;
  final int hotelId;
  final double amount;

  // حقول عرض فقط (من JOIN مع shared_expense_groups/hotels) — راجع
  // DatabaseService.getSharedExpenseSharesForHotelAndDate.
  final String? groupDescription;
  final double? groupTotalAmount;
  final String? groupPaymentMethod;
  final int? groupFundingHotelId;
  final String? fundingHotelName;

  const SharedExpenseShare({
    this.id,
    required this.sharedExpenseGroupId,
    required this.hotelId,
    required this.amount,
    this.groupDescription,
    this.groupTotalAmount,
    this.groupPaymentMethod,
    this.groupFundingHotelId,
    this.fundingHotelName,
  });

  /// هل هذه المنشأة هي المموِّلة نفسها (وليست مشارِكة مستفيدة)؟
  bool get isFundingHotel => groupFundingHotelId != null && groupFundingHotelId == hotelId;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shared_expense_group_id': sharedExpenseGroupId,
      'hotel_id': hotelId,
      'amount': amount,
    };
  }

  factory SharedExpenseShare.fromMap(Map<String, dynamic> map) {
    return SharedExpenseShare(
      id: map['id'] as int?,
      sharedExpenseGroupId: map['shared_expense_group_id'] as int,
      hotelId: map['hotel_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      groupDescription: map['group_description'] as String?,
      groupTotalAmount: map['group_total_amount'] != null ? (map['group_total_amount'] as num).toDouble() : null,
      groupPaymentMethod: map['group_payment_method'] as String?,
      groupFundingHotelId: map['group_funding_hotel_id'] as int?,
      fundingHotelName: map['funding_hotel_name'] as String?,
    );
  }
}
