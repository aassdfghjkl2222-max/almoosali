import 'package:flutter/material.dart';

import 'app_dialog.dart';

/// حوارات التأكيد الموحّدة الثلاثة لسلة المهملات — نفس النصوص حرفياً في كل
/// مكان بالتطبيق (راجع متطلبات ميزة "سلة المهملات"). تُبنى فوق AppDialog.confirmAction
/// الموجود فعلاً بدل حوار جديد، فتستفيد تلقائياً من عرض أي StateError (مثل
/// حارس "مصروف مُرحَّل لا يمكن حذفه") كرسالة خطأ حمراء بدل تنفيذ صامت.
class TrashConfirmDialogs {
  TrashConfirmDialogs._();

  /// نقل عنصر إلى سلة المهملات (حذف ناعم) — يُستدعى بدل أي AlertDialog حذف قديم.
  static Future<void> confirmMoveToTrash(BuildContext context, Future<void> Function() onConfirm) {
    return AppDialog.confirmAction(
      context: context,
      title: "تأكيد الحذف",
      message: "هل أنت متأكد من نقل هذا العنصر إلى سلة المهملات؟",
      confirmLabel: "نعم",
      cancelLabel: "لا",
      onConfirm: onConfirm,
    );
  }

  static Future<void> confirmRestore(BuildContext context, Future<void> Function() onConfirm) {
    return AppDialog.confirmAction(
      context: context,
      title: "استعادة العنصر",
      message: "هل أنت متأكد من استعادة هذا العنصر؟",
      confirmLabel: "نعم",
      cancelLabel: "لا",
      onConfirm: onConfirm,
    );
  }

  static Future<void> confirmPermanentDelete(BuildContext context, Future<void> Function() onConfirm) {
    return AppDialog.confirmAction(
      context: context,
      title: "حذف نهائي",
      message: "هل أنت متأكد من حذف هذا العنصر نهائياً؟ لا يمكن التراجع عن هذا الإجراء.",
      confirmLabel: "نعم",
      cancelLabel: "لا",
      isDangerous: true,
      onConfirm: onConfirm,
    );
  }
}
