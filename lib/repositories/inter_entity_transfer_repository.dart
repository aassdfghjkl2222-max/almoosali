import '../core/database/database_service.dart';
import '../models/inter_entity_transfer.dart';
import '../services/financial_engine.dart';

/// إنشاء واستعلام "التحويل بين المنشآت" — مبلغ يرسله فندق مباشرة إلى فندق
/// آخر بلا مصروف مرتبط.
///
/// عندما تُفتح الشاشة من الفندق **المرسِل** (يُمرَّر [fundingSourceCategory])،
/// يُستخدم [FinancialEngine.recordSharedExpense] — نفس الأسلوب المُستخدم أصلاً
/// لـ"المصروف المشترك": يخصم مصدر التمويل المُختار فعلياً من أصول المرسِل
/// (نقد/خزنة/شبكة) **و** ينشئ ذمة (المستقبِل مدين للمرسِل) في خطوة واحدة —
/// حركة نقدية حقيقية + ذمة، وليس ذمة فقط.
///
/// عندما تُفتح من الفندق **المستقبِل** ([fundingSourceCategory] فارغ، لأن
/// قرار تمويل الطرف المرسِل غير معروف من هذه الشاشة)، يبقى السلوك القديم:
/// [FinancialEngine.recordTransaction] بآلية entity_/receivable_entity —
/// ذمة فقط، بلا أثر على أي رصيد فعلي (نفس منطق "مصروف مموَّل من فندق آخر").
class InterEntityTransferRepository {
  final _dbService = DatabaseService();
  final _financialEngine = FinancialEngine();

  Future<int> createTransfer({
    required int fromHotelId,
    required int toHotelId,
    required double amount,
    required String statement,
    String? fundingSourceCategory,
  }) async {
    final now = DateTime.now();
    final transfer = InterEntityTransfer(
      fromHotelId: fromHotelId,
      toHotelId: toHotelId,
      amount: amount,
      statement: statement,
      date: "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      time: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      createdAt: now.toIso8601String(),
    );
    final id = await _dbService.insertInterEntityTransfer(transfer.toMap());

    if (fundingSourceCategory != null) {
      // المرسِل يدفع فعلياً: خصم حقيقي من أصوله + ذمة على المستقبِل، معاً.
      await _financialEngine.recordSharedExpense(
        fundingHotelId: fromHotelId,
        totalAmount: amount,
        paymentMethodCategory: fundingSourceCategory,
        otherShares: {toHotelId: amount},
        description: "تحويل بين المنشآت: $statement",
        referenceId: id,
      );
    } else {
      // المستقبِل يُنشئ القيد: ذمة فقط، بلا معرفة مصدر تمويل المرسِل الفعلي.
      await _financialEngine.recordTransaction(
        hotelId: toHotelId,
        sourceCategory: 'entity_$fromHotelId',
        amount: amount,
        type: 'expense',
        description: "تحويل بين المنشآت: $statement",
        referenceId: id,
        referenceType: 'inter_entity_transfer',
        otherHotelId: fromHotelId,
      );
    }

    return id;
  }

  Future<List<InterEntityTransfer>> getForHotel(int hotelId) async {
    final data = await _dbService.getInterEntityTransfers(hotelId);
    return data.map((e) => InterEntityTransfer.fromMap(e)).toList();
  }
}
