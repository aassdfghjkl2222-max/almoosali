import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/contract_document_options.dart';
import '../../../models/contract_document.dart';
import '../../../models/contract_folder.dart';
import '../../../repositories/contract_document_repository.dart';
import '../../../services/security_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
import 'widgets/contract_empty_state.dart';

/// أرشيف مستندات العقود: مجلدات ومستندات مؤرشَفة معاً. "استعادة" فورية،
/// و"حذف نهائي" محمي بأربع مراحل تأكيد متتالية (نفس نمط RecycleBinPage
/// تماماً للفنادق) — تحذير صريح ← كتابة الاسم ← سبب الحذف ← رمز PIN.
class ContractDocumentsArchivePage extends StatefulWidget {
  const ContractDocumentsArchivePage({super.key});

  @override
  State<ContractDocumentsArchivePage> createState() => _ContractDocumentsArchivePageState();
}

class _ContractDocumentsArchivePageState extends State<ContractDocumentsArchivePage> {
  final _repo = ContractDocumentRepository();
  List<ContractFolder> _folders = [];
  List<ContractDocument> _documents = [];
  bool _isLoading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final folders = await _repo.getArchivedFolders();
    final documents = await _repo.getArchivedDocuments();
    if (!mounted) return;
    setState(() { _folders = folders; _documents = documents; _isLoading = false; });
  }

  String _formatDate(String? iso) {
    if (iso == null) return "—";
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  Future<void> _restoreFolder(ContractFolder folder) async {
    await _repo.restoreFolder(folder.id!, performedBy: "مدير النظام");
    _changed = true;
    _loadData();
  }

  Future<void> _restoreDocument(ContractDocument document) async {
    await _repo.restoreDocument(document.id!, performedBy: "مدير النظام");
    _changed = true;
    _loadData();
  }

  Future<void> _permanentDeleteFolder(ContractFolder folder) async {
    final proceed = await _warningStep("المجلد \"${folder.name}\"", "سيتم حذف هذا المجلد وكل ما بداخله (مجلدات فرعية ومستندات مهما بلغ عددها) نهائياً.");
    if (proceed != true || !mounted) return;
    final name = await _typeNameStep(folder.name);
    if (name != true || !mounted) return;
    final reason = await _reasonStep();
    if (reason == null || !mounted) return;
    final verified = await _pinStep();
    if (verified != true || !mounted) return;
    await _repo.deleteFolderPermanently(folder, performedBy: "مدير النظام", reason: reason);
    _changed = true;
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم حذف \"${folder.name}\" نهائياً"))); _loadData(); }
  }

  Future<void> _permanentDeleteDocument(ContractDocument document) async {
    final proceed = await _warningStep("المستند \"${document.name}\"", "سيتم حذف هذا المستند وملفه المرفق نهائياً من النظام.");
    if (proceed != true || !mounted) return;
    final name = await _typeNameStep(document.name);
    if (name != true || !mounted) return;
    final reason = await _reasonStep();
    if (reason == null || !mounted) return;
    final verified = await _pinStep();
    if (verified != true || !mounted) return;
    await _repo.deleteDocumentPermanently(document, performedBy: "مدير النظام", reason: reason);
    _changed = true;
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم حذف \"${document.name}\" نهائياً"))); _loadData(); }
  }

  Future<bool?> _warningStep(String entityLabel, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: AppColors.danger), SizedBox(width: 8), Expanded(child: Text("حذف نهائي — لا يمكن التراجع", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15)))]),
        content: Text("$entityLabel: $message هذا الإجراء لا يمكن التراجع عنه إطلاقاً بعد تنفيذه."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("متابعة", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Future<bool?> _typeNameStep(String exactName) {
    final controller = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matches = controller.text.trim() == exactName;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text("تأكيد الحذف", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("للمتابعة، اكتب الاسم بالضبط:", style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(exactName, style: AppTextStyles.bodyBold),
                const SizedBox(height: AppSizes.sm),
                AppTextField(controller: controller, hint: "الاسم", onChanged: (_) => setDialogState(() {})),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
              TextButton(onPressed: matches ? () => Navigator.pop(context, true) : null, child: Text("متابعة", style: TextStyle(color: matches ? AppColors.danger : Colors.grey, fontWeight: FontWeight.bold))),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _reasonStep() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final valid = controller.text.trim().isNotEmpty;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text("سبب الحذف النهائي", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("يُسجَّل هذا السبب في سجل التدقيق قبل الحذف مباشرة، إلزامي.", style: AppTextStyles.caption),
                const SizedBox(height: AppSizes.sm),
                AppTextField(controller: controller, hint: "سبب الحذف", icon: Icons.notes_outlined, maxLines: 2, onChanged: (_) => setDialogState(() {})),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
              TextButton(onPressed: valid ? () => Navigator.pop(context, controller.text.trim()) : null, child: Text("متابعة", style: TextStyle(color: valid ? AppColors.danger : Colors.grey, fontWeight: FontWeight.bold))),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _pinStep() {
    final controller = TextEditingController();
    String? errorText;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text("تأكيد صلاحية المدير", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("أدخل رمز PIN للمتابعة بالحذف النهائي.", style: AppTextStyles.caption),
                const SizedBox(height: AppSizes.sm),
                AppTextField(controller: controller, hint: "رمز PIN", isPassword: true, keyboardType: TextInputType.number, errorText: errorText),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
              TextButton(
                onPressed: () async {
                  final ok = await SecurityService.instance.verifyPin(controller.text.trim());
                  if (ok) {
                    if (context.mounted) Navigator.pop(context, true);
                  } else {
                    setDialogState(() => errorText = "رمز غير صحيح");
                  }
                },
                child: const Text("تأكيد الحذف النهائي", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = !_isLoading && _folders.isEmpty && _documents.isEmpty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) Navigator.pop(context, _changed); },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("أرشيف مستندات العقود", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.danger,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : isEmpty
                ? const ContractEmptyState(icon: Icons.archive_outlined, title: "الأرشيف فارغ", message: "المجلدات والمستندات المؤرشَفة تظهر هنا.")
                : ListView(
                    padding: const EdgeInsets.all(AppSizes.md),
                    children: [
                      if (_folders.isNotEmpty) ...[
                        Text("المجلدات المؤرشَفة", style: AppTextStyles.bodyBold),
                        const SizedBox(height: AppSizes.sm),
                        for (final f in _folders) Padding(padding: const EdgeInsets.only(bottom: AppSizes.sm), child: _buildFolderRow(f)),
                        const SizedBox(height: AppSizes.md),
                      ],
                      if (_documents.isNotEmpty) ...[
                        Text("المستندات المؤرشَفة", style: AppTextStyles.bodyBold),
                        const SizedBox(height: AppSizes.sm),
                        for (final d in _documents) Padding(padding: const EdgeInsets.only(bottom: AppSizes.sm), child: _buildDocumentRow(d)),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _buildFolderRow(ContractFolder folder) {
    final color = Color(folder.colorValue);
    return AppCard(
      identityAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(ContractFolderIcons.iconFor(folder.iconKey), color: color, size: 20)),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: Text(folder.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text("أُرشِف: ${_formatDate(folder.archivedAt)}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
              const SizedBox(width: AppSizes.md),
              const Icon(Icons.person_outline, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text("بواسطة: ${folder.archivedBy ?? '—'}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
          if (folder.archiveReason != null && folder.archiveReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text("السبب: ${folder.archiveReason}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _restoreFolder(folder), icon: const Icon(Icons.restore_rounded, size: 18), label: const Text("استعادة"))),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: OutlinedButton.icon(onPressed: () => _permanentDeleteFolder(folder), style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)), icon: const Icon(Icons.delete_forever_outlined, size: 18), label: const Text("حذف نهائي"))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(ContractDocument document) {
    final color = ContractFileTypes.colorFor(document.fileType);
    return AppCard(
      identityAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(ContractFileTypes.iconFor(document.fileType), color: color, size: 20)),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: Text(document.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text("أُرشِف: ${_formatDate(document.archivedAt)}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
              const SizedBox(width: AppSizes.md),
              const Icon(Icons.person_outline, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text("بواسطة: ${document.archivedBy ?? '—'}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
          if (document.archiveReason != null && document.archiveReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text("السبب: ${document.archiveReason}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _restoreDocument(document), icon: const Icon(Icons.restore_rounded, size: 18), label: const Text("استعادة"))),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: OutlinedButton.icon(onPressed: () => _permanentDeleteDocument(document), style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)), icon: const Icon(Icons.delete_forever_outlined, size: 18), label: const Text("حذف نهائي"))),
            ],
          ),
        ],
      ),
    );
  }
}
