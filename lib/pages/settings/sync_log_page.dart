import 'package:flutter/material.dart';

import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';

/// سجل عمليات المزامنة — فارغ صادقاً حالياً لأن المزامنة السحابية غير
/// مفعَّلة بعد؛ الصفحة جاهزة لعرض عمليات حقيقية فور ربط خدمة سحابية.
class SyncLogPage extends StatelessWidget {
  const SyncLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("سجل عمليات المزامنة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
              const SizedBox(height: AppSizes.md),
              const Text("لا توجد عمليات مزامنة مسجَّلة", style: AppTextStyles.bodyBold),
              const SizedBox(height: AppSizes.xs),
              const Text(
                "المزامنة السحابية غير مفعَّلة في هذا الإصدار — سيبدأ هذا السجل بعرض العمليات الفعلية فور تفعيلها.",
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
