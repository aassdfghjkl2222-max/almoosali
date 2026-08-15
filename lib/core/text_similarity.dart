/// كشف تشابه أسماء "شبه واضح" — يُستخدم لتحذير غير مانع عند إنشاء فئة مالية
/// جديدة يشبه اسمها فئة موجودة (مثال: "باركنج"/"إيراد الباركنج"/"موقف
/// سيارات" قد تُمثِّل نفس الغرض المالي رغم اختلاف الصياغة)، وليس حظراً صلباً.
/// خوارزمية واحدة يشترك فيها كل من FinancialCategoryRepository (SQLite) و
/// SupaFinancialCategoryRepository (Supabase) — لا تُكرَّر في أي مكان آخر.
bool isLikelyDuplicateCategoryName(String a, String b) {
  final an = normalizeForCategoryNameComparison(a);
  final bn = normalizeForCategoryNameComparison(b);
  if (an.isEmpty || bn.isEmpty) return false;
  if (an == bn) return true;
  if (an.contains(bn) || bn.contains(an)) return true;
  final at = an.split(' ').where((t) => t.isNotEmpty).toSet();
  final bt = bn.split(' ').where((t) => t.isNotEmpty).toSet();
  if (at.length <= 1 && bt.length <= 1) return false; // كلمة واحدة بلا احتواء أصلاً: قورنت أعلاه بالفعل
  final intersection = at.intersection(bt).length;
  final union = at.union(bt).length;
  if (union == 0) return false;
  return (intersection / union) >= 0.5;
}

/// يُطابِق البحث الشامل (GlobalSearch) — [haystack] نص خام كما هو مخزَّن،
/// [normalizedQuery] مُطبَّع مسبقاً عبر [normalizeForCategoryNameComparison]
/// (استدعِ هذا التطبيع مرة واحدة فقط على نص البحث نفسه، وليس على كل حقل
/// يُقارَن به — الأداء). مطابقة جزئية (contains)، بلا حساسية لحالة الأحرف
/// أو التشكيل العربي أو اختلاف الألف/التاء المربوطة/الياء.
bool globalSearchMatches(String? haystack, String normalizedQuery) {
  if (haystack == null || haystack.isEmpty || normalizedQuery.isEmpty) return false;
  return normalizeForCategoryNameComparison(haystack).contains(normalizedQuery);
}

String normalizeForCategoryNameComparison(String s) {
  return s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[ً-ْٰ]'), '') // حركات/تشكيل عربي
      .replaceAll(RegExp(r'[إأآا]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ');
}
