import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_page_route.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/training_mode_controller.dart';
import '../../services/training_mode_service.dart';
import '../dashboard/pages/hotels_page.dart';

/// وضع التدريب — منقولة من SettingsPage القديمة حرفياً.
class TrainingModeSettingsPage extends StatefulWidget {
  const TrainingModeSettingsPage({super.key});

  @override
  State<TrainingModeSettingsPage> createState() => _TrainingModeSettingsPageState();
}

class _TrainingModeSettingsPageState extends State<TrainingModeSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("🎓 وضع التدريب", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: TrainingModeController.isActive,
            builder: (context, isActive, _) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
                child: Column(children: [
                  if (!isActive)
                    ListTile(
                      leading: Icon(Icons.play_circle_outline, color: primary),
                      title: const Text("▶️ بدء التدريب"),
                      subtitle: const Text(
                        "ينشئ نسخة كاملة منفصلة من البيانات لتدريب المدير/الموظفين دون أي تأثير على البيانات الحقيقية",
                        style: TextStyle(fontSize: 11),
                      ),
                      onTap: _showStartTrainingDialog,
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.stop_circle_outlined, color: AppColors.danger),
                      title: const Text("⏹️ إنهاء التدريب والعودة للبيانات الأصلية", style: TextStyle(color: AppColors.danger)),
                      subtitle: const Text(
                        "يحذف كل بيانات التدريب نهائياً ويعيد فتح البيانات الحقيقية كما كانت تماماً",
                        style: TextStyle(fontSize: 11),
                      ),
                      onTap: _showEndTrainingDialog,
                    ),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showStartTrainingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("بدء وضع التدريب"),
        content: const Text(
          "سيتم إنشاء نسخة كاملة من كل بيانات التطبيق (الفنادق، التقارير اليومية، المصروفات، المستندات، الموظفون، الموردون، العقود، وكل شيء آخر). "
          "كل عملية تقوم بها بعد ذلك (إضافة/تعديل/حذف) ستطبَّق على هذه النسخة فقط ولن تؤثر على بياناتك الحقيقية إطلاقاً.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _runTrainingAction(TrainingModeService.startTraining);
            },
            child: Text("بدء التدريب", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEndTrainingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("إنهاء وضع التدريب"),
        content: const Text("سيتم حذف كل بيانات التدريب نهائياً والعودة إلى بياناتك الحقيقية كما كانت قبل بدء التدريب. هل أنت متأكد؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _runTrainingAction(TrainingModeService.endTraining);
            },
            child: const Text("إنهاء التدريب", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// ينفّذ بدء/إنهاء التدريب مع مؤشر تحميل، ثم يهدم شجرة التنقّل بالكامل
  /// ويعيد بناءها من قائمة الفنادق حتى تُحمَّل كل شاشة بياناتها من الاتصال
  /// الصحيح (الحقيقي أو التدريبي) بدل الاستمرار بعرض بيانات الاتصال السابق.
  Future<void> _runTrainingAction(Future<void> Function() action) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text("جارٍ التنفيذ...")),
          ],
        ),
      ),
    );
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        premiumRoute(const HotelsPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    }
  }
}
