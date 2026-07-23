import '../core/database/database_service.dart';
import '../models/inter_entity_transfer.dart';
import '../services/financial_engine.dart';

/// إنشاء واستعلام "التحويل بين المنشآت" — مبلغ يرسله فندق مباشرة إلى فندق
/// آخر بلا مصروف مرتبط. القيد المحاسبي فوري عند الحفظ عبر
/// [FinancialEngine.recordTransaction] بنفس آلية entity_/receivable_entity
/// المستخدمة أصلاً لحالة "مصروف مموَّل من فندق آخر" — ذمة فقط، بلا أي أثر على
/// أرصدة نقد/شبكة أي من الطرفين (نفس منطق النظام الحالي، بلا تغيير).
class InterEntityTransferRepository {
  final _dbService = DatabaseService();
  final _financialEngine = FinancialEngine();

  Future<int> createTransfer({
    required int fromHotelId,
    required int toHotelId,
    required double amount,
    required String statement,
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

    // المستقبِل (toHotelId) يصبح مديناً للمرسِل (fromHotelId) — نفس اتجاه
    // "مصروف مموَّل من فندق آخر" تماماً (راجع VaultRepository._postSpecialPendingExpenses).
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

    return id;
  }

  Future<List<InterEntityTransfer>> getForHotel(int hotelId) async {
    final data = await _dbService.getInterEntityTransfers(hotelId);
    return data.map((e) => InterEntityTransfer.fromMap(e)).toList();
  }
}
