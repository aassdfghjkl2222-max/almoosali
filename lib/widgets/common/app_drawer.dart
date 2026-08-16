import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_page_route.dart';
import '../../core/app_permissions.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../repositories/hotel_repository.dart';
import '../../services/permission_service.dart';
import '../../pages/notes/notes_page.dart';
import '../../pages/settings/about_page.dart';
import '../../pages/settings/backup_page.dart';
import '../../pages/settings/settings_page.dart';
import '../../pages/settings/support_page.dart';
import '../../pages/settlements/pages/supplier_debts_page.dart';
import '../../pages/dashboard/pages/hotels_page.dart';
import '../../pages/contracts/contracts_page.dart';
import '../../pages/documents/documents_hub_page.dart';
import '../../pages/documents/contract_documents/contract_folder_browser_page.dart';
import '../../pages/login/pin_login_page.dart';
import '../../pages/master_data/master_data_hub_page.dart';
import '../../pages/trash/trash_bin_page.dart';

/// القائمة الرئيسية — مخصصة للأنظمة العامة الخاصة بالتطبيق فقط. أي نظام
/// تشغيلي خاص بفندق معيّن (التقرير اليومي، مركز التحليل، المركز المالي،
/// الموظفون، المستندات، المصروفات...) يبقى داخل لوحة تحكم ذلك الفندق ولا
/// يظهر هنا، تماماً كما هو مطبَّق فعلاً في dashboard_page.dart.
///
/// "المستخدمون والصلاحيات" انتقلت إلى الإعدادات ← الأمان (راجع
/// SettingsPage/SecuritySettingsPage) — ليست في هذه القائمة الجانبية.
class AppDrawer extends StatelessWidget {
  final Hotel? hotel;
  const AppDrawer({super.key, this.hotel});

  Color _identityColor(BuildContext context) {
    return hotel != null ? HotelVisualIdentity.colorForHotel(hotel) : AppColors.primary;
  }

