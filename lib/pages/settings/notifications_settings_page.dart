import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_preferences.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../repositories/document_repository.dart';
import '../../services/document_notification_service.dart';

/// الإشعارات — منقولة من SettingsPage القديمة حرفياً.
class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _isLoading = true;
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
    _notificationsEnabled = await AppPreferences.getBool(AppPreferences.keyNotificationsEnabled, defaultValue: true);
    _soundEnabled = await AppPreferences.getBool(AppPreferences.keySoundEnabled, defaultValue: true);
    _vibrationEnabled = await AppPreferences.getBool(AppPreferences.keyVibrationEnabled, defaultValue: true);
    _criticalNotifications = await AppPreferences.getBool(AppPreferences.keyCriticalNotifications, defaultValue: true);
    _silentNotifications = await AppPreferences.getBool(AppPreferences.keySilentNotifications);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("الإشعارات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: AppSizes.sm),
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(child: Text("عند التفعيل، يُرسِل التطبيق تذكيرات محلية بانتهاء المستندات (قبل 30 و10 و5 أيام ويوم الانتهاء).", style: TextStyle(fontSize: 11, color: AppColors.info))),
                    ],
                  ),
                ),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
                  child: Column(children: [
                    SwitchListTile(
                      secondary: Icon(Icons.notifications_outlined, color: primary),
                      title: const Text("تشغيل الإشعارات"),
                      value: _notificationsEnabled,
                      activeThumbColor: primary,
                      onChanged: (v) async {
                        await AppPreferences.setBool(AppPreferences.keyNotificationsEnabled, v);
                        if (!mounted) return;
                        setState(() => _notificationsEnabled = v);
                        if (v) await DocumentNotificationService.requestPermissionIfNeeded();
                        final documents = await DocumentRepository().getAllDocuments();
                        await DocumentNotificationService.rescheduleAll(documents);
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
                ),
              ],
            ),
    );
  }
}
