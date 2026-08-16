import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/document_status.dart';
import '../../../models/document.dart';
import '../../../models/document_attachment.dart';
import '../../../models/hotel.dart';
import '../../../repositories/document_repository.dart';
import '../../../services/attachment_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/trash_confirm_dialogs.dart';

/// تعبئة/تعديل بيانات نسخة الفندق من مستند مرجعي (رقم، تواريخ، جهة مصدرة،
/// ملاحظات، مرفقات) — لا يُسمح بإنشاء نوع مستند جديد من هنا (يُدار حصراً من
/// "البيانات المرجعية"). المستندات القديمة غير المرتبطة بنوع (من قبل هذه
/// الميزة) تُحرَّر بشكل مبسَّط (الاسم/التاريخ فقط) وتبقى قابلة للحذف.
class HotelDocumentEditPage extends StatefulWidget {
  /// null للمستندات "العامة" (hotelId=null) التي تُعدَّل مباشرة من داخل
  /// "المستندات الدائمة" بلا الحاجة للدخول لأي فندق — الشاشة تستخدم الثيم
  /// الافتراضي للتطبيق في هذه الحالة بدل هوية فندق بصرية.
  final Hotel? hotel;
  final Document document;
  const HotelDocumentEditPage({super.key, this.hotel, required this.document});

  @override
  State<HotelDocumentEditPage> createState() => _HotelDocumentEditPageState();
}

class _HotelDocumentEditPageState extends State<HotelDocumentEditPage> {
  final _repository = DocumentRepository();
  late Document _document;

  final _nameController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _notesController = TextEditingController();

  List<DocumentAttachment> _attachments = [];
  bool _isLoadingAttachments = true;
  bool _isSaving = false;

