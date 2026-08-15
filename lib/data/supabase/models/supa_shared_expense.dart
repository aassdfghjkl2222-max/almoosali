/// يطابق `shared_expense_groups`/`shared_expense_allocations` — راجع
/// supabase/migrations/20260730000002_phase3_operational_money_flow.sql.
/// يُنشآن معاً دائماً عبر create_shared_expense_distribution (RPC)، لا
/// إدراجاً مباشراً — راجع SupaSharedExpenseRepository.createDistribution.
class SupaSharedExpenseGroup {
  final String? id;
  final String categoryId;
  final String? description;
  final double totalAmount;
  final String paymentMethod;
  final String fundingHotelId;
  final String expenseDate;
  final String? createdAt;

  const SupaSharedExpenseGroup({
    this.id,
    required this.categoryId,
    this.description,
    required this.totalAmount,
    required this.paymentMethod,
    required this.fundingHotelId,
    required this.expenseDate,
    this.createdAt,
  });

  factory SupaSharedExpenseGroup.fromMap(Map<String, dynamic> map) {
    return SupaSharedExpenseGroup(
      id: map['id'] as String?,
      categoryId: map['category_id'] as String,
      description: map['description'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      fundingHotelId: map['funding_hotel_id'] as String,
      expenseDate: map['expense_date'] as String,
      createdAt: map['created_at'] as String?,
    );
  }
}

class SupaSharedExpenseAllocation {
  final String? id;
  final String sharedExpenseGroupId;
  final String hotelId;
  final double amount;
  final String? statement;

  const SupaSharedExpenseAllocation({
    this.id,
    required this.sharedExpenseGroupId,
    required this.hotelId,
    required this.amount,
    this.statement,
  });

  /// الصياغة التي يتوقعها create_shared_expense_distribution داخل
  /// p_allocations.
  Map<String, dynamic> toRpcJson() => {
        'hotel_id': hotelId,
        'amount': amount,
        if (statement != null) 'statement': statement,
      };

  factory SupaSharedExpenseAllocation.fromMap(Map<String, dynamic> map) {
    return SupaSharedExpenseAllocation(
      id: map['id'] as String?,
      sharedExpenseGroupId: map['shared_expense_group_id'] as String,
      hotelId: map['hotel_id'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }
}
