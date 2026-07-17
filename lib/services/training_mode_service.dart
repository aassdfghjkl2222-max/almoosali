import 'dart:io';

import 'package:path/path.dart';

import '../core/app_preferences.dart';
import '../core/database/database_service.dart';
import '../core/training_mode_controller.dart';

/// خدمة وضع التدريب — تبديل ملف قاعدة البيانات بأكمله إلى نسخة منفصلة
/// (manazel_training.db) بحيث تُغطّى كل جداول النظام تلقائياً (فنادق، تقارير
/// يومية، مصروفات، مستندات، موظفون، موردون، عقود...) بلا أي كود خاص بكل جدول.
///
/// لا علاقة لهذا بـ AppPreferences.keyTrialMode (وضع التجربة، يُخفّف قواعد
/// تحقق داخل نفس القاعدة الحقيقية) — الاثنان مستقلان تماماً.
///
/// حد نطاق مُفصَح عنه: النسخ يشمل ملف قاعدة البيانات فقط، وليس ملفات
/// المرفقات (صور/PDF المستندات) المخزَّنة على القرص بشكل منفصل — أي مرفق
/// يُرفَع أثناء التدريب يبقى ملفاً يتيماً بعد الإنهاء (لا يؤثر على أي بيانات
/// حقيقية، فقط مساحة تخزين ضئيلة).
class TrainingModeService {
  TrainingModeService._();

  static Future<void> startTraining() async {
    if (TrainingModeController.isActive.value) return;

    final realPath = await DatabaseService().getDatabaseFilePath();
    await DatabaseService().closeForRestore();

    final trainingPath = join(dirname(realPath), 'manazel_training.db');
    final trainingFile = File(trainingPath);
    if (await trainingFile.exists()) {
      await trainingFile.delete();
    }
    await File(realPath).copy(trainingPath);

    await AppPreferences.setBool(AppPreferences.keyTrainingModeActive, true);
    TrainingModeController.isActive.value = true;
  }

  static Future<void> endTraining() async {
    if (!TrainingModeController.isActive.value) return;

    await DatabaseService().closeForRestore();
    // العلم لا يزال true هنا، فـ getDatabaseFilePath() يعيد مسار الملف
    // التدريبي نفسه فعلياً — يُستخدم مباشرة كمسار الحذف.
    final trainingPath = await DatabaseService().getDatabaseFilePath();
    final trainingFile = File(trainingPath);
    if (await trainingFile.exists()) {
      await trainingFile.delete();
    }

    await AppPreferences.setBool(AppPreferences.keyTrainingModeActive, false);
    TrainingModeController.isActive.value = false;
  }
}
