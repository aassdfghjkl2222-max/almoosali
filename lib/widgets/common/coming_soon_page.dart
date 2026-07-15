import 'package:flutter/material.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';

/// صفحة "قيد الإعداد" عامة لأي قسم في التطبيق لم تُبنَ وظائفه الكاملة بعد
/// (هيكل تنقّل فقط في مرحلته الأولى) — ودجت واحد مشترك بلا ارتباط بأي قسم
/// معيّن، يُعاد استخدامه بدل صفحة شبه مكررة لكل قسم جديد (البيانات المرجعية،
/// المستندات، وأي قسم مستقبلي).
class ComingSoonPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const ComingSoonPage({
    super.key,
    required this.title,
    required this.icon,
    this.description = "سيتوفر ضمن مراحل قادمة من هذا القسم.",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: AppSizes.lg),
              Text("هذا القسم قيد الإعداد", style: AppTextStyles.title.copyWith(fontSize: 18)),
              const SizedBox(height: AppSizes.sm),
              Text(
                description,
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
