import '../core/database/database_service.dart';
import '../core/text_similarity.dart';
import '../models/financial_category.dart';

/// محرك الفئات المالية الموحَّد — المصدر الوحيد لتصنيفات المصروفات والإيرادات
/// في التطبيق بالكامل. أي شاشة تُنشئ عملية مالية (مصروف معلَّق، مصروف مشترك،
/// بند تقرير يومي، فاتورة...) يجب أن تختار من هنا، لا تكتب اسماً حراً — راجع
/// تعليق جدول financial_categories في database_service.dart.
class FinancialCategoryRepository {
  final _dbService = DatabaseService();

  Future<List<FinancialCategory>> getCategories({required String type, bool includeArchived = false}) async {
    final data = await _dbService.getFinancialCategories(type: type, includeArchived: includeArchived);
    return data.map((m) => FinancialCategory.fromMap(m)).toList();
  }

  Future<void> recordUsage(int categoryId) async {
    await _dbService.recordFinancialCategoryUsage(categoryId);
  }

  Future<FinancialCategory?> getCategoryById(int id) async {
    final map = await _dbService.getFinancialCategoryById(id);
    return map == null ? null : FinancialCategory.fromMap(map);
  }

  Future<List<FinancialCategory>> getAllCategories() async {
    final data = await _dbService.getAllFinancialCategories();
    return data.map((m) => FinancialCategory.fromMap(m)).toList();
  }

  /// فحص تكرار الاسم — يُقارَن ضمن نفس [type] فقط (فئة إيراد وفئة مصروف قد
  /// يتشاركان الاسم نفسه بلا تعارض، مطابقةً للسلوك المعتمَد سابقاً في نظام
  /// بنود التقرير اليومي القديم). بلا حساسية لحالة الأحرف/المسافات الزائدة.
  Future<FinancialCategory?> getCategoryByName(String name, String type, {int? excludeId}) async {
    final all = await getCategories(type: type, includeArchived: true);
    final normalized = name.trim();
    for (final c in all) {
      if (c.id == excludeId) continue;
      if (c.name.trim() == normalized) return c;
    }
    return null;
  }

  /// كشف تكرار "شبه واضح" (بخلاف [getCategoryByName] الذي يمنع فقط التطابق
  /// الحرفي التام) — مثال من نطاق المهمة: "باركنج"/"إيراد الباركنج"/"موقف
  /// سيارات" قد تُمثِّل نفس الغرض المالي رغم اختلاف الصياغة. يُستخدَم كتحذير
  /// غير مانع (المستخدم يؤكد المتابعة صراحةً إن أراد فئة مختلفة فعلاً تتشابه
  /// صياغتها) وليس حظراً صلباً، لتفادي رفض فئات مختلفة فعلاً تتشارك كلمة شائعة.
  Future<FinancialCategory?> findLikelyDuplicate(String name, String type, {int? excludeId}) async {
    final all = await getCategories(type: type, includeArchived: true);
    for (final c in all) {
      if (c.id == excludeId) continue;
      if (isLikelyDuplicateCategoryName(c.name, name)) return c;
    }
    return null;
  }

  Future<bool> isCategoryInUse(FinancialCategory category) async {
    if (category.id == null) return false;
    return await _dbService.isFinancialCategoryInUse(category.id!, category.name);
  }

  Future<int> addCategory(FinancialCategory category) async {
    return await _dbService.insertFinancialCategory(category.toMap());
  }

  Future<int> updateCategory(FinancialCategory category) async {
    if (category.id == null) return 0;
    final data = category.copyWith(updatedAt: DateTime.now().toIso8601String()).toMap();
    return await _dbService.updateFinancialCategory(category.id!, data);
  }

  /// أرشفة (بدل الحذف) — تختفي فوراً من كل شاشات اختيار الفئة، وتبقى مرتبطة
  /// بأي عملية تاريخية استخدمتها سابقاً.
  Future<int> archiveCategory(int id) async {
    return await _dbService.updateFinancialCategory(id, {'is_visible': 0, 'updated_at': DateTime.now().toIso8601String()});
  }

  Future<int> restoreCategory(int id) async {
    return await _dbService.updateFinancialCategory(id, {'is_visible': 1, 'updated_at': DateTime.now().toIso8601String()});
  }

  /// يجعل فئة واحدة فقط (ضمن [type]) هي الافتراضية — تُستخدم في شاشة إضافة
  /// الفاتورة الضريبية لتحديد فئة مُختارة مسبقاً.
  Future<void> setDefaultCategory(int id, String type) async {
    final siblings = await getCategories(type: type, includeArchived: true);
    for (final c in siblings) {
      if (c.id == null) continue;
      await _dbService.updateFinancialCategory(c.id!, {'is_default': c.id == id ? 1 : 0});
    }
  }

  /// حذف نهائي — مسموح فقط لفئة لم تُستخدَم إطلاقاً (راجع [isCategoryInUse]).
  /// يُستدعى فقط بعد هذا التحقق من الواجهة.
  Future<int> deleteCategory(int id) async {
    return await _dbService.deleteFinancialCategory(id);
  }

  Future<void> reorderCategories(List<FinancialCategory> orderedCategories) async {
    final ids = orderedCategories.where((c) => c.id != null).map((c) => c.id!).toList();
    await _dbService.reorderFinancialCategories(ids);
  }

  Future<void> resetToDefaultOrder(String type) async {
    await _dbService.resetFinancialCategoryOrder(type);
  }
}
