import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_similarity.dart';
import '../models/supa_financial_category.dart';
import '../supabase_config.dart';

/// محرك الفئات المالية الموحَّد — نسخة Supabase. يقرأ/يكتب حصراً عبر
/// `financial_categories` وبوابتَي RPC (record_financial_category_usage,
/// reorder_financial_categories, reset_financial_category_order) — راجع
/// supabase/migrations/20260728000002_phase2_financial_core.sql و
/// 20260730000001_phase2_reports_and_category_rpcs.sql. قواعد الاستخدام
/// (لا حذف لفئة مستخدَمة، لا اسم مكرَّر بالضبط لنفس النوع، افتراضي واحد فقط
/// لكل نوع) مفروضة أصلاً بواسطة قيود/سياسات قاعدة البيانات نفسها؛ هذه الطبقة
/// لا تُعيد تنفيذها، فقط تستدعيها وتترجم الاستثناء الناتج عند الحاجة.
class SupaFinancialCategoryRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaFinancialCategory>> getCategories({required String type, bool includeArchived = false}) async {
    var query = _db.from('financial_categories').select().eq('type', type);
    if (!includeArchived) query = query.filter('archived_at', 'is', null);
    final rows = await query.order('is_pinned', ascending: false).order('sort_order', ascending: true);
    return (rows as List).map((m) => SupaFinancialCategory.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<SupaFinancialCategory>> getAllCategories() async {
    final rows = await _db.from('financial_categories').select().order('type', ascending: true).order('is_pinned', ascending: false).order('sort_order', ascending: true);
    return (rows as List).map((m) => SupaFinancialCategory.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<SupaFinancialCategory?> getCategoryById(String id) async {
    final row = await _db.from('financial_categories').select().eq('id', id).maybeSingle();
    return row == null ? null : SupaFinancialCategory.fromMap(row);
  }

  /// تطابق حرفي تام (بعد إزالة المسافات الطرفية) ضمن نفس النوع — يعتمد على
  /// قيد `unique(type, name)` في قاعدة البيانات، فهذا الاستعلام للعرض
  /// المسبق فقط (رسالة خطأ واضحة قبل محاولة الحفظ)، وليس مصدر الحقيقة.
  Future<SupaFinancialCategory?> getCategoryByName(String name, String type, {String? excludeId}) async {
    final all = await getCategories(type: type, includeArchived: true);
    final normalized = name.trim();
    for (final c in all) {
      if (c.id == excludeId) continue;
      if (c.name.trim() == normalized) return c;
    }
    return null;
  }

  /// كشف تكرار "شبه واضح" — تحذير غير مانع، نفس الخوارزمية المستخدَمة في
  /// النسخة المحلية (SQLite) بالضبط عبر core/text_similarity.dart.
  Future<SupaFinancialCategory?> findLikelyDuplicate(String name, String type, {String? excludeId}) async {
    final all = await getCategories(type: type, includeArchived: true);
    for (final c in all) {
      if (c.id == excludeId) continue;
      if (isLikelyDuplicateCategoryName(c.name, name)) return c;
    }
    return null;
  }

  /// هل هذه الفئة مستخدَمة في أي بند تقرير مالي؟ (نطاق Phase 2 الحالي فقط —
  /// مصروفات معلَّقة/فواتير/عقود ستنضم هنا عند تنفيذ المراحل اللاحقة، تماماً
  /// كما تطوَّر مقابلها في database_service.dart محلياً). لا حاجة فعلية لهذا
  /// الفحص قبل الحذف — سياسة financial_categories_delete في قاعدة البيانات
  /// تفرضه بنفسها؛ متاح هنا فقط لعرض رسالة واضحة في الواجهة *قبل* المحاولة.
  Future<bool> isCategoryInUse(String categoryId) async {
    final revenueRows = await _db.from('financial_report_revenue_lines').select('id').eq('category_id', categoryId).limit(1);
    if ((revenueRows as List).isNotEmpty) return true;
    final expenseRows = await _db.from('financial_report_expense_lines').select('id').eq('category_id', categoryId).limit(1);
    return (expenseRows as List).isNotEmpty;
  }

  Future<SupaFinancialCategory> addCategory(SupaFinancialCategory category) async {
    final row = await _db.from('financial_categories').insert(category.toInsertMap()).select().single();
    return SupaFinancialCategory.fromMap(row);
  }

  Future<SupaFinancialCategory> updateCategory(SupaFinancialCategory category) async {
    if (category.id == null) {
      throw ArgumentError('updateCategory requires an existing category.id');
    }
    final row = await _db.from('financial_categories').update(category.toUpdateMap()).eq('id', category.id!).select().single();
    return SupaFinancialCategory.fromMap(row);
  }

  /// أرشفة (بدل الحذف) — تختفي فوراً من كل شاشات اختيار الفئة (المُنتقي يقرأ
  /// includeArchived: false دائماً)، وتبقى مرتبطة بأي عملية تاريخية استخدمتها.
  Future<void> archiveCategory(String id) async {
    await _db.from('financial_categories').update({'archived_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restoreCategory(String id) async {
    await _db.from('financial_categories').update({'archived_at': null, 'archived_by': null}).eq('id', id);
  }

  /// يجعل فئة واحدة فقط (ضمن [type]) هي الافتراضية — يُنفَّذ بخطوتين لأن
  /// الفهرس الفريد الجزئي `idx_financial_categories_one_default_per_type`
  /// يمنع وجود فئتين افتراضيتين لنفس النوع في آنٍ واحد، فيجب إلغاء القديمة
  /// أولاً ثم تعيين الجديدة (وليس تحديثاً واحداً متزامناً).
  Future<void> setDefaultCategory(String id, String type) async {
    await _db.from('financial_categories').update({'is_default': false}).eq('type', type).eq('is_default', true);
    await _db.from('financial_categories').update({'is_default': true}).eq('id', id);
  }

  /// حذف نهائي — قاعدة البيانات ترفضه (استثناء RLS) إن كانت الفئة مستخدَمة
  /// فعلياً؛ الواجهة يجب أن تستدعي [isCategoryInUse] أولاً لعرض رسالة واضحة
  /// بدل ترك المستخدم يواجه استثناء Postgrest خاماً.
  Future<void> deleteCategory(String id) async {
    await _db.from('financial_categories').delete().eq('id', id);
  }

  Future<void> recordUsage(String categoryId) async {
    await _db.rpc('record_financial_category_usage', params: {'target_category_id': categoryId});
  }

  Future<void> reorderCategories(List<SupaFinancialCategory> orderedCategories) async {
    final ids = orderedCategories.where((c) => c.id != null).map((c) => c.id!).toList();
    await _db.rpc('reorder_financial_categories', params: {'ordered_ids': ids});
  }

  Future<void> resetToDefaultOrder(String type) async {
    await _db.rpc('reset_financial_category_order', params: {'target_type': type});
  }
}
