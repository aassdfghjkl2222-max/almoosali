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
  final String amountSource; // الخزنة / شبكة / خارج النظام
  final String createdAt;

  /// المورد المرتبط بدين هذا المصروف (إلزامي فقط عند paymentMethod == آجل
  /// (دين)) — راجع [fundingSourceDeferred].
  final int? supplierId;
  final String? supplierName; // حقل عرض فقط من JOIN، لا يُكتب في toMap
  final String? dueDate; // تاريخ استحقاق الدين — اختياري

  /// مصدر تمويل المبلغ فعلياً — null يعني هذا الفندق نفسه (الافتراضي، السلوك
  /// القديم بلا تغيير). قيمة غير null = معرّف فندق آخر موَّل المبلغ فعلياً،
  /// فلا يُخصَم من خزنة هذا الفندق عند الترحيل بل تُنشأ ذمة تلقائية بين
  /// الفندقين (راجع FinancialEngine.recordTransaction وتعليقها). منفصل تماماً
  /// عن [paymentMethod] (نقد/شبكة) الذي يبقى يجيب "كيف" بينما هذا يجيب "من أين".
  final int? fundingSourceHotelId;

  static const fundingSourceDeferred = 'آجل (دين)';

  /// الاسم المحاسبي لسحوبات المالك الشخصية — تُخصَم من الخزنة عند الترحيل
  /// وتُنشئ تلقائياً ذمة على المالك (راجع FinancialEngine.recordOwnerDrawing).
  /// [مُستبدَل بقسم "مسحوبات المالك" المستقل والفوري — يبقى فقط لعرض/تعديل
  /// أي مصروفات معلّقة قديمة أُنشئت بهذا المسار قبل الاستبدال، بلا أي مسار
  /// إضافة جديد يستخدمه بعد الآن.]
  static const paymentMethodOwnerDrawing = 'مسحوبات المالك';

  /// "عهدة الفندق" — المالك يموِّل مصروفاً حقيقياً للفندق من ماله الخاص:
  /// مصروف تشغيلي فعلي للفندق، لا يُخصَم أي نقد/شبكة/خزنة من الفندق، وتُنشأ
  /// تلقائياً ذمة (التزام) على الفندق لصالح المالك عبر حساب 'personal' عند
  /// الترحيل (راجع VaultRepository._postSpecialPendingExpenses).
  static const paymentMethodHotelAdvance = 'شخصي';

  /// "الخزنة" — مصدر تمويل فوري (خصم مباشر من رصيد الخزنة المتراكم عند
  /// الترحيل) بخلاف "نقد" الذي يُخصم من إيراد اليوم نفسه قبل الإيداع. كلاهما
  /// يؤول لنفس حساب FinancialEngine الداخلي ('cash') — الفرق توقيت/مصدر
  /// الخصم فقط، لا الحساب المحاسبي. راجع VaultRepository._postSpecialPendingExpenses.
  static const paymentMethodSafe = 'الخزنة';

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
    this.fundingSourceHotelId,
  });

  bool get isDeferredDebt => paymentMethod == fundingSourceDeferred;
  bool get isOwnerDrawing => paymentMethod == paymentMethodOwnerDrawing;
  bool get isHotelAdvance => paymentMethod == paymentMethodHotelAdvance;

  /// هل المبلغ ممَّول فعلياً من فندق آخر (وليس هذا الفندق نفسه)؟ — يحدِّد
  /// استبعاده من صافي الخزنة وإنشاء الذمة التلقائية بين المنشآت عند الترحيل.
  bool get isFundedByOtherHotel => fundingSourceHotelId != null && fundingSourceHotelId != hotelId;

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
      'funding_source_hotel_id': fundingSourceHotelId,
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
      fundingSourceHotelId: map['funding_source_hotel_id'] as int?,
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
    int? fundingSourceHotelId,
    bool clearSupplier = false,
    bool clearDueDate = false,
    bool clearFundingSource = false,
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
      fundingSourceHotelId: clearFundingSource ? null : (fundingSourceHotelId ?? this.fundingSourceHotelId),
    );
  }
}
