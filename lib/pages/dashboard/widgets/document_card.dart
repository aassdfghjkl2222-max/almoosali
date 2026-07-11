import 'package:flutter/material.dart';

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
    final expiry = DateTime.tryParse(document.expiryDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String statusText = "غير معروف";
    Color statusColor = Colors.grey;

    if (expiry != null) {
      final difference = expiry.difference(today).inDays;

      if (expiry.isBefore(today)) {
        statusText = "منتهي";
        statusColor = Colors.black;
      } else if (difference <= 5) {
        statusText = "عاجل";
        statusColor = Colors.red;
      } else if (difference <= 10) {
        statusText = "تحذير";
        statusColor = Colors.red;
      } else if (difference <= 30) {
        statusText = "سينتهي قريباً";
        statusColor = Colors.orange;
      } else {
        statusText = "ساري";
        statusColor = Colors.green;
      }
    }

    return AppCard(
      onTap: onTap,
      identityAccent: identityAccent,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor,
            child: const Icon(
              Icons.description,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(document.expiryDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

}
