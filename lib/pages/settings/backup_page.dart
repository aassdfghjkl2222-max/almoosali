import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_drawer.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "النسخ الاحتياطي",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "حماية بياناتك",
              style: AppTextStyles.title,
            ),
            const SizedBox(height: AppSizes.sm),
            const Text(
              "يمكنك تصدير قاعدة البيانات الحالية لاستعادتها في أي وقت أو نقلها لجهاز آخر.",
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSizes.lg),
            AppCard(
              child: Column(
                children: [
                  _buildOption(
                    context,
                    title: "تصدير قاعدة البيانات",
                    subtitle: "حفظ نسخة من البيانات الحالية",
                    icon: Icons.upload_file,
                    onTap: () => _showNotImplemented(context),
                  ),
                  const Divider(height: AppSizes.xl),
                  _buildOption(
                    context,
                    title: "استيراد قاعدة البيانات",
                    subtitle: "استعادة بيانات من نسخة سابقة",
                    icon: Icons.download_for_offline,
                    onTap: () => _showNotImplemented(context),
                  ),
                ],
              ),
            ),
            const Spacer(),
            AppButton(
              text: "نسخ احتياطي سحابي (قريباً)",
              onPressed: () {},
              icon: Icons.cloud_done,
              backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSizes.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.sm),
            ),
            child: Icon(icon, color: primary),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyBold),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  void _showNotImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("هذه الميزة ستتوفر قريباً في التحديث القادم"),
      ),
    );
  }
}
