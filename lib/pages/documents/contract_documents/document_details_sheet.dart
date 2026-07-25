import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_page_route.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/contract_document_options.dart';
import '../../../models/contract_document.dart';
import '../../../repositories/contract_document_repository.dart';
import '../../../services/attachment_service.dart';
import '../../../widgets/common/app_text_field.dart';
import 'create_edit_document_page.dart';

/// نافذة سفلية بتفاصيل مستند وإجراءاته — فتح/معاينة (عبر open_filex)، تعديل،
/// استبدال المرفق، أرشفة (حذف). سجل الإصدارات (Version History) لاستبدال
/// المرفق مُعَدّ للمستقبل فقط ولم يُنفَّذ بعد (يُستبدَل الملف القديم مباشرة).
class DocumentDetailsSheet extends StatefulWidget {
  final ContractDocument document;
  const DocumentDetailsSheet({super.key, required this.document});

  @override
  State<DocumentDetailsSheet> createState() => _DocumentDetailsSheetState();
}

class _DocumentDetailsSheetState extends State<DocumentDetailsSheet> {
  final _repo = ContractDocumentRepository();
  bool _busy = false;

  Future<void> _edit() async {
    Navigator.pop(context);
    final result = await Navigator.push(context, premiumRoute(CreateEditDocumentPage(folderId: widget.document.folderId, document: widget.document)));
    if (result == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _replaceAttachment() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSizes.sm),
            ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text("الكاميرا"), onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text("معرض الصور"), onTap: () => Navigator.pop(ctx, 'gallery')),
            ListTile(leading: const Icon(Icons.folder_open_outlined), title: const Text("مدير الملفات"), onTap: () => Navigator.pop(ctx, 'files')),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => _busy = true);
    ({String path, String name})? picked;
    if (source == 'camera') picked = await AttachmentService.captureImage(folder: 'contract_documents');
    if (source == 'gallery') {
      final images = await AttachmentService.pickImages(folder: 'contract_documents');
      picked = images.isEmpty ? null : images.first;
    }
    if (source == 'files') picked = await AttachmentService.pickAnyDocument(folder: 'contract_documents');
    if (picked == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    await _repo.replaceAttachment(widget.document, newPath: picked.path, newFileName: picked.name, newFileType: ContractFileTypes.fromExtension(picked.name), performedBy: "مدير النظام");
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _archive() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text("أرشفة \"${widget.document.name}\"", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("سينتقل المستند إلى الأرشيف، ويمكن استعادته لاحقاً في أي وقت.", style: AppTextStyles.caption),
            const SizedBox(height: AppSizes.sm),
            AppTextField(controller: controller, hint: "سبب الأرشفة (اختياري)", icon: Icons.notes_outlined),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text("أرشفة", style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _repo.archiveDocument(widget.document.id!, performedBy: "مدير النظام", reason: reason.isEmpty ? null : reason);
    if (mounted) Navigator.pop(context, true);
  }

  String _formatDate(String? iso) {
    if (iso == null) return "—";
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final color = ContractFileTypes.colorFor(doc.fileType);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Icon(ContractFileTypes.iconFor(doc.fileType), color: color, size: 24),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.name, style: AppTextStyles.title.copyWith(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(doc.fileName, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              if (doc.description != null && doc.description!.trim().isNotEmpty) _infoRow("الوصف", doc.description!),
              if (doc.category != null && doc.category!.trim().isNotEmpty) _infoRow("الفئة", doc.category!),
              if (doc.tags.isNotEmpty) _infoRow("الوسوم", doc.tags.join('، ')),
              if (doc.expiryDate != null) _infoRow("تاريخ الانتهاء", _formatDate(doc.expiryDate)),
              if (doc.reminderDate != null) _infoRow("تذكير", _formatDate(doc.reminderDate)),
              if (doc.notes != null && doc.notes!.trim().isNotEmpty) _infoRow("ملاحظات", doc.notes!),
              _infoRow("أُضيف بواسطة", "${doc.createdBy ?? '—'} — ${_formatDate(doc.createdAt)}"),
              const SizedBox(height: AppSizes.md),
              _actionTile(Icons.open_in_new_rounded, "فتح / معاينة", () => OpenFilex.open(doc.filePath)),
              _actionTile(Icons.edit_outlined, "تعديل البيانات", _edit),
              _actionTile(Icons.attach_file_rounded, "استبدال المرفق", _busy ? null : _replaceAttachment),
              _actionTile(Icons.archive_outlined, "أرشفة (حذف)", _archive, color: AppColors.warning),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12))),
          Expanded(child: Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback? onTap, {Color? color}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
