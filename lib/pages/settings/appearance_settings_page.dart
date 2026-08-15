import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_theme_controller.dart';
import '../../core/app_preferences.dart';

/// المظهر: الوضع الداكن، اللغة (عرض فقط)، حجم الخط، سرعة الحركة — منقولة من
/// SettingsPage القديمة حرفياً. غير مذكورة صراحة في تصنيف الإعدادات
/// المطلوب، فأُبقيت كفئة إضافية مستقلة بدل حذف وظيفة قائمة.
class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  bool _isLoading = true;
  bool _darkMode = false;
  double _fontScale = 1.0;
  String _animationSpeed = 'normal';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _darkMode = await AppPreferences.getBool(AppPreferences.keyDarkMode);
    _fontScale = await AppPreferences.getDouble(AppPreferences.keyFontScale, defaultValue: 1.0);
    _animationSpeed = await AppPreferences.getString(AppPreferences.keyAnimationSpeed, defaultValue: 'normal');
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("المظهر", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                  ]),
                ),
              ],
            ),
    );
  }
}
