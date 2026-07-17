import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_preferences.dart';
import '../../core/app_radius.dart';
import '../../core/app_theme_controller.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/security_service.dart';
import '../login/pin_login_page.dart';
import '../login/security_setup_page.dart';
import 'about_page.dart';
import 'data_info_page.dart';
import 'support_page.dart';

/// "الإعدادات العامة" — إعدادات التطبيق العامة فقط (المرحلة الثانية من قسم
/// "القائمة الرئيسية والإعدادات العامة"). لا تحتوي أي إعداد خاص بقسم تشغيلي
/// داخل الفندق (تلك تبقى داخل قسمها كما هو معمول به فعلاً في المشروع).
///
/// بعض المفاتيح هنا (الوضع الداكن، حجم الخط، سرعة الحركة، الإشعارات) هي
/// تفضيلات تُخزَّن فعلياً عبر AppPreferences لكنها لا تُغيّر عرض التطبيق
/// بعد — لا يوجد نظام إشعارات حقيقي في التطبيق حالياً، ولا نسق داكن مبني في
/// AppTheme، وربط أثرها الفعلي عبر كامل التطبيق يقع خارج نطاق هذه المهمة
/// (تعديل أقسام أخرى). القيم تُحفَظ وتُقرأ بشكل حقيقي، وجاهزة ليقرأها أي
/// قسم آخر مستقبلاً دون إعادة تصميم هذه الصفحة.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _securityService = SecurityService.instance;
  bool _isLoading = true;

  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricLabel = "الدخول البيومتري";
  int _pinLength = 4;
  bool _hideBalances = false;
  bool _trialMode = false;

  bool _darkMode = false;
  double _fontScale = 1.0;
  String _animationSpeed = 'normal';

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _criticalNotifications = true;
  bool _silentNotifications = false;

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
    _darkMode = await AppPreferences.getBool(AppPreferences.keyDarkMode);
    _fontScale = await AppPreferences.getDouble(AppPreferences.keyFontScale, defaultValue: 1.0);
    _animationSpeed = await AppPreferences.getString(AppPreferences.keyAnimationSpeed, defaultValue: 'normal');
    _notificationsEnabled = await AppPreferences.getBool(AppPreferences.keyNotificationsEnabled, defaultValue: true);
    _soundEnabled = await AppPreferences.getBool(AppPreferences.keySoundEnabled, defaultValue: true);
    _vibrationEnabled = await AppPreferences.getBool(AppPreferences.keyVibrationEnabled, defaultValue: true);
    _criticalNotifications = await AppPreferences.getBool(AppPreferences.keyCriticalNotifications, defaultValue: true);
    _silentNotifications = await AppPreferences.getBool(AppPreferences.keySilentNotifications);

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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("الإعدادات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                _buildSectionTitle("المظهر"),
                _buildAppearanceSection(),
                const SizedBox(height: AppSizes.lg),
                _buildSectionTitle("الإشعارات"),
                _buildNotificationsSection(),
                const SizedBox(height: AppSizes.lg),
                _buildSectionTitle("البيانات"),
                _buildLinkCard(icon: Icons.storage_outlined, title: "معلومات البيانات المخزَّنة", subtitle: "حجم قاعدة البيانات وعدد السجلات (للعرض فقط)", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataInfoPage()))),
                const SizedBox(height: AppSizes.lg),
                _buildSectionTitle("حالة النظام"),
                _buildSystemStatusSection(),
                const SizedBox(height: AppSizes.lg),
                _buildSectionTitle("الدعم والمساعدة"),
                _buildLinkCard(icon: Icons.help_outline_rounded, title: "الدعم والمساعدة", subtitle: "الأسئلة الشائعة والإبلاغ عن مشكلة", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage()))),
                const SizedBox(height: AppSizes.lg),
                _buildSectionTitle("حول التطبيق"),
                _buildLinkCard(icon: Icons.info_outline_rounded, title: "حول التطبيق", subtitle: "${AppConfig.appName} — الإصدار ${AppConfig.version}", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()))),
                const SizedBox(height: AppSizes.xl),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm, right: AppSizes.xs),
      child: Text(title, style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Column(children: children),
    );
  }

  Widget _buildLinkCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return _buildCard([
      ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
        subtitle: Text(subtitle, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    ]);
  }

  // ---------------- الأمان ----------------

  Widget _buildSecuritySection() {
    final primary = Theme.of(context).colorScheme.primary;
    return _buildCard([
      ListTile(
        leading: Icon(Icons.lock_outline, color: primary),
        title: const Text("تغيير الرمز السري"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySetupPage())),
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
    ]);
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySetupPage()));
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
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SecuritySetupPage()), (route) => false);
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
            onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PinLoginPage()), (route) => false),
            child: const Text("تسجيل الخروج", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------- المظهر ----------------

  Widget _buildAppearanceSection() {
    final primary = Theme.of(context).colorScheme.primary;
    return _buildCard([
      SwitchListTile(
        secondary: Icon(Icons.dark_mode_outlined, color: primary),
        title: const Text("الوضع الداكن"),
        value: _darkMode,
        activeThumbColor: primary,
        onChanged: (value) async {
          await AppThemeController.setDarkMode(value);
          if (!mounted) return;
          setState(() => _darkMode = value);
        },
      ),
      const Divider(height: 1, indent: 50),
      ListTile(
        leading: Icon(Icons.language_outlined, color: primary),
        title: const Text("لغة التطبيق"),
        trailing: const Text("العربية", style: AppTextStyles.caption),
      ),
      const Divider(height: 1, indent: 50),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
        child: Row(
          children: [
            Icon(Icons.format_size_outlined, color: primary),
            const SizedBox(width: AppSizes.md),
            const Expanded(child: Text("حجم الخط")),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0.9, label: Text("صغير", style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 1.0, label: Text("متوسط", style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 1.15, label: Text("كبير", style: TextStyle(fontSize: 11))),
              ],
              selected: {_fontScale},
              showSelectedIcon: false,
              onSelectionChanged: (v) async {
                await AppThemeController.setFontScale(v.first);
                if (!mounted) return;
                setState(() => _fontScale = v.first);
              },
            ),
          ],
        ),
      ),
      const Divider(height: 1, indent: 50),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
        child: Row(
          children: [
            Icon(Icons.speed_outlined, color: primary),
            const SizedBox(width: AppSizes.md),
            const Expanded(child: Text("سرعة الحركة والانتقالات")),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'slow', label: Text("بطيء", style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'normal', label: Text("عادي", style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'fast', label: Text("سريع", style: TextStyle(fontSize: 11))),
              ],
              selected: {_animationSpeed},
              showSelectedIcon: false,
              onSelectionChanged: (v) async {
                await AppThemeController.setAnimationSpeed(v.first);
                if (!mounted) return;
                setState(() => _animationSpeed = v.first);
              },
            ),
          ],
        ),
      ),
    ]);
  }

  // ---------------- الإشعارات ----------------

  Widget _buildNotificationsSection() {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppSizes.sm),
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.info),
              SizedBox(width: 8),
              Expanded(child: Text("لا يرسل التطبيق إشعارات فعلية بعد — هذه التفضيلات محفوظة وجاهزة لتفعيل نظام الإشعارات مستقبلاً.", style: TextStyle(fontSize: 11, color: AppColors.info))),
            ],
          ),
        ),
        _buildCard([
          SwitchListTile(
            secondary: Icon(Icons.notifications_outlined, color: primary),
            title: const Text("تشغيل الإشعارات"),
            value: _notificationsEnabled,
            activeThumbColor: primary,
            onChanged: (v) async {
              await AppPreferences.setBool(AppPreferences.keyNotificationsEnabled, v);
              if (!mounted) return;
              setState(() => _notificationsEnabled = v);
            },
          ),
          const Divider(height: 1, indent: 50),
          SwitchListTile(
            secondary: Icon(Icons.volume_up_outlined, color: primary),
            title: const Text("الصوت"),
            value: _soundEnabled,
            activeThumbColor: primary,
            onChanged: !_notificationsEnabled
                ? null
                : (v) async {
                    await AppPreferences.setBool(AppPreferences.keySoundEnabled, v);
                    if (!mounted) return;
                    setState(() => _soundEnabled = v);
                  },
          ),
          const Divider(height: 1, indent: 50),
          SwitchListTile(
            secondary: Icon(Icons.vibration_outlined, color: primary),
            title: const Text("الاهتزاز"),
            value: _vibrationEnabled,
            activeThumbColor: primary,
            onChanged: !_notificationsEnabled
                ? null
                : (v) async {
                    await AppPreferences.setBool(AppPreferences.keyVibrationEnabled, v);
                    if (!mounted) return;
                    setState(() => _vibrationEnabled = v);
                  },
          ),
          const Divider(height: 1, indent: 50),
          SwitchListTile(
            secondary: const Icon(Icons.priority_high_rounded, color: AppColors.danger),
            title: const Text("الإشعارات الحرجة"),
            value: _criticalNotifications,
            activeThumbColor: primary,
            onChanged: !_notificationsEnabled
                ? null
                : (v) async {
                    await AppPreferences.setBool(AppPreferences.keyCriticalNotifications, v);
                    if (!mounted) return;
                    setState(() => _criticalNotifications = v);
                  },
          ),
          const Divider(height: 1, indent: 50),
          SwitchListTile(
            secondary: Icon(Icons.notifications_off_outlined, color: primary),
            title: const Text("الإشعارات الصامتة"),
            value: _silentNotifications,
            activeThumbColor: primary,
            onChanged: !_notificationsEnabled
                ? null
                : (v) async {
                    await AppPreferences.setBool(AppPreferences.keySilentNotifications, v);
                    if (!mounted) return;
                    setState(() => _silentNotifications = v);
                  },
          ),
        ]),
      ],
    );
  }

  // ---------------- حالة النظام ----------------

  Widget _buildSystemStatusSection() {
    return _buildCard([
      _statusRow(Icons.apartment, "إصدار التطبيق", AppConfig.version),
      const Divider(height: 1, indent: 50),
      _statusRow(Icons.storage_outlined, "إصدار قاعدة البيانات", "24"),
      const Divider(height: 1, indent: 50),
      _statusRow(Icons.sync_outlined, "آخر مزامنة", "غير مفعَّلة حالياً"),
      const Divider(height: 1, indent: 50),
      _statusRow(Icons.cloud_upload_outlined, "آخر نسخة احتياطية", "لم تُجرَ أي نسخة بعد"),
      const Divider(height: 1, indent: 50),
      _statusRow(Icons.check_circle_outline, "حالة النظام", "متصل ويعمل", valueColor: AppColors.success),
    ]);
  }

  Widget _statusRow(IconData icon, String label, String value, {Color? valueColor}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
      trailing: Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: valueColor)),
    );
  }
}
