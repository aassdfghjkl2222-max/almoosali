import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_preferences.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/backup_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/common/app_text_field.dart';
import 'backup_list_page.dart';
import 'backup_log_page.dart';
import 'sync_log_page.dart';

/// النسخ الاحتياطي والمزامنة — قسم مستقل لحماية البيانات.
///
/// النسخ الاحتياطي حقيقي بالكامل: ينسخ فعلياً ملف قاعدة البيانات المحلي
/// (manazel.db) عبر [BackupService]. المزامنة السحابية بالمقابل هيكلية/
/// واجهة فقط في هذه المرحلة (بلا اتصال شبكي فعلي) بتصريح صريح من المهمة
/// المطلوبة، مبنية بحيث تكون جاهزة للربط بخدمة سحابية حقيقية مستقبلاً دون
/// إعادة تصميم — راجع [SyncService].
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isLoading = true;
  bool _isWorking = false;

  DateTime? _lastBackupAt;
  int _backupsCount = 0;
  bool _autoBackupEnabled = false;
  String _autoBackupFrequency = 'weekly';
  String _lastSyncLabel = 'لم تتم أي مزامنة بعد';
  int _pendingSyncCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ranAuto = await BackupService.maybeRunScheduledBackup();
    await _loadState();
    if (ranAuto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إنشاء نسخة احتياطية تلقائية حسب الجدولة المحدَّدة")),
      );
    }
  }

  Future<void> _loadState() async {
    final lastStr = await AppPreferences.getString(AppPreferences.keyLastBackupAt);
    final backups = await BackupService.listBackups();
    final autoEnabled = await AppPreferences.getBool(AppPreferences.keyAutoBackupEnabled);
    final frequency = await AppPreferences.getString(AppPreferences.keyAutoBackupFrequency, defaultValue: 'weekly');
    final syncLabel = await SyncService.getLastSyncLabel();
    final pendingCount = await SyncService.getPendingCount();

    if (!mounted) return;
    setState(() {
      _lastBackupAt = lastStr.isEmpty ? null : DateTime.tryParse(lastStr);
      _backupsCount = backups.length;
      _autoBackupEnabled = autoEnabled;
      _autoBackupFrequency = frequency;
      _lastSyncLabel = syncLabel;
      _pendingSyncCount = pendingCount;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "لم تُجرَ أي نسخة بعد";
    return DateFormat('yyyy/MM/dd — HH:mm', 'ar').format(date);
  }

  Future<void> _createBackupNow() async {
    setState(() => _isWorking = true);
    try {
      await BackupService.createBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إنشاء نسخة احتياطية جديدة بنجاح"), backgroundColor: AppColors.success),
      );
      await _loadState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تعذّر إنشاء النسخة الاحتياطية: $e"), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _pickAndRestore() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("استعادة نسخة احتياطية"),
        content: const Text(
          "سيتم استبدال جميع البيانات الحالية ببيانات الملف المحدَّد. سيُنشأ تلقائياً نسخة أمان من الحالة الحالية قبل الاستبدال. يُنصح بإغلاق التطبيق وإعادة فتحه بعد الانتهاء.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _runRestore(path);
            },
            child: const Text("استعادة", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _runRestore(String path) async {
    setState(() => _isWorking = true);
    final error = await BackupService.restoreBackup(path);
    if (!mounted) return;
    setState(() => _isWorking = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
      return;
    }
    await _loadState();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تمت الاستعادة بنجاح"),
        content: const Text("يرجى إغلاق التطبيق بالكامل وإعادة فتحه الآن حتى تظهر البيانات المستعادة بشكل صحيح."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))],
      ),
    );
  }

  Future<void> _toggleAutoBackup(bool value) async {
    await AppPreferences.setBool(AppPreferences.keyAutoBackupEnabled, value);
    setState(() => _autoBackupEnabled = value);
  }

  Future<void> _setFrequency(String freq) async {
    await AppPreferences.setString(AppPreferences.keyAutoBackupFrequency, freq);
    setState(() => _autoBackupFrequency = freq);
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;

    if (!await SupabaseAuthService.instance.hasStoredCredentials()) {
      final signedIn = await _showSignInDialog();
      if (!signedIn || !mounted) return;
    }

    setState(() => _isSyncing = true);
    final message = await SyncService.syncNow();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await _loadState();
  }

  /// حوار تسجيل الدخول للخدمة السحابية — يظهر مرة واحدة فقط (أول محاولة
  /// مزامنة)، منفصل تماماً عن رمز PIN المحلي. راجع SupabaseAuthService.
  Future<bool> _showSignInDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text("تسجيل الدخول للمزامنة السحابية", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "أدخل بيانات حساب الخدمة السحابية (Supabase) المُنشَأ مسبقاً لهذا الفندق — تُحفَظ هذه البيانات بأمان على هذا الجهاز فقط ولن تُطلَب مجدداً.",
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSizes.md),
                AppTextField(controller: emailController, hint: "البريد الإلكتروني", icon: Icons.email_outlined),
                const SizedBox(height: AppSizes.sm),
                AppTextField(
                  controller: passwordController,
                  hint: "كلمة المرور",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  errorText: errorText,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text("إلغاء")),
              TextButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  final password = passwordController.text;
                  if (email.isEmpty || password.isEmpty) {
                    setDialogState(() => errorText = "يرجى تعبئة الحقلين");
                    return;
                  }
                  final error = await SupabaseAuthService.instance.saveCredentialsAndSignIn(
                    email: email,
                    password: password,
                  );
                  if (error != null) {
                    setDialogState(() => errorText = error);
                    return;
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                },
                child: const Text("دخول", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("النسخ الاحتياطي والمزامنة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _sectionTitle("النسخ الاحتياطي"),
                _functionCard(
                  icon: Icons.backup_outlined,
                  title: "إنشاء نسخة احتياطية",
                  description: "حفظ نسخة كاملة من بيانات التطبيق الحالية على الجهاز",
                  status: "آخر تنفيذ: ${_formatDate(_lastBackupAt)}",
                  statusColor: _lastBackupAt == null ? Theme.of(context).colorScheme.onSurfaceVariant : AppColors.success,
                  action: FilledButton.icon(
                    onPressed: _isWorking ? null : _createBackupNow,
                    icon: _isWorking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text("إنشاء الآن"),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                _functionCard(
                  icon: Icons.restore_outlined,
                  title: "استعادة نسخة احتياطية",
                  description: "استرجاع البيانات من ملف نسخة احتياطية موجود",
                  status: "$_backupsCount نسخة محفوظة محلياً",
                  statusColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  action: OutlinedButton.icon(
                    onPressed: _isWorking ? null : _pickAndRestore,
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: const Text("اختيار ملف"),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                _functionCard(
                  icon: Icons.schedule_outlined,
                  title: "النسخ الاحتياطي التلقائي والجدولة",
                  description: "إنشاء نسخة احتياطية تلقائياً حسب التكرار المحدَّد عند فتح هذه الصفحة",
                  status: _autoBackupEnabled ? "مفعَّل — $_frequencyLabel" : "غير مفعَّل",
                  statusColor: _autoBackupEnabled ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant,
                  action: Switch(
                    value: _autoBackupEnabled,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: _toggleAutoBackup,
                  ),
                  extra: _autoBackupEnabled
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSizes.sm),
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'daily', label: Text("يومي", style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'weekly', label: Text("أسبوعي", style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'monthly', label: Text("شهري", style: TextStyle(fontSize: 11))),
                            ],
                            selected: {_autoBackupFrequency},
                            showSelectedIcon: false,
                            onSelectionChanged: (v) => _setFrequency(v.first),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: AppSizes.sm),
                _functionCard(
                  icon: Icons.folder_copy_outlined,
                  title: "إدارة النسخ الاحتياطية",
                  description: "عرض جميع النسخ المحفوظة محلياً، واستعادة أو حذف أي منها",
                  status: "$_backupsCount نسخة",
                  statusColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  action: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupListPage()));
                      _loadState();
                    },
                    icon: const Icon(Icons.list_alt_outlined, size: 18),
                    label: const Text("إدارة"),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                _functionCard(
                  icon: Icons.receipt_long_outlined,
                  title: "سجل عمليات النسخ الاحتياطي",
                  description: "سجل تفصيلي بجميع عمليات النسخ والاستعادة السابقة",
                  status: "عرض السجل الكامل",
                  statusColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  action: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupLogPage())),
                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                    label: const Text("عرض"),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                _sectionTitle("المزامنة"),
                Container(
                  margin: const EdgeInsets.only(bottom: AppSizes.sm),
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "المزامنة السحابية مفعَّلة حالياً لبيانات الفنادق فقط (مرحلة تجريبية أولى) — بقية البيانات (موظفون، فواتير، تقارير...) ستُضاف لاحقاً بنفس الآلية.",
                          style: TextStyle(fontSize: 11, color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
                _functionCard(
                  icon: Icons.sync_outlined,
                  title: "مزامنة الآن",
                  description: "بدء عملية مزامنة يدوية مع الخدمة السحابية",
                  status: _isSyncing ? "جارِ المزامنة..." : "$_pendingSyncCount فندق بانتظار الرفع",
                  statusColor: _isSyncing
                      ? AppColors.info
                      : (_pendingSyncCount > 0 ? AppColors.warning : Theme.of(context).colorScheme.onSurfaceVariant),
                  action: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _syncNow,
                    icon: _isSyncing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync, size: 18),
                    label: const Text("مزامنة"),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                _functionCard(
                  icon: Icons.cloud_queue_outlined,
                  title: "حالة المزامنة",
                  description: "آخر مزامنة ناجحة مع الخدمة السحابية",
                  status: _lastSyncLabel,
                  statusColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSizes.sm),
                _functionCard(
                  icon: Icons.devices_other_outlined,
                  title: "الأجهزة المرتبطة",
                  description: "الأجهزة المرتبطة بحساب المزامنة السحابي",
                  status: "لا توجد أجهزة مرتبطة",
                  statusColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSizes.sm),
                _functionCard(
                  icon: Icons.receipt_long_outlined,
                  title: "سجل عمليات المزامنة",
                  description: "سجل تفصيلي بعمليات المزامنة السابقة",
                  status: "عرض السجل الكامل",
                  statusColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  action: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncLogPage())),
                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                    label: const Text("عرض"),
                  ),
                ),
                const SizedBox(height: AppSizes.xl),
              ],
            ),
    );
  }

  String get _frequencyLabel {
    switch (_autoBackupFrequency) {
      case 'daily':
        return "يومي";
      case 'monthly':
        return "شهري";
      default:
        return "أسبوعي";
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm, right: AppSizes.xs),
      child: Text(title, style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _functionCard({
    required IconData icon,
    required String title,
    required String description,
    required String status,
    required Color statusColor,
    Widget? action,
    Widget? extra,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(AppSizes.sm)),
                  child: Icon(icon, color: primary),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyBold),
                      const SizedBox(height: 2),
                      Text(description, style: AppTextStyles.caption),
                      const SizedBox(height: 6),
                      Text(status, style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: AppSizes.sm), action],
              ],
            ),
            if (extra != null) extra,
          ],
        ),
      ),
    );
  }
}
