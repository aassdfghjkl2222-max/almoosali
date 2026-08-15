import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_preferences.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/sync_service.dart';

/// حالة النظام — منقولة من SettingsPage القديمة، مع تصحيح رقم إصدار قاعدة
/// البيانات ("44" كان قديماً/غير صحيح) وحالة المزامنة (كانت نصاً ثابتاً
/// "غير مفعَّلة" رغم أن مزامنة الفنادق فعلية الآن — راجع HotelSyncService).
class SystemStatusPage extends StatefulWidget {
  const SystemStatusPage({super.key});

  @override
  State<SystemStatusPage> createState() => _SystemStatusPageState();
}

class _SystemStatusPageState extends State<SystemStatusPage> {
  bool _isLoading = true;
  String _syncLabel = 'لم تتم أي مزامنة بعد';
  String _backupLabel = 'لم تُجرَ أي نسخة بعد';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _syncLabel = await SyncService.getLastSyncLabel();
    final lastBackupStr = await AppPreferences.getString(AppPreferences.keyLastBackupAt);
    final lastBackupAt = lastBackupStr.isEmpty ? null : DateTime.tryParse(lastBackupStr);
    _backupLabel = lastBackupAt == null ? 'لم تُجرَ أي نسخة بعد' : DateFormat('yyyy/MM/dd — HH:mm', 'ar').format(lastBackupAt);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("حالة النظام", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
                  child: Column(children: [
                    _statusRow(Icons.apartment, "إصدار التطبيق", AppConfig.version),
                    const Divider(height: 1, indent: 50),
                    _statusRow(Icons.storage_outlined, "إصدار قاعدة البيانات", "52"),
                    const Divider(height: 1, indent: 50),
                    _statusRow(Icons.sync_outlined, "آخر مزامنة (الفنادق)", _syncLabel),
                    const Divider(height: 1, indent: 50),
                    _statusRow(Icons.cloud_upload_outlined, "آخر نسخة احتياطية", _backupLabel),
                    const Divider(height: 1, indent: 50),
                    _statusRow(Icons.check_circle_outline, "حالة النظام", "متصل ويعمل", valueColor: AppColors.success),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value, {Color? valueColor}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
      trailing: Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: valueColor)),
    );
  }
}
