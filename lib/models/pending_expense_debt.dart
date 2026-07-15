/// دين على المنشأة لصالح مورد، ناتج عن مصروف معلق بمصدر تمويل "آجل (دين)" —
/// لا يُنشأ أي قيد في الخزنة/البنك/الشبكة عند إنشائه. مرتبط بمصروف معلق واحد
/// فقط (pending_expense_id فريد)، ويُحدَّث تلقائياً إن عُدِّل ذلك المصروف قبل
/// ترحيله، ويُحذف تلقائياً (ON DELETE CASCADE) إن حُذف. مستقل عن [SupplierDebt]
/// (الخاص حصراً بفواتير "شراء آجل") تفادياً لخلط مصدرين مختلفين للمديونية
/// بنفس العمود الفريد invoice_id — كلاهما يُجمَّعان معاً في "الذمم الدائنة".
class PendingExpenseDebt {
  static const statusUnpaid = 'غير مسدد';

  final int? id;
  final int hotelId;
  final int supplierId;
  final int pendingExpenseId;
  final double amount;
  final String statement;
  final String? dueDate;
  final String status;
  final String createdAt;

  const PendingExpenseDebt({
    this.id,
    required this.hotelId,
    required this.supplierId,
    required this.pendingExpenseId,
    required this.amount,
    required this.statement,
    this.dueDate,
    this.status = statusUnpaid,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'supplier_id': supplierId,
      'pending_expense_id': pendingExpenseId,
      'amount': amount,
      'statement': statement,
      'due_date': dueDate,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory PendingExpenseDebt.fromMap(Map<String, dynamic> map) {
    return PendingExpenseDebt(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] as int,
      supplierId: map['supplier_id'] as int,
      pendingExpenseId: map['pending_expense_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      statement: map['statement'] as String,
      dueDate: map['due_date'] as String?,
      status: map['status'] as String? ?? statusUnpaid,
      createdAt: map['created_at'] as String,
    );
  }
}
