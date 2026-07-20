import 'package:flutter/material.dart';
import '../../../core/app_radius.dart';
import '../../../core/document_status.dart';
import '../../../models/document.dart';

/// بطاقة مستند قابلة للتحديد (Checkbox) — تُستخدم في شاشات اختيار مستندات
/// عبر أكثر من فندق (كشاشة "إضافة مستند" داخل مجلد). تعرض كل ما يميّز
/// المستند عن نظرائه بنفس الاسم في فنادق أخرى: اسم الفندق (اختياري — يُخفى
/// إن كان الفندق معروفاً مسبقاً من فلتر الشاشة)، فئة المستند، تاريخ الانتهاء
/// إن وُجد، وحالة المستند بلونها. مستقلة عن [DocumentCard] (المستخدمة في
/// شاشات "فتح مستند") لأن نمط العرض/التفاعل هنا مختلف جوهرياً (تحديد متعدد
/// لا فتح فردي)، تفادياً لتحميل ذلك الودجت بمسؤوليتين مختلفتين.
class SelectableDocumentCard extends StatelessWidget {
  final Document document;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? hotelLabel;

  const SelectableDocumentCard({
    super.key,
    required this.document,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.hotelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final status = DocumentStatus.fromExpiryDate(document.expiryDate);
    final title = document.typeName ?? document.name;
    final hasExpiry = document.expiryDate.trim().isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: selected ? 1.4 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: selected, onChanged: (_) => onTap()),
              CircleAvatar(radius: 16, backgroundColor: status.color, child: Icon(status.icon, color: Colors.white, size: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                        Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        if (hotelLabel != null)
                          _MetaChip(icon: Icons.apartment_outlined, text: hotelLabel!),
                        if (document.categoryName != null)
                          _MetaChip(icon: Icons.label_outline, text: document.categoryName!),
                        if (hasExpiry)
                          _MetaChip(icon: Icons.event_outlined, text: document.expiryDate),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
