import 'package:flutter/material.dart';

import '../../../../core/app_sizes.dart';
import '../../../../core/app_text_styles.dart';

/// حالة فارغة موحَّدة لكل شاشات وحدة مستندات العقود (لا مجلدات/لا مستندات/لا
/// نتائج بحث/أرشيف فارغ) — فرق واحد فقط: الأيقونة والعنوان والرسالة.
class ContractEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const ContractEmptyState({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: Colors.grey.shade400),
            ),
            const SizedBox(height: AppSizes.md),
            Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
