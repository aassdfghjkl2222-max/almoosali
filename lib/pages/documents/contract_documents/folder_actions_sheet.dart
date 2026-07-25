import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/contract_folder.dart';
import '../../../repositories/contract_document_repository.dart';
import '../../../widgets/common/app_text_field.dart';
import 'create_edit_folder_sheet.dart';

/// قائمة إجراءات مجلد (تُفتَح بالضغط الطويل على بطاقة مجلد). "حذف" هنا يعني
/// أرشفة دائماً وليس حذفاً نهائياً — الحذف النهائي متاح فقط من شاشة الأرشيف
/// بعد التأكيد المتعدد المراحل. نقل/نسخ المجلد مؤجَّلان (راجع تعليق أسفل الصفحة).
class FolderActionsSheet extends StatelessWidget {
  final ContractFolder folder;
  const FolderActionsSheet({super.key, required this.folder});

  Future<void> _edit(BuildContext context) async {
    Navigator.pop(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateEditFolderSheet(parentId: folder.parentId, folder: folder),
    );
    if (result == true && context.mounted) Navigator.pop(context, true);
  }

  Future<void> _showDetails(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (folder.description != null && folder.description!.trim().isNotEmpty) ...[
              Text(folder.description!),
              const SizedBox(height: AppSizes.sm),
            ],
            Text("أُنشئ بواسطة: ${folder.createdBy ?? '—'}", style: AppTextStyles.caption),
            Text("تاريخ الإنشاء: ${folder.createdAt.split('T').first}", style: AppTextStyles.caption),
            if (folder.updatedAt != null) Text("آخر تعديل: ${folder.updatedAt!.split('T').first}", style: AppTextStyles.caption),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إغلاق"))],
      ),
    );
  }

  Future<void> _archive(BuildContext context) async {
    Navigator.pop(context);
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text("أرشفة \"${folder.name}\"", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("سينتقل المجلد بكل محتوياته إلى الأرشيف، ويمكن استعادته لاحقاً في أي وقت.", style: AppTextStyles.caption),
              const SizedBox(height: AppSizes.sm),
              AppTextField(controller: controller, hint: "سبب الأرشفة (اختياري)", icon: Icons.notes_outlined),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text("أرشفة", style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    await ContractDocumentRepository().archiveFolder(folder.id!, performedBy: "مدير النظام", reason: reason.isEmpty ? null : reason);
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSizes.sm), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: AppSizes.md), child: Align(alignment: Alignment.centerRight, child: Text(folder.name, style: AppTextStyles.bodyBold))),
            const Divider(height: AppSizes.md),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text("تعديل (الاسم/الوصف/الأيقونة/اللون)"), onTap: () => _edit(context)),
            ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text("التفاصيل"), onTap: () => _showDetails(context)),
            ListTile(leading: const Icon(Icons.archive_outlined, color: AppColors.warning), title: const Text("أرشفة (حذف)", style: TextStyle(color: AppColors.warning)), onTap: () => _archive(context)),
          ],
        ),
      ),
    );
  }
}
