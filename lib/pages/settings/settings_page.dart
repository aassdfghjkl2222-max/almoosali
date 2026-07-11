import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/security_service.dart';
import '../login/security_setup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _securityService = SecurityService.instance;
  bool _biometricEnabled = false;
  int _pinLength = 4;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _biometricEnabled = await _securityService.isBiometricEnabled();
    _pinLength = await _securityService.getPinLength();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "الإعدادات",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              _buildSectionTitle("الأمان"),
              _buildSecuritySection(),
              const SizedBox(height: AppSizes.lg),
              _buildSectionTitle("عن التطبيق"),
              _buildAppInfo(),
            ],
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm, right: AppSizes.xs),
      child: Text(
        title,
        style: AppTextStyles.subtitle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
            title: const Text("تغيير الرمز السري"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecuritySetupPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 50),
          SwitchListTile(
            secondary: Icon(Icons.fingerprint, color: Theme.of(context).colorScheme.primary),
            title: const Text("الدخول بالبصمة"),
            value: _biometricEnabled,
            activeThumbColor: Theme.of(context).colorScheme.primary,
            onChanged: (value) async {
              final canCheck = await _securityService.canCheckBiometrics();
              if (canCheck) {
                await _securityService.setBiometricEnabled(value);
                if (!mounted) return;
                setState(() => _biometricEnabled = value);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("جهازك لا يدعم البصمة أو لم يتم إعدادها")),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 50),
          ListTile(
            leading: Icon(Icons.pin, color: Theme.of(context).colorScheme.primary),
            title: const Text("عدد أرقام الرمز"),
            subtitle: Text("الحالي: $_pinLength أرقام"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showPinLengthDialog,
          ),
          const Divider(height: 1, indent: 50),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
            title: const Text("حذف الرمز وإعادة الإعداد", style: TextStyle(color: AppColors.danger)),
            onTap: _showResetSecurityDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
            title: const Text("الإصدار"),
            trailing: const Text("1.0.0"),
          ),
        ],
      ),
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
              leading: Icon(
                _pinLength == 4 ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _pinLength == 4 ? Theme.of(context).colorScheme.primary : AppColors.textSecondary,
              ),
              onTap: () {
                _updatePinLength(4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("6 أرقام"),
              leading: Icon(
                _pinLength == 6 ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _pinLength == 6 ? Theme.of(context).colorScheme.primary : AppColors.textSecondary,
              ),
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
    // نطلب من المستخدم إعادة إعداد الرمز بالطول الجديد
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("يرجى إعادة إعداد الرمز السري بالطول الجديد")),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecuritySetupPage()),
    );
  }

  void _showResetSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف بيانات الأمان"),
        content: const Text("هل أنت متأكد من حذف الرمز السري وإلغاء البصمة؟ سيتعين عليك إعدادهما مرة أخرى."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () async {
              await _securityService.clearAll();
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SecuritySetupPage()),
                (route) => false,
              );
            },
            child: const Text("حذف", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
