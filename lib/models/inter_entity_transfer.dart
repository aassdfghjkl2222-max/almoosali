/// "التحويل بين المنشآت": تحويل مباشر لمبلغ من [fromHotelId] إلى [toHotelId]
/// بلا مصروف مرتبط — ليس مصروفاً ولا يظهر في إجمالي مصروفات أي تقرير. سجل
/// معلَّق بحت عند الإنشاء ([isTransferred] = false): بلا أي قيد محاسبي، بلا
/// أي أثر على المركز المالي. القيد المحاسبي الفعلي (ذمة بين الفندقين، أو خصم
/// حقيقي من أصول المُرسِل + ذمة إن دُفع من مصدر تمويل حقيقي — راجع
/// [fundingSourceCategory]) يُنفَّذ فقط عند ترحيل تقرير يوم هذا التحويل
/// (راجع VaultRepository.postReportComponents وInterEntityTransferRepository) —
/// يمر بنفس دورة الحياة المحاسبية: معلّق ← تقرير يومي ← ترحيل.
class InterEntityTransfer {
  final int? id;
  final int fromHotelId;
  final int toHotelId;
  final double amount;
  final String statement;
  final String date;
  final String time;
  final String createdAt;

  /// مصدر التمويل الفعلي ('cash'/'bank') إن كان هذا الفندق (fromHotelId) هو
  /// من دفع فعلياً (فتح الشاشة من طرف المُرسِل) — null يعني القيد أُنشئ من
  /// طرف المستقبِل (ذمة فقط، بلا أثر نقدي حقيقي).
  final String? fundingSourceCategory;

  /// هل رُحِّل تقرير يوم هذا التحويل فعلياً؟ false = معلَّق (قابل للتعديل/الحذف
  /// بلا أي عكس محاسبي، لأنه لم يُسجَّل شيء بعد). true = القيد المحاسبي
  /// مُسجَّل بالفعل، فلا يجوز تعديله أو حذفه (راجع
  /// InterEntityTransferRepository._ensureTransferEditable).
  final bool isTransferred;

  const InterEntityTransfer({
    this.id,
    required this.fromHotelId,
    required this.toHotelId,
    required this.amount,
    required this.statement,
    required this.date,
    required this.time,
    required this.createdAt,
    this.fundingSourceCategory,
    this.isTransferred = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'from_hotel_id': fromHotelId,
      'to_hotel_id': toHotelId,
      'amount': amount,
      'statement': statement,
      'date': date,
      'time': time,
      'created_at': createdAt,
      'funding_source_category': fundingSourceCategory,
      'is_transferred': isTransferred ? 1 : 0,
    };
  }

  factory InterEntityTransfer.fromMap(Map<String, dynamic> map) {
    return InterEntityTransfer(
      id: map['id'] as int?,
      fromHotelId: map['from_hotel_id'] as int,
      toHotelId: map['to_hotel_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      statement: map['statement'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      createdAt: map['created_at'] as String,
      fundingSourceCategory: map['funding_source_category'] as String?,
      isTransferred: (map['is_transferred'] as int? ?? 0) == 1,
    );
  }

  InterEntityTransfer copyWith({
    int? id,
    int? fromHotelId,
    int? toHotelId,
    double? amount,
    String? statement,
    String? date,
    String? time,
    String? createdAt,
    String? fundingSourceCategory,
    bool clearFundingSourceCategory = false,
    bool? isTransferred,
  }) {
    return InterEntityTransfer(
      id: id ?? this.id,
      fromHotelId: fromHotelId ?? this.fromHotelId,
      toHotelId: toHotelId ?? this.toHotelId,
      amount: amount ?? this.amount,
      statement: statement ?? this.statement,
      date: date ?? this.date,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
      fundingSourceCategory: clearFundingSourceCategory ? null : (fundingSourceCategory ?? this.fundingSourceCategory),
      isTransferred: isTransferred ?? this.isTransferred,
    );
  }
}
