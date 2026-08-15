/// يطابق جدول `pending_expenses` — راجع
/// supabase/migrations/20260730000002_phase3_operational_money_flow.sql.
class SupaPendingExpense {
  static const paymentCash = 'cash';
  static const paymentPos = 'pos';
  static const paymentPersonal = 'personal';
  static const paymentOwnerDrawing = 'owner_drawing';
  static const paymentDeferred = 'deferred';

  final String? id;
  final String hotelId;
  final String categoryId;
  final String? supplierId;
  final double amount;
  final String statement;
  final String paymentMethod;
  final String? fundingSourceHotelId;
  final String? dueDate;
  final bool isTransferred;
  final String? transferredAt;
  final String? sharedExpenseGroupId;
  final String? archivedAt;
  final String? createdAt;
  final String? updatedAt;

  const SupaPendingExpense({
    this.id,
    required this.hotelId,
    required this.categoryId,
    this.supplierId,
    required this.amount,
    required this.statement,
    required this.paymentMethod,
    this.fundingSourceHotelId,
    this.dueDate,
    this.isTransferred = false,
    this.transferredAt,
    this.sharedExpenseGroupId,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isArchived => archivedAt != null;
  bool get isFromSharedExpense => sharedExpenseGroupId != null;

  Map<String, dynamic> toInsertMap() => {
        'hotel_id': hotelId,
        'category_id': categoryId,
        'supplier_id': supplierId,
        'amount': amount,
        'statement': statement,
        'payment_method': paymentMethod,
        'funding_source_hotel_id': fundingSourceHotelId,
        'due_date': dueDate,
      };

  Map<String, dynamic> toUpdateMap() => {
        'category_id': categoryId,
        'supplier_id': supplierId,
        'amount': amount,
        'statement': statement,
        'payment_method': paymentMethod,
        'funding_source_hotel_id': fundingSourceHotelId,
        'due_date': dueDate,
      };

  factory SupaPendingExpense.fromMap(Map<String, dynamic> map) {
    return SupaPendingExpense(
      id: map['id'] as String?,
      hotelId: map['hotel_id'] as String,
      categoryId: map['category_id'] as String,
      supplierId: map['supplier_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      statement: map['statement'] as String,
      paymentMethod: map['payment_method'] as String,
      fundingSourceHotelId: map['funding_source_hotel_id'] as String?,
      dueDate: map['due_date'] as String?,
      isTransferred: map['is_transferred'] as bool? ?? false,
      transferredAt: map['transferred_at'] as String?,
      sharedExpenseGroupId: map['shared_expense_group_id'] as String?,
      archivedAt: map['archived_at'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
