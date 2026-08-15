import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import '../../core/app_page_route.dart';
import '../../core/app_permissions.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/common/permission_gate.dart';
import 'about_page.dart';
import 'ai_invoice_ocr_settings_page.dart';
import 'appearance_settings_page.dart';
import 'data_info_page.dart';
import 'financial_categories_page.dart';
import 'hotel_management_page.dart';
import 'notifications_settings_page.dart';
import 'security_settings_page.dart';
import 'support_page.dart';
import 'system_status_page.dart';
import 'training_mode_settings_page.dart';

/// "الإعدادات" — شاشة رئيسية تعرض فئات رئيسية فقط (بطاقات)، كل فئة تفتح
/// صفحتها التفصيلية الخاصة. الأقسام التفصيلية (الأمان/المظهر/الإشعارات/
/// حالة النظام/وضع التدريب) انتقلت إلى ملفاتها الخاصة (security_settings_page.dart
/// وغيرها) بلا أي تغيير في منطقها الداخلي — فقط إعادة تنظيم شكلي لتبسيط
/// الشاشة الرئيسية.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: AppPermissions.settingsAccess,
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("الإعدادات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          _categoryCard(
            context,
            icon: Icons.shield_outlined,
            title: "الأمان",
            subtitle: "الرمز السري، البصمة، المستخدمون والصلاحيات",
            onTap: () => Navigator.push(context, premiumRoute(const SecuritySettingsPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.apartment_outlined,
            title: "إدارة الفنادق",
            subtitle: "إضافة وتعديل وأرشفة الفنادق، وسلة المحذوفات",
            onTap: () => Navigator.push(context, premiumRoute(const HotelManagementPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.category_outlined,
            title: "الفئات المالية",
            subtitle: "تصنيفات المصروفات والإيرادات — مشتركة بين كل الفنادق",
            onTap: () => Navigator.push(context, premiumRoute(const FinancialCategoriesPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.notifications_outlined,
            title: "الإشعارات",
            subtitle: "تذكيرات انتهاء المستندات، الصوت والاهتزاز",
            onTap: () => Navigator.push(context, premiumRoute(const NotificationsSettingsPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.storage_outlined,
            title: "البيانات",
            subtitle: "حجم قاعدة البيانات وعدد السجلات",
            onTap: () => Navigator.push(context, premiumRoute(const DataInfoPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.auto_awesome_outlined,
            title: "القراءة الذكية للفواتير",
            subtitle: "اختيار المزوّد ومفتاح API لقراءة الفواتير بلا رمز QR",
            onTap: () => Navigator.push(context, premiumRoute(const AiInvoiceOcrSettingsPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.school_outlined,
            title: "وضع التدريب",
            subtitle: "نسخة منفصلة كاملة من البيانات للتدريب بلا أي أثر على الحقيقية",
            onTap: () => Navigator.push(context, premiumRoute(const TrainingModeSettingsPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.monitor_heart_outlined,
            title: "حالة النظام",
            subtitle: "إصدار التطبيق، قاعدة البيانات، والمزامنة",
            onTap: () => Navigator.push(context, premiumRoute(const SystemStatusPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.palette_outlined,
            title: "المظهر",
            subtitle: "الوضع الداكن، حجم الخط، سرعة الحركة",
            onTap: () => Navigator.push(context, premiumRoute(const AppearanceSettingsPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.help_outline_rounded,
            title: "الدعم والمساعدة",
            subtitle: "الأسئلة الشائعة والإبلاغ عن مشكلة",
            onTap: () => Navigator.push(context, premiumRoute(const SupportPage())),
          ),
          _categoryCard(
            context,
            icon: Icons.info_outline_rounded,
            title: "حول التطبيق",
            subtitle: "${AppConfig.appName} — الإصدار ${AppConfig.version}",
            onTap: () => Navigator.push(context, premiumRoute(const AboutPage())),
          ),
        ],
      ),
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.xs),
        leading: CircleAvatar(backgroundColor: primary.withValues(alpha: 0.1), child: Icon(icon, color: primary)),
        title: Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
        subtitle: Text(subtitle, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
