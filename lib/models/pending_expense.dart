class PendingExpense {
  final int? id;
  final int hotelId;
  final double amount;
  final String paymentMethod; // نقد / شبكة / ... / "آجل (دين)"
  final int categoryId;
  final String? categoryName; // Helper for display
  final int? categoryIcon; // Helper for display
  final int? categoryColor; // Helper for display
  final String statement;
  final String? notes;
  final String date;
  final String time;
  final bool isTransferred;
  final String amountSource; // الخزنة / الحساب البنكي / خارج النظام
  final String createdAt;

  /// المورد المرتبط بدين هذا المصروف (إلزامي فقط عند paymentMethod == آجل
  /// (دين)) — راجع [fundingSourceDeferred].
  final int? supplierId;
  final String? supplierName; // حقل عرض فقط من JOIN، لا يُكتب في toMap
  final String? dueDate; // تاريخ استحقاق الدين — اختياري

  static const fundingSourceDeferred = 'آجل (دين)';

  PendingExpense({
    this.id,
    required this.hotelId,
    required this.amount,
    required this.paymentMethod,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.statement,
    this.notes,
    required this.date,
    required this.time,
    this.isTransferred = false,
    this.amountSource = 'خارج النظام',
    required this.createdAt,
    this.supplierId,
    this.supplierName,
    this.dueDate,
  });

  bool get isDeferredDebt => paymentMethod == fundingSourceDeferred;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotel_id': hotelId,
      'amount': amount,
      'payment_method': paymentMethod,
      'category_id': categoryId,
      'statement': statement,
      'notes': notes,
      'date': date,
      'time': time,
      'is_transferred': isTransferred ? 1 : 0,
      'amount_source': amountSource,
      'created_at': createdAt,
      'supplier_id': supplierId,
      'due_date': dueDate,
    };
  }

  factory PendingExpense.fromMap(Map<String, dynamic> map, {String? categoryName}) {
    return PendingExpense(
      id: map['id'],
      hotelId: map['hotel_id'],
      amount: map['amount'],
      paymentMethod: map['payment_method'],
      categoryId: map['category_id'],
      categoryName: categoryName ?? map['category_name'],
      categoryIcon: map['icon_code'],
      categoryColor: map['color_value'],
      statement: map['statement'],
      notes: map['notes'],
      date: map['date'],
      time: map['time'],
      isTransferred: (map['is_transferred'] ?? 0) == 1,
      amountSource: map['amount_source'] ?? 'خارج النظام',
      createdAt: map['created_at'],
      supplierId: map['supplier_id'] as int?,
      supplierName: map['supplier_name'] as String?,
      dueDate: map['due_date'] as String?,
    );
  }

  PendingExpense copyWith({
    int? id,
    int? hotelId,
    double? amount,
    String? paymentMethod,
    int? categoryId,
    String? categoryName,
    int? categoryIcon,
    int? categoryColor,
    String? statement,
    String? notes,
    String? date,
    String? time,
    bool? isTransferred,
    String? amountSource,
    String? createdAt,
    int? supplierId,
    String? supplierName,
    String? dueDate,
    bool clearSupplier = false,
    bool clearDueDate = false,
  }) {
    return PendingExpense(
      id: id ?? this.id,
      hotelId: hotelId ?? this.hotelId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      statement: statement ?? this.statement,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      time: time ?? this.time,
      isTransferred: isTransferred ?? this.isTransferred,
      amountSource: amountSource ?? this.amountSource,
      createdAt: createdAt ?? this.createdAt,
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      supplierName: clearSupplier ? null : (supplierName ?? this.supplierName),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    );
  }
}
