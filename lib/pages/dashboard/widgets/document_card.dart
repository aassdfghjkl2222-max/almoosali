import 'package:flutter/material.dart';

import '../../../core/document_status.dart';
import '../../../models/document.dart';
import '../../../widgets/common/app_card.dart';

class DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;

  /// لون هوية الفندق الحالي — طبقة تصميم إضافية اختيارية، لا تغيّر ألوان حالة المستند.
  final Color? identityAccent;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    this.identityAccent,
  });

  @override
  Widget build(BuildContext context) {
    final status = DocumentStatus.fromExpiryDate(document.expiryDate);
    final title = document.typeName ?? document.name;

    return AppCard(
      onTap: onTap,
      identityAccent: identityAccent,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: status.color,
            child: Icon(status.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    if (document.isMandatory) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.push_pin, size: 12, color: Colors.grey),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (document.categoryName != null)
                  Text(document.categoryName!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text(
            status.label,
            style: TextStyle(color: status.color, fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}
