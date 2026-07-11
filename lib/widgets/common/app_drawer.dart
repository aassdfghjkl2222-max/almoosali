import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../pages/dashboard/dashboard_page.dart';
import '../../pages/notes/notes_page.dart';
import '../../pages/alerts/alerts_page.dart';
import '../../pages/settings/backup_page.dart';
import '../../pages/users/users_page.dart';
import '../../pages/dashboard/pages/hotels_page.dart';
import '../../pages/settlements/settlements_hub_page.dart';
import '../../pages/vault/vault_dashboard_page.dart';
import '../../pages/invoices/invoices_page.dart';
import '../../pages/contracts/contracts_page.dart';
import '../../pages/settings/settings_page.dart';
import '../../pages/login/pin_login_page.dart';

class AppDrawer extends StatelessWidget {
  final Hotel? hotel;
  const AppDrawer({super.key, this.hotel});

  @override
  Widget build(BuildContext context) {
    // محاولة الحصول على اسم الصفحة الحالية لتمييزها
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              children: [
                _drawerItem(
                  context: context,
                  icon: Icons.home_work_rounded,
                  title: "الصفحة الرئيسية",
                  isActive: currentRoute == '/hotels' || currentRoute == null,
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HotelsPage()),
                      (route) => false,
                    );
                  },
                ),
                if (hotel != null) ...[
                  _drawerItem(
                    context: context,
                    icon: Icons.dashboard_outlined,
                    title: "لوحة التحكم",
                    isActive: false,
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => DashboardPage(hotel: hotel!)),
                        (route) => false,
                      );
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.receipt_long_rounded,
                    title: "الفواتير الإلكترونية",
                    isActive: currentRoute == '/invoices',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InvoicesPage(hotel: hotel!)),
                      );
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.account_balance_rounded,
                    title: "المركز المالي",
                    isActive: currentRoute == '/vault',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => VaultDashboardPage(hotel: hotel!)),
                      );
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.note_alt_outlined,
                    title: "المذكرات",
                    isActive: currentRoute == '/notes',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NotesPage(hotel: hotel!)),
                      );
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.assignment_outlined,
                    title: "العقود",
                    isActive: currentRoute == '/contracts',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ContractsPage(hotel: hotel!)),
                      );
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: "التسويات المالية",
                    isActive: currentRoute == '/settlements',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SettlementsHubPage(hotel: hotel!)),
                      );
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.notifications_none_rounded,
                    title: "التنبيهات",
                    isActive: currentRoute == '/alerts',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AlertsPage(hotel: hotel!)),
                      );
                    },
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: Divider(height: AppSizes.xl),
                ),
                _drawerItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: "الإعدادات",
                  isActive: currentRoute == '/settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
                _drawerItem(
                  context: context,
                  icon: Icons.cloud_upload_outlined,
                  title: "النسخ الاحتياطي",
                  isActive: currentRoute == '/backup',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BackupPage()),
                    );
                  },
                ),
                _drawerItem(
                  context: context,
                  icon: Icons.sync_rounded,
                  title: "المزامنة",
                  isActive: currentRoute == '/sync',
                  onTap: () {},
                ),
                _drawerItem(
                  context: context,
                  icon: Icons.people_outline_rounded,
                  title: "المستخدمون",
                  isActive: currentRoute == '/users',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsersPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _drawerItem(
            context: context,
            icon: Icons.logout_rounded,
            title: "تسجيل الخروج",
            iconColor: AppColors.danger,
            textColor: AppColors.danger,
            onTap: () => _showLogoutDialog(context),
          ),
          const SizedBox(height: AppSizes.md),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSizes.md,
        bottom: AppSizes.lg,
        left: AppSizes.md,
        right: AppSizes.md,
      ),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.lg),
          bottomRight: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.apartment,
                  color: theme.colorScheme.secondary,
                  size: AppSizes.iconLarge,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConfig.appName,
                      style: AppTextStyles.title.copyWith(color: Colors.white),
                    ),
                    Text(
                      AppConfig.companyNameAr,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.secondary,
                child: Text(
                  "م", // أول حرف من مدير
                  style: AppTextStyles.bodyBold.copyWith(color: theme.primaryColor),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "مدير النظام",
                    style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                  ),
                  Text(
                    "admin@manazel.com",
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
    Color? iconColor,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive
              ? theme.primaryColor
              : (iconColor ?? AppColors.textSecondary),
          size: 24,
        ),
        title: Text(
          title,
          style: AppTextStyles.body.copyWith(
            color: isActive
                ? theme.primaryColor
                : (textColor ?? AppColors.textPrimary),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isActive,
        selectedTileColor: theme.primaryColor.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text("تسجيل الخروج", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من رغبتك في تسجيل الخروج؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const PinLoginPage()),
                (route) => false,
              );
            },
            child: const Text(
              "تسجيل الخروج",
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
