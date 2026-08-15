import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/app_colors.dart';
import '../../core/app_page_route.dart';
import '../../core/app_preferences.dart';
import '../../core/app_radius.dart';
import '../../core/app_permissions.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/permission_service.dart';
import '../../services/security_service.dart';
import '../../services/session_service.dart';
import '../login/pin_login_page.dart';
import '../login/security_setup_page.dart';
import '../users/users_page.dart';

/// الأمان: الرمز السري، البصمة، إخفاء الأرصدة، وضع التجربة، المستخدمون
/// والصلاحيات، حذف الرمز، تسجيل الخروج — منقولة من SettingsPage القديمة
/// حرفياً (بلا أي تغيير سلوك) عند تقسيم الإعدادات إلى فئات رئيسية.
class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _securityService = SecurityService.instance;
  bool _isLoading = true;

  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricLabel = "الدخول البيومتري";
  int _pinLength = 4;
  bool _hideBalances = false;
  bool _trialMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometricTypes = await _securityService.getAvailableBiometricTypes();
    final canCheck = await _securityService.canCheckBiometrics();

    _biometricEnabled = await _securityService.isBiometricEnabled();
    _pinLength = await _securityService.getPinLength();
    _biometricAvailable = canCheck;
    _biometricLabel = _computeBiometricLabel(biometricTypes);
    _hideBalances = await AppPreferences.getBool(AppPreferences.keyHideBalances);
    _trialMode = await AppPreferences.getBool(AppPreferences.keyTrialMode);

    if (mounted) setState(() => _isLoading = false);
  }

  String _computeBiometricLabel(List<BiometricType> types) {
    final hasFace = types.contains(BiometricType.face);
    final hasFingerprint = types.contains(BiometricType.fingerprint) || types.contains(BiometricType.strong) || types.contains(BiometricType.weak);
    if (hasFace && hasFingerprint) return "الدخول بالبصمة أو الوجه";
    if (hasFace) return "الدخول بالتعرف على الوجه";
    if (hasFingerprint) return "الدخول بالبصمة";
    return "الدخول البيومتري";
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("الأمان", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildCard([
                  ListTile(
                    leading: Icon(Icons.lock_outline, color: primary),
                    title: const Text("تغيير الرمز السري"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context, premiumRoute(const SecuritySetupPage())),
                  ),
                  const Divider(height: 1, indent: 50),
                  SwitchListTile(
                    secondary: Icon(Icons.fingerprint, color: primary),
                    title: Text(_biometricLabel),
                    subtitle: _biometricAvailable ? null : const Text("جهازك لا يدعم هذه الميزة أو لم يتم إعدادها", style: AppTextStyles.caption),
                    value: _biometricEnabled,
                    activeThumbColor: primary,
                    onChanged: !_biometricAvailable
                        ? null
                        : (value) async {
                            await _securityService.setBiometricEnabled(value);
                            if (!mounted) return;
                            setState(() => _biometricEnabled = value);
                          },
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: Icon(Icons.pin, color: primary),
                    title: const Text("عدد أرقام الرمز"),
                    subtitle: Text("الحالي: $_pinLength أرقام"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showPinLengthDialog,
                  ),
                  const Divider(height: 1, indent: 50),
                  SwitchListTile(
                    secondary: Icon(Icons.visibility_off_outlined, color: primary),
                    title: const Text("إخفاء الأرصدة داخل التطبيق"),
                    value: _hideBalances,
                    activeThumbColor: primary,
                    onChanged: (value) async {
                      await AppPreferences.setBool(AppPreferences.keyHideBalances, value);
                      if (!mounted) return;
                      setState(() => _hideBalances = value);
                    },
                  ),
                  const Divider(height: 1, indent: 50),
                  SwitchListTile(
                    secondary: Icon(Icons.science_outlined, color: primary),
                    title: const Text("وضع التجربة"),
                    subtitle: const Text("يسمح بتكرار/تعديل/حذف التقرير المالي اليومي بحرية أثناء الاختبار", style: TextStyle(fontSize: 11)),
                    value: _trialMode,
                    activeThumbColor: primary,
                    onChanged: (value) async {
                      await AppPreferences.setBool(AppPreferences.keyTrialMode, value);
                      if (!mounted) return;
                      setState(() => _trialMode = value);
                    },
                  ),
                  if (PermissionService.instance.hasPermission(AppPermissions.usersView)) ...[
                    const Divider(height: 1, indent: 50),
                    ListTile(
                      leading: Icon(Icons.manage_accounts_outlined, color: primary),
                      title: const Text("المستخدمون والصلاحيات"),
                      subtitle: const Text("إنشاء حسابات موظفين، وتحديد وصولهم للفنادق والصلاحيات", style: AppTextStyles.caption),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.push(context, premiumRoute(const UsersPage())),
                    ),
                  ],
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                    title: const Text("حذف الرمز وإعادة الإعداد", style: TextStyle(color: AppColors.danger)),
                    onTap: _showResetSecurityDialog,
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                    title: const Text("تسجيل الخروج", style: TextStyle(color: AppColors.danger)),
                    onTap: _showLogoutDialog,
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Column(children: children),
    );
  }

  void _showPinLengthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تغيير عدد أرقام الرمز"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("4 أرقام"),
              leading: Icon(_pinLength == 4 ? Icons.radio_button_checked : Icons.radio_button_off, color: _pinLength == 4 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
              onTap: () {
                _updatePinLength(4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("6 أرقام"),
              leading: Icon(_pinLength == 6 ? Icons.radio_button_checked : Icons.radio_button_off, color: _pinLength == 6 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
              onTap: () {
                _updatePinLength(6);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePinLength(int length) async {
    await _securityService.setPinLength(length);
    setState(() => _pinLength = length);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إعادة إعداد الرمز السري بالطول الجديد")));
    Navigator.push(context, premiumRoute(const SecuritySetupPage()));
  }

  void _showResetSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف بيانات الأمان"),
        content: const Text("هل أنت متأكد من حذف الرمز السري وإلغاء البصمة؟ سيتعين عليك إعدادهما مرة أخرى."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              await _securityService.clearAll();
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(context, premiumRoute(const SecuritySetupPage()), (route) => false);
            },
            child: const Text("حذف", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تسجيل الخروج", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من رغبتك في تسجيل الخروج؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("إلغاء", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          TextButton(
            onPressed: () {
              // مسح جلسة المستخدم الحالي (إن وُجدت) — لا يجب أن يرث الموظف
              // التالي الذي يستخدم هذا الجهاز صلاحيات آخر من سجَّل خروجه.
              SessionService.instance.logout();
              PermissionService.instance.clear();
              Navigator.pushAndRemoveUntil(context, premiumRoute(const PinLoginPage()), (route) => false);
            },
            child: const Text("تسجيل الخروج", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
