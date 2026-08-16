import 'package:intl/intl.dart';

/// سجل ثابت لكل نوع كيان "قابل للحذف الناعم" عبر سلة المهملات الموحّدة —
/// راجع lib/repositories/trash_repository.dart وlib/pages/trash/trash_bin_page.dart.
///
/// الفنادق والموظفون **غير مُدرَجين هنا عمداً**: يحتفظان بنظامهما الحالي
/// كاملاً (RecycleBinPage بحمايته الرباعية للفنادق، is_archived بلا حذف
/// نهائي للموظفين) — سلة المهملات الموحّدة تصل إليهما عبر بطاقة تنقّل إلى
/// شاشتيهما الحاليتين بدل تفكيك حمايتهما إلى الحوارات العامة هنا.
class TrashableEntity {
  final String type;
  final String table;
  final String label;
  final String Function(Map<String, dynamic> row) displayName;

  const TrashableEntity({
    required this.type,
    required this.table,
    required this.label,
    required this.displayName,
  });
}

String _fmtAmount(dynamic amount) {
  final n = (amount is num) ? amount.toDouble() : double.tryParse('$amount') ?? 0;
  return NumberFormat("#,##0.##").format(n);
}

/// كل الأنواع المشمولة بالمرحلة الأولى من سلة المهملات الموحّدة — إضافة نوع
/// جديد مستقبلاً هي تسجيل واحد هنا (+ عمود is_deleted على جدوله عبر
/// DatabaseService._trashableTables) بلا أي تعديل آخر في الشاشة أو المستودع
/// العام (راجع متطلب "أي وحدة مستقبلية تدعم السلة تلقائياً").
const List<TrashableEntity> trashableEntities = [
  TrashableEntity(type: 'document', table: 'documents', label: 'مستند', displayName: _name),
  TrashableEntity(type: 'note', table: 'notes', label: 'ملاحظة', displayName: _noteName),
  TrashableEntity(type: 'contract', table: 'contracts', label: 'عقد', displayName: _name),
  TrashableEntity(type: 'contract_payment', table: 'contract_payments', label: 'دفعة عقد', displayName: _amountRow),
  TrashableEntity(type: 'invoice', table: 'invoices', label: 'فاتورة', displayName: _invoiceName),
  TrashableEntity(type: 'settlement', table: 'settlements', label: 'تسوية', displayName: _settlementName),
  TrashableEntity(type: 'pending_expense', table: 'pending_expenses', label: 'مصروف معلَّق', displayName: _statementRow),
  TrashableEntity(type: 'shared_expense', table: 'shared_expenses', label: 'مصروف مشترك', displayName: _sharedExpenseName),
  TrashableEntity(type: 'inter_entity_transfer', table: 'inter_entity_transfers', label: 'تحويل بين المنشآت', displayName: _statementRow),
];

String _name(Map<String, dynamic> row) => (row['name'] as String?)?.trim().isNotEmpty == true ? row['name'] : 'بلا اسم';
String _noteName(Map<String, dynamic> row) => (row['title'] as String?)?.trim().isNotEmpty == true ? row['title'] : 'ملاحظة بلا عنوان';
String _statementRow(Map<String, dynamic> row) => (row['statement'] as String?)?.trim().isNotEmpty == true ? row['statement'] : 'بلا بيان';
String _invoiceName(Map<String, dynamic> row) => 'فاتورة رقم ${row['invoice_number'] ?? '—'} — ${_fmtAmount(row['total_amount'])} ريال';
String _settlementName(Map<String, dynamic> row) => (row['description'] as String?)?.trim().isNotEmpty == true ? row['description'] : 'تسوية — ${_fmtAmount(row['amount'])} ريال';
String _sharedExpenseName(Map<String, dynamic> row) => (row['description'] as String?)?.trim().isNotEmpty == true ? row['description'] : 'مصروف مشترك — ${_fmtAmount(row['total_amount'])} ريال';
String _amountRow(Map<String, dynamic> row) => 'دفعة بمبلغ ${_fmtAmount(row['amount'])} ريال';