  bool get _isLegacy => !_document.isLinkedToType;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _nameController.text = _document.typeName ?? _document.name;
    _documentNumberController.text = _document.documentNumber ?? '';
    _expiryDateController.text = _document.expiryDate;
    _notesController.text = _document.notes ?? '';
    _loadAttachments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _documentNumberController.dispose();
    _expiryDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAttachments() async {
    if (_document.id == null) return;
    final attachments = await _repository.getAttachments(_document.id!);
    if (!mounted) return;
    setState(() {
      _attachments = attachments;
      _isLoadingAttachments = false;
    });
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = picked.toString().split(' ')[0]);
    }
  }

  Future<void> _save() async {
    if (_document.requiresRenewal && _expiryDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("هذا المستند يحتاج إلى تجديد، يرجى تحديد تاريخ الانتهاء")));
      return;
    }
    if (_isLegacy && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال اسم المستند")));
      return;
    }

    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد الحفظ",
      message: "هل تريد حفظ بيانات هذا المستند؟",
      onConfirm: () async {
        setState(() => _isSaving = true);
        final updated = _document.copyWith(
          name: _isLegacy ? _nameController.text.trim() : _document.name,
          documentNumber: _documentNumberController.text.trim().isEmpty ? null : _documentNumberController.text.trim(),
          expiryDate: _expiryDateController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await _repository.updateDocument(updated);
        if (mounted) Navigator.pop(context, true);
      },
    );
    if (mounted) setState(() => _isSaving = false);
  }

  /// نقل ناعم إلى سلة المهملات (لا حذف فعلي، لا حذف ملفات — راجع
  /// DocumentRepository.deleteDocument). إن كان المستند نسخة فندق تلقائية
  /// مرتبطة بنوع مرجعي (owner_type='hotel')، تُعاد تزويد الفندق فوراً بنسخة
  /// فارغة من نفس النوع بدل ترك فجوة — النقل للسلة هنا يعني "إعادة تعيين
  /// بيانات هذا المستند" وليس "هذا الفندق لم يعد بحاجة لهذا النوع" (يُضبط
  /// ذلك من البيانات المرجعية فقط). لا ينطبق هذا على مستندات موظف/مورد
  /// المرتبطة بنوع، لأنها ليست نُسخاً تلقائية للفندق أصلاً.
  Future<void> _deleteDocument() async {
    final wasHotelOwnedType = _document.isLinkedToType && _document.ownerType == Document.ownerTypeHotel;
    if (_document.id == null) return;
    await TrashConfirmDialogs.confirmMoveToTrash(context, () async {
      await _repository.deleteDocument(_document);
      if (wasHotelOwnedType) {
        await _repository.reprovisionHotelDocumentTypes();
      }
      if (mounted) Navigator.pop(context, true);
    });
  }

  // ---------------- المرفقات ----------------

  Future<void> _addImages() async {
    final picked = await AttachmentService.pickImages(folder: 'document_attachments');
    if (picked.isEmpty || _document.id == null) return;
    for (final file in picked) {
      await _repository.addAttachment(DocumentAttachment(
        documentId: _document.id!,
        hotelId: _document.hotelId ?? 0,
        filePath: file.path,
        fileType: 'image',
        fileName: file.name,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }
    await _loadAttachments();
  }

  Future<void> _addPdf() async {
    final picked = await AttachmentService.pickPdf(folder: 'document_attachments');
    if (picked == null || _document.id == null) return;
    await _repository.addAttachment(DocumentAttachment(
      documentId: _document.id!,
      hotelId: _document.hotelId ?? 0,
      filePath: picked.path,
      fileType: 'pdf',
      fileName: picked.name,
      createdAt: DateTime.now().toIso8601String(),
    ));
    await _loadAttachments();
  }

  Future<void> _deleteAttachment(DocumentAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف المرفق"),
        content: const Text("هل تريد حذف هذا المرفق نهائياً؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("حذف", style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || attachment.id == null) return;
    await _repository.deleteAttachment(attachment.id!);
    await AttachmentService.deleteFile(attachment.filePath);
    await _loadAttachments();
  }

  /// استبدال مرفق عند تجديد المستند — يحذف الملف/الصف القديم ثم يفتح نفس
  /// منتقي النوع (صورة/PDF) لإضافة البديل، بلا إنشاء أي سجل مستند جديد.
  Future<void> _replaceAttachment(DocumentAttachment attachment) async {
    if (attachment.id == null) return;
    await _repository.deleteAttachment(attachment.id!);
    await AttachmentService.deleteFile(attachment.filePath);
    if (attachment.isPdf) {
      await _addPdf();
    } else {
      await _addImages();
    }
  }

  void _showAttachmentMenu(DocumentAttachment attachment) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text("فتح"),
              onTap: () {
                Navigator.pop(sheetContext);
                OpenFilex.open(attachment.filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text("مشاركة / تنزيل"),
              onTap: () {
                Navigator.pop(sheetContext);
                Share.shareXFiles([XFile(attachment.filePath)], text: attachment.fileName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text("استبدال (عند التجديد)"),
              onTap: () {
                Navigator.pop(sheetContext);
                _replaceAttachment(attachment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text("حذف", style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteAttachment(attachment);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = DocumentStatus.fromExpiryDate(_expiryDateController.text);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("بيانات المستند", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          if (!_isLegacy) _buildTypeInfoCard(status),
          const SizedBox(height: AppSizes.md),
          AppCard(
            child: Column(
              children: [
                if (_isLegacy) ...[
                  AppTextField(controller: _nameController, hint: "اسم المستند", icon: Icons.description_outlined),
                  const SizedBox(height: AppSizes.md),
                ],
                AppTextField(controller: _documentNumberController, hint: "رقم المستند (اختياري)", icon: Icons.numbers_outlined),
                const SizedBox(height: AppSizes.md),
                _buildDateField(_document.requiresRenewal ? "تاريخ الانتهاء (إجباري)" : "تاريخ الانتهاء (اختياري)", _expiryDateController),
                const SizedBox(height: AppSizes.md),
                AppTextField(controller: _notesController, hint: "ملاحظات (اختياري)", icon: Icons.notes_outlined, maxLines: 3),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          _buildAttachmentsSection(),
          const SizedBox(height: AppSizes.xl),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text("حفظ"),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: AppSizes.md),
          OutlinedButton.icon(
            onPressed: _deleteDocument,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            label: const Text("حذف المستند", style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeInfoCard(DocumentStatusInfo status) {
    return AppCard(
      color: status.color.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status.icon, color: status.color),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: Text(_document.typeName ?? _document.name, style: AppTextStyles.title.copyWith(fontSize: 16))),
            ],
          ),
          if (_document.typeDescription != null && _document.typeDescription!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.xs),
            Text(_document.typeDescription!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (_document.categoryName != null) _tag(_document.categoryName!, Color(_document.categoryColor ?? 0xFF7A1E2C)),
              if (_document.isMandatory) _tag("إلزامي", AppColors.danger),
              _tag(_document.requiresRenewal ? "يحتاج تجديد" : "بلا تجديد", AppColors.info),
              _tag(status.label, status.color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return GestureDetector(
      onTap: () => _pickDate(controller),
      child: AbsorbPointer(
        child: AppTextField(controller: controller, hint: label, icon: Icons.calendar_today_outlined),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("المرفقات", style: AppTextStyles.bodyBold),
              const Spacer(),
              IconButton(onPressed: _addImages, icon: const Icon(Icons.add_photo_alternate_outlined), tooltip: "إرفاق صورة"),
              IconButton(onPressed: _addPdf, icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: "إرفاق PDF"),
            ],
          ),
          if (_isLoadingAttachments)
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSizes.md), child: Center(child: CircularProgressIndicator()))
          else if (_attachments.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSizes.sm), child: Text("لا توجد مرفقات بعد", style: AppTextStyles.caption))
          else
            Wrap(spacing: 8, runSpacing: 8, children: _attachments.map(_buildAttachmentTile).toList()),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(DocumentAttachment attachment) {
    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => OpenFilex.open(attachment.filePath),
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: attachment.isPdf
                ? const Center(child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 36))
                : Image.file(File(attachment.filePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
          ),
        ),
        Positioned(
          top: 2,
          left: 2,
          child: GestureDetector(
            onTap: () => _showAttachmentMenu(attachment),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