  /// يفتح صفحة خاصة بفندق: مباشرة إن كان هناك فندق في السياق الحالي، وإلا
  /// يعرض قائمة اختيار فندق أولاً (بلا تحميل أي بيانات إلا عند الحاجة فعلاً).
  Future<void> _openHotelScoped(BuildContext context, String pickerTitle, Widget Function(Hotel) builder) async {
    if (hotel != null) {
      Navigator.push(context, premiumRoute(builder(hotel!)));
      return;
    }
    final hotels = await HotelRepository().getAllHotels();
    if (!context.mounted) return;
    final chosen = await showModalBottomSheet<Hotel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => _HotelPickerSheet(title: pickerTitle, hotels: hotels),
    );
    if (chosen != null && context.mounted) {
      Navigator.push(context, premiumRoute(builder(chosen)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _identityColor(context);
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(color),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.md, horizontal: AppSizes.sm),
              children: [
                _drawerItem(
                  context: context,
                  icon: Icons.home_work_rounded,
                  title: "الصفحة الرئيسية",
                  subtitle: "قائمة الفنادق",
                  color: color,
                  onTap: () => Navigator.pushAndRemoveUntil(context, premiumRoute(const HotelsPage()), (route) => false),
                ),
                if (PermissionService.instance.hasPermission(AppPermissions.documentsView))
                  _drawerItem(
                    context: context,
                    icon: Icons.folder_outlined,
                    title: "المستندات",
                    subtitle: "كل مستندات التطبيق في مكان واحد",
                    color: color,
                    onTap: () => Navigator.push(context, premiumRoute(const DocumentsHubPage())),
                  ),
                if (PermissionService.instance.hasPermission(AppPermissions.contractsView))
                  _drawerItem(
                    context: context,
                    icon: Icons.assignment_outlined,
                    title: "العقود",
                    color: color,
                    onTap: () => _openHotelScoped(context, "اختر الفندق لعرض عقوده", (h) => ContractsPage(hotel: h)),
                  ),
                _drawerItem(
                  context: context,
                  icon: Icons.snippet_folder_outlined,
                  title: "مستندات العقود",
                  subtitle: "مجلدات متداخلة على مستوى الشركة",
                  color: color,
                  onTap: () => Navigator.push(context, premiumRoute(const ContractFolderBrowserPage())),
                ),
                if (PermissionService.instance.hasPermission(AppPermissions.suppliersView))
                  _drawerItem(
                    context: context,
                    icon: Icons.local_shipping_outlined,
                    title: "الموردون",
                    color: color,
                    onTap: () => _openHotelScoped(context, "اختر الفندق لعرض مورديه", (h) => SupplierDebtsPage(hotel: h)),
                  ),
                _drawerItem(
                  context: context,
                  icon: Icons.note_alt_outlined,
                  title: "الملاحظات",
                  color: color,
                  onTap: () => _openHotelScoped(context, "اختر الفندق لعرض ملاحظاته", (h) => NotesPage(hotel: h)),
                ),
                _drawerItem(
                  context: context,
                  icon: Icons.library_books_outlined,
                  title: "البيانات المرجعية",
                  subtitle: "بيانات مشتركة بين كل الفنادق",
                  color: color,
                  onTap: () => Navigator.push(context, premiumRoute(const MasterDataHubPage())),
                ),
                if (PermissionService.instance.hasPermission(AppPermissions.settingsAccess))
                  _drawerItem(
                    context: context,
                    icon: Icons.delete_outline_rounded,
                    title: "سلة المهملات",
                    color: color,
                    onTap: () => Navigator.push(context, premiumRoute(const TrashBinPage())),
                  ),
                const _DrawerDivider(),
                _drawerItem(
                  context: context,
                  icon: Icons.cloud_sync_outlined,
                  title: "النسخ الاحتياطي والمزامنة",
                  color: color,
                  onTap: () => Navigator.push(context, premiumRoute(const BackupPage())),
                ),
                if (PermissionService.instance.hasPermission(AppPermissions.settingsAccess))
                  _drawerItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    title: "الإعدادات",
                    color: color,
                    onTap: () => Navigator.push(context, premiumRoute(const SettingsPage())),
                  ),
                _drawerItem(
                  context: context,
                  icon: Icons.help_outline_rounded,
                  title: "الدعم والمساعدة",
                  color: color,
                  onTap: () => Navigator.push(context, premiumRoute(const SupportPage())),
                ),
                _drawerItem(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: "حول التطبيق",
                  color: color,
                  onTap: () => Navigator.push(context, premiumRoute(const AboutPage())),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _drawerItem(
            context: context,
            icon: Icons.logout_rounded,
            title: "تسجيل الخروج",
            color: AppColors.danger,
            onTap: () => _showLogoutDialog(context),
          ),
          const SizedBox(height: AppSizes.sm),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: EdgeInsets.only(top: 48, bottom: AppSizes.lg, left: AppSizes.md, right: AppSizes.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(AppRadius.lg), bottomRight: Radius.circular(AppRadius.lg)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.apartment, color: Colors.white, size: AppSizes.iconLarge),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hotel?.arabicName ?? AppConfig.appName, style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(hotel != null ? AppConfig.companyNameAr : "نظام إدارة الفنادق", style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.75), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subtitle != null) Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تسجيل الخروج", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من رغبتك في تسجيل الخروج؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("إلغاء", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          TextButton(
            onPressed: () => Navigator.pushAndRemoveUntil(context, premiumRoute(const PinLoginPage()), (route) => false),
            child: const Text("تسجيل الخروج", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.sm),
      child: Divider(height: AppSizes.lg),
    );
  }
}

class _HotelPickerSheet extends StatelessWidget {
  final String title;
  final List<Hotel> hotels;
  const _HotelPickerSheet({required this.title, required this.hotels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.title.copyWith(fontSize: 17)),
            const SizedBox(height: AppSizes.sm),
            const Divider(height: 1),
            Flexible(
              child: hotels.isEmpty
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("لا توجد فنادق مسجَّلة", style: AppTextStyles.caption)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: hotels.length,
                      itemBuilder: (_, i) {
                        final h = hotels[i];
                        return ListTile(
                          leading: CircleAvatar(radius: 10, backgroundColor: HotelVisualIdentity.colorForHotel(h)),
                          title: Text(h.arabicName, style: AppTextStyles.bodyBold),
                          onTap: () => Navigator.pop(context, h),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
