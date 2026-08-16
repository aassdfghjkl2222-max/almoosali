/// عنصر واحد معروض في شاشة "سلة المهملات" — بناء عرض فقط (لا يُكتب لقاعدة
/// البيانات)، يُبنى من صف خام في TrashRepository.listAll().
class TrashedItem {
  final String type;
  final String typeLabel;
  final int id;
  final String name;
  final DateTime deletedAt;

  const TrashedItem({
    required this.type,
    required this.typeLabel,
    required this.id,
    required this.name,
    required this.deletedAt,
  });

  static const retentionDays = 30;

  int get remainingDays {
    final elapsed = DateTime.now().difference(deletedAt).inDays;
    final remaining = retentionDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isOverdue => DateTime.now().difference(deletedAt).inDays >= retentionDays;
}
