import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';

class AppDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: _brandedTitle(dialogContext, title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("حسناً"),
            ),
          ],
        );
      },
    );
  }

  /// شريط علوي رفيع بلون هوية الفندق الحالي أعلى عنوان أي نافذة منبثقة —
  /// طبقة هوية بصرية فوق التصميم دون المساس بالألوان الوظيفية للمحتوى.
  static Widget _brandedTitle(BuildContext context, String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// نافذة تأكيد إلزامية (إلغاء / تأكيد) قبل تنفيذ أي عملية تؤثر على
  /// البيانات (حفظ، تعديل، حذف، ترحيل، اعتماد، إغلاق، إنشاء، إضافة، نقل،
  /// تسوية، استيراد، تصدير). لا تُنفَّذ [onConfirm] إلا بعد ضغط "تأكيد"؛
  /// عند "إلغاء" أو إغلاق النافذة لا يحدث أي شيء.
  static Future<void> confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
    String confirmLabel = "تأكيد",
    String cancelLabel = "إلغاء",
    bool isDangerous = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: _brandedTitle(dialogContext, title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("إلغاء", style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDangerous ? AppColors.danger : Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onConfirm();
    }
  }
}