/// محرك توزيع مبلغ إجمالي على مجموعة عناصر (منشآت هنا، لكن بلا أي اعتماد على
/// Hotel — قابل لإعادة الاستخدام لأي توزيع مستقبلي مشابه). القاعدة: أي عنصر
/// ضمن [manuallyEditedIds] يحتفظ بقيمته الحالية من [currentAmounts] كما هي
/// تماماً، والباقي (العناصر "التلقائية") يتقاسم (total - مجموع القيم اليدوية)
/// بالتساوي. فرق التقريب الناتج عن قسمة غير مستوية (مثل 900/3 أو 1000/3)
/// يُمتَص بالكامل في آخر عنصر تلقائي حتى يتطابق مجموع الناتج مع total تماماً
/// (لا تراكم فروقاً صغيرة يظهرها شريط "المتبقي" كخطأ تقريب وهمي).
class ExpenseDistributionEngine {
  ExpenseDistributionEngine._();

  static double _round2(double v) => (v * 100).round() / 100;

  /// يعيد خريطة معرّف العنصر → المبلغ الموزَّع عليه. عناصر [propertyIds] التي
  /// لا تظهر في [manuallyEditedIds] "تلقائية" ويُعاد حساب حصتها دائماً؛ إن كان
  /// المبلغ المتبقي بعد خصم الحصص اليدوية صفراً أو سالباً (توزيع يدوي زائد
  /// بالفعل) تُعاد حصص العناصر التلقائية صفراً — لا قسمة على قيمة سالبة.
  static Map<int, double> distribute({
    required double total,
    required List<int> propertyIds,
    required Set<int> manuallyEditedIds,
    required Map<int, double> currentAmounts,
  }) {
    if (propertyIds.isEmpty) return {};

    final result = <int, double>{};
    double lockedSum = 0;
    final autoIds = <int>[];
    for (final id in propertyIds) {
      if (manuallyEditedIds.contains(id)) {
        final v = _round2(currentAmounts[id] ?? 0);
        result[id] = v;
        lockedSum += v;
      } else {
        autoIds.add(id);
      }
    }

    if (autoIds.isEmpty) return result;

    final remaining = _round2(total - lockedSum);
    if (remaining <= 0) {
      for (final id in autoIds) {
        result[id] = 0;
      }
      return result;
    }

    final share = _round2(remaining / autoIds.length);
    double runningSum = 0;
    for (var i = 0; i < autoIds.length; i++) {
      if (i == autoIds.length - 1) {
        result[autoIds[i]] = _round2(remaining - runningSum);
      } else {
        result[autoIds[i]] = share;
        runningSum += share;
      }
    }
    return result;
  }
}
