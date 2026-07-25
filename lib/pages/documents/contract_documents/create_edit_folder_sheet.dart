import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/contract_document_options.dart';
import '../../../core/hotel_color_palettes.dart';
import '../../../models/contract_folder.dart';
import '../../../repositories/contract_document_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/common/app_text_field.dart';

/// نافذة سفلية لإنشاء مجلد جديد أو تعديل مجلد موجود ([folder] != null) — اسم
/// إلزامي (فريد بين إخوته في نفس المستوى)، وصف اختياري، أيقونة ولون من قوائم
/// جاهزة. غلاف المجلد (Cover Image) مُعَدّ للمستقبل فقط ولا يُطلب هنا الآن.
class CreateEditFolderSheet extends StatefulWidget {
  final int? parentId;
  final ContractFolder? folder;
  const CreateEditFolderSheet({super.key, this.parentId, this.folder});

  @override
  State<CreateEditFolderSheet> createState() => _CreateEditFolderSheetState();
}

class _CreateEditFolderSheetState extends State<CreateEditFolderSheet> {
  final _repo = ContractDocumentRepository();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  String _iconKey = ContractFolderIcons.defaultKey;
  int _colorValue = HotelColorPalettes.defaultColorValue;
  bool _isSaving = false;
  String? _nameError;

  bool get _isEditing => widget.folder != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder?.name ?? '');
    _descController = TextEditingController(text: widget.folder?.description ?? '');
    if (widget.folder != null) {
      _iconKey = widget.folder!.iconKey;
      _colorValue = widget.folder!.colorValue;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = "اسم المجلد مطلوب");
      return;
    }
    setState(() => _isSaving = true);
    final taken = await _repo.isFolderNameTaken(name, parentId: widget.parentId, excludeId: widget.folder?.id);
    if (taken) {
      setState(() {
        _isSaving = false;
        _nameError = "يوجد مجلد بهذا الاسم في نفس المكان";
      });
      return;
    }
    if (_isEditing) {
      await _repo.updateFolder(
        widget.folder!.copyWith(name: name, description: _descController.text.trim(), iconKey: _iconKey, colorValue: _colorValue),
        previous: widget.folder,
      );
    } else {
      await _repo.createFolder(name: name, description: _descController.text.trim(), iconKey: _iconKey, colorValue: _colorValue, parentId: widget.parentId);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
        padding: const EdgeInsets.all(AppSizes.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: AppSizes.md),
              Text(_isEditing ? "تعديل المجلد" : "إنشاء مجلد", style: AppTextStyles.title.copyWith(fontSize: 17)),
              const SizedBox(height: AppSizes.md),
              AppTextField(controller: _nameController, hint: "اسم المجلد", icon: Icons.folder_outlined, errorText: _nameError, onChanged: (_) => setState(() => _nameError = null)),
              const SizedBox(height: AppSizes.sm),
              AppTextField(controller: _descController, hint: "وصف اختياري", icon: Icons.notes_outlined, maxLines: 2),
              const SizedBox(height: AppSizes.md),
              Text("الأيقونة", style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSizes.sm),
              Wrap(
                spacing: AppSizes.sm,
                runSpacing: AppSizes.sm,
                children: [
                  for (final option in ContractFolderIcons.all)
                    _IconChoice(option: option, selected: _iconKey == option.key, color: Color(_colorValue), onTap: () => setState(() => _iconKey = option.key)),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              Text("اللون", style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSizes.sm),
              Wrap(
                spacing: AppSizes.sm,
                runSpacing: AppSizes.sm,
                children: [
                  for (final option in HotelColorPalettes.all)
                    _ColorChoice(color: option.color, selected: _colorValue == option.color.toARGB32(), onTap: () => setState(() => _colorValue = option.color.toARGB32())),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              AppButton(text: _isEditing ? "حفظ التعديلات" : "إنشاء المجلد", onPressed: _isSaving ? () {} : _save, isLoading: _isSaving),
              const SizedBox(height: AppSizes.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final FolderIconOption option;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _IconChoice({required this.option, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: selected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Icon(option.icon, color: selected ? color : Colors.grey.shade600, size: 22),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorChoice({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: AppColors.primary, width: 2.5) : Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
      ),
    );
  }
}
