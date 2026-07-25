import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/contract_document_options.dart';
import '../../../models/contract_document.dart';
import '../../../repositories/contract_document_repository.dart';
import '../../../services/attachment_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';

/// إنشاء مستند جديد (يتطلب اختيار مرفق) أو تعديل بيانات مستند موجود
/// ([document] != null، بلا تغيير المرفق هنا — راجع "استبدال المرفق" في
/// DocumentDetailsSheet). دعم أنواع ملفات مستقبلية عبر ContractFileTypes.fromExtension
/// (لا حاجة لتعديل هذه الصفحة عند إضافة امتداد جديد).
class CreateEditDocumentPage extends StatefulWidget {
  final int? folderId;
  final ContractDocument? document;
  const CreateEditDocumentPage({super.key, this.folderId, this.document});

  @override
  State<CreateEditDocumentPage> createState() => _CreateEditDocumentPageState();
}

class _CreateEditDocumentPageState extends State<CreateEditDocumentPage> {
  final _repo = ContractDocumentRepository();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _categoryController;
  late final TextEditingController _notesController;
  final _tagController = TextEditingController();
  List<String> _tags = [];
  DateTime? _expiryDate;
  DateTime? _reminderDate;
  ({String path, String name})? _pickedFile;
  bool _isSaving = false;
  String? _nameError;
  String? _fileError;

  bool get _isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _nameController = TextEditingController(text: doc?.name ?? '');
    _descController = TextEditingController(text: doc?.description ?? '');
    _categoryController = TextEditingController(text: doc?.category ?? '');
    _notesController = TextEditingController(text: doc?.notes ?? '');
    _tags = doc?.tags.toList() ?? [];
    _expiryDate = doc?.expiryDate == null ? null : DateTime.tryParse(doc!.expiryDate!);
    _reminderDate = doc?.reminderDate == null ? null : DateTime.tryParse(doc!.reminderDate!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(String source) async {
    ({String path, String name})? picked;
    if (source == 'camera') picked = await AttachmentService.captureImage(folder: 'contract_documents');
    if (source == 'gallery') {
      final images = await AttachmentService.pickImages(folder: 'contract_documents');
      picked = images.isEmpty ? null : images.first;
    }
    if (source == 'files') picked = await AttachmentService.pickAnyDocument(folder: 'contract_documents');
    if (picked != null) setState(() { _pickedFile = picked; _fileError = null; });
  }

  Future<void> _pickDate({required bool isExpiry}) async {
    final initial = (isExpiry ? _expiryDate : _reminderDate) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() { if (isExpiry) _expiryDate = picked; else _reminderDate = picked; });
  }

  void _addTag() {
    final t = _tagController.text.trim();
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() { _tags.add(t); _tagController.clear(); });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) { setState(() => _nameError = "اسم المستند مطلوب"); return; }
    if (!_isEditing && _pickedFile == null) { setState(() => _fileError = "يجب اختيار مرفق"); return; }
    setState(() => _isSaving = true);
    final category = _categoryController.text.trim();
    final notes = _notesController.text.trim();
    final description = _descController.text.trim();
    if (_isEditing) {
      await _repo.updateDocument(widget.document!.copyWith(
        name: name,
        description: description,
        category: category,
        tags: _tags,
        notes: notes,
        expiryDate: _expiryDate?.toIso8601String(),
        clearExpiryDate: _expiryDate == null,
        reminderDate: _reminderDate?.toIso8601String(),
        clearReminderDate: _reminderDate == null,
      ));
    } else {
      await _repo.createDocument(
        folderId: widget.folderId,
        name: name,
        description: description,
        category: category,
        tags: _tags,
        notes: notes,
        filePath: _pickedFile!.path,
        fileName: _pickedFile!.name,
        fileType: ContractFileTypes.fromExtension(_pickedFile!.name),
        expiryDate: _expiryDate?.toIso8601String(),
        reminderDate: _reminderDate?.toIso8601String(),
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  String _formatDate(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? "تعديل المستند" : "إنشاء مستند", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          AppTextField(controller: _nameController, hint: "اسم المستند", icon: Icons.description_outlined, errorText: _nameError, onChanged: (_) => setState(() => _nameError = null)),
          const SizedBox(height: AppSizes.sm),
          AppTextField(controller: _descController, hint: "وصف اختياري", icon: Icons.notes_outlined, maxLines: 2),
          const SizedBox(height: AppSizes.sm),
          AppTextField(controller: _categoryController, hint: "الفئة", icon: Icons.category_outlined),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final c in ContractDocumentCategories.suggestions)
                ActionChip(label: Text(c, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _categoryController.text = c)),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(child: AppTextField(controller: _tagController, hint: "إضافة وسم", icon: Icons.local_offer_outlined, onSubmitted: (_) => _addTag())),
              IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), onPressed: _addTag),
            ],
          ),
          if (_tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _tags) Chip(label: Text(t), onDeleted: () => setState(() => _tags.remove(t))),
              ],
            ),
          const SizedBox(height: AppSizes.sm),
          AppTextField(controller: _notesController, hint: "ملاحظات", icon: Icons.sticky_note_2_outlined, maxLines: 3),
          const SizedBox(height: AppSizes.md),
          _dateField(label: "تاريخ الانتهاء (اختياري)", value: _expiryDate, onTap: () => _pickDate(isExpiry: true), onClear: () => setState(() => _expiryDate = null)),
          const SizedBox(height: AppSizes.sm),
          _dateField(label: "تذكير (اختياري)", value: _reminderDate, onTap: () => _pickDate(isExpiry: false), onClear: () => setState(() => _reminderDate = null)),
          if (!_isEditing) ...[
            const SizedBox(height: AppSizes.md),
            Text("المرفق", style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(child: _attachButton(Icons.camera_alt_outlined, "الكاميرا", () => _pickAttachment('camera'))),
                const SizedBox(width: AppSizes.sm),
                Expanded(child: _attachButton(Icons.photo_library_outlined, "المعرض", () => _pickAttachment('gallery'))),
                const SizedBox(width: AppSizes.sm),
                Expanded(child: _attachButton(Icons.folder_open_outlined, "الملفات", () => _pickAttachment('files'))),
              ],
            ),
            if (_pickedFile != null) ...[
              const SizedBox(height: AppSizes.sm),
              AppCard(
                child: Row(
                  children: [
                    Icon(ContractFileTypes.iconFor(ContractFileTypes.fromExtension(_pickedFile!.name)), color: AppColors.primary),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(child: Text(_pickedFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
            if (_fileError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_fileError!, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
          ],
          const SizedBox(height: AppSizes.lg),
          AppButton(text: _isEditing ? "حفظ التعديلات" : "إنشاء المستند", onPressed: _isSaving ? () {} : _save, isLoading: _isSaving),
        ],
      ),
    );
  }

  Widget _dateField({required String label, required DateTime? value, required VoidCallback onTap, required VoidCallback onClear}) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, color: Colors.grey, size: 20),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(value == null ? label : "$label: ${_formatDate(value)}", style: TextStyle(color: value == null ? Colors.grey.shade600 : null))),
            if (value != null) InkWell(onTap: onClear, child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _attachButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label, style: const TextStyle(fontSize: 12)));
  }
}
