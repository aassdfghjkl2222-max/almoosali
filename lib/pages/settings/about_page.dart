import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';

/// صفحة "حول التطبيق" — معلومات حقيقية فقط من AppConfig (نفس المصدر
/// المستخدم أصلاً داخل شاشة الإعدادات)، بلا أي بيانات وهمية.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("حول التطبيق"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.apartment, color: AppColors.primary, size: 48),
                ),
                const SizedBox(height: AppSizes.md),
                Text(AppConfig.companyNameAr, style: AppTextStyles.title, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(AppConfig.companyNameEn, style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text("الإصدار ${AppConfig.version}", style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          _buildCard([
            _infoRow("اسم التطبيق", AppConfig.appName),
            _infoRow("الجهة المالكة", AppConfig.companyNameAr),
            _infoRow("رقم الإصدار", AppConfig.version),
            _infoRow("إصدار قاعدة البيانات", "24"),
          ]),
          const SizedBox(height: AppSizes.md),
          _buildCard([
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "تطبيق منازل هو نظام إدارة داخلي لمجموعة فنادق شركة منازل البيت المحدودة، يغطي المستندات والموظفين والتقارير المالية اليومية والمركز المالي والعقود والعلاقات المالية بين المنشآت.",
                style: AppTextStyles.body,
              ),
            ),
          ]),
          const SizedBox(height: AppSizes.md),
          _buildCard([
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.history_outlined, color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text("سجل التحديثات", style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text("لا يوجد سجل تحديثات منشور بعد لهذا الإصدار.", style: AppTextStyles.caption),
            ),
          ]),
          const SizedBox(height: AppSizes.lg),
          Center(
            child: Text("© ${DateTime.now().year} ${AppConfig.companyNameAr} — جميع الحقوق محفوظة", style: AppTextStyles.caption.copyWith(fontSize: 11), textAlign: TextAlign.center),
          ),
          const SizedBox(height: AppSizes.md),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.caption)),
          Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
