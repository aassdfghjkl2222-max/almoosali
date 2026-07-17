/// بند دائم قابل لإعادة الاستخدام داخل التقرير المالي اليومي (إيراد أو
/// مصروف) — مثل "ماكينة القهوة"، "المغسلة"، "مواقف السيارات". لا يظهر
/// تلقائياً داخل شاشة التقرير؛ يظهر فقط عند الضغط على "➕ إضافة بند" في قسم
/// الإيرادات أو المصروفات. التقارير المحفوظة سابقاً تحتفظ بنسخة كاملة
/// (اسم/مبلغ/مصدر) داخل details_json الخاص بها، فلا ترتبط بهذا الجدول عبر
/// مفتاح خارجي — حذف بند من هنا لا يمسّ أي تقرير سابق يستخدمه.
class FinancialReportItem {
  static const typeRevenue = 'revenue';
  static const typeExpense = 'expense';

  final int? id;
  final String name;
  final String type; // 'revenue' | 'expense'
  final String? defaultFundingSource; // للإيراد فقط: نقد/شبكة/تحويل بنكي
  final bool isVisible;
  final int sortOrder;
  final String createdAt;

  const FinancialReportItem({
    this.id,
    required this.name,
    required this.type,
    this.defaultFundingSource,
    this.isVisible = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'default_funding_source': defaultFundingSource,
      'is_visible': isVisible ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt,
    };
  }

  factory FinancialReportItem.fromMap(Map<String, dynamic> map) {
    return FinancialReportItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      defaultFundingSource: map['default_funding_source'] as String?,
      isVisible: (map['is_visible'] as int? ?? 1) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: map['created_at'] as String,
    );
  }

  FinancialReportItem copyWith({
    int? id,
    String? name,
    String? type,
    String? defaultFundingSource,
    bool? isVisible,
    int? sortOrder,
    String? createdAt,
  }) {
    return FinancialReportItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      defaultFundingSource: defaultFundingSource ?? this.defaultFundingSource,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
