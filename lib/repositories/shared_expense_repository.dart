import '../core/database/database_service.dart';
import '../models/shared_expense_group.dart';
import '../models/shared_expense_share.dart';
import '../services/financial_engine.dart';

/// إنشاء واستعلام "المصروف المشترك" — مصروف واحد تدفعه منشأة بالكامل ويُوزَّع
/// أثره على عدة منشآت مشارِكة. القيود المحاسبية الفعلية تُنفَّذ فوراً عبر
/// [FinancialEngine.recordSharedExpense] عند الحفظ (راجع تعليقها) — لا تنتظر
/// أي دورة ترحيل لاحقة، بخلاف المصروفات المعلقة العادية.
class SharedExpenseRepository {
  final _dbService = DatabaseService();
  final _financialEngine = FinancialEngine();

  /// مصدر التمويل النصي → فئة FinancialEngine ('cash'/'bank'). "نقد" و"الخزنة"
  /// كلاهما يؤولان لحساب النقد الموحّد داخلياً ('cash')؛ "شبكة" فقط تُخصم من
  /// حساب الشبكة/البنك ('bank').
  static String paymentMethodCategory(String paymentMethod) => paymentMethod == 'شبكة' ? 'bank' : 'cash';

  /// [shares] حصة كل منشأة مشارِكة (بما فيها المموِّلة نفسها، إن وُجدت في
  /// الخريطة بقيمة > 0) — المجموع يجب أن يساوي [group.totalAmount] (يُتحقَّق
  /// منه في الواجهة قبل الاستدعاء). ينشئ صف المجموعة + صف حصة لكل منشأة، ثم
  /// يستدعي [FinancialEngine.recordSharedExpense] بحصص المنشآت الأخرى فقط
  /// (باستثناء المموِّلة نفسها التي لا قيد منفصل لها — راجع تعليق الدالة).
  Future<int> createSharedExpense({
    required SharedExpenseGroup group,
    required Map<int, double> shares,
  }) async {
    final groupId = await _dbService.insertSharedExpenseGroup(group.toMap());

    for (final entry in shares.entries) {
      await _dbService.insertSharedExpenseShare(
        SharedExpenseShare(sharedExpenseGroupId: groupId, hotelId: entry.key, amount: entry.value).toMap(),
      );
    }

    final otherShares = Map<int, double>.from(shares)..remove(group.fundingHotelId);
    await _financialEngine.recordSharedExpense(
      fundingHotelId: group.fundingHotelId,
      totalAmount: group.totalAmount,
      paymentMethodCategory: paymentMethodCategory(group.paymentMethod),
      otherShares: otherShares,
      description: group.description,
      referenceId: groupId,
    );

    return groupId;
  }

  /// حصص فندق معيّن من كل مصروف مشترك بتاريخ محدَّد — عرض معلوماتي فقط في
  /// التقرير اليومي (راجع daily_report_builder.dart)، بلا أي أثر على الحساب.
  Future<List<SharedExpenseShare>> getSharesForHotelAndDate(int hotelId, String date) async {
    final data = await _dbService.getSharedExpenseSharesForHotelAndDate(hotelId, date);
    return data.map((e) => SharedExpenseShare.fromMap(e)).toList();
  }

  /// كل مجموعات المصروف المشترك التي مَوَّلتها منشأة معيّنة — لقسم "المصروفات
  /// المشتركة" في شاشة العمليات المالية المعلقة.
  Future<List<SharedExpenseGroup>> getSharedExpensesForFundingHotel(int hotelId) async {
    final data = await _dbService.getSharedExpenseGroupsByFundingHotel(hotelId);
    return data.map((e) => SharedExpenseGroup.fromMap(e)).toList();
  }
}
