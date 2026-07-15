import 'package:flutter/material.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/document_category.dart';
import '../../../models/document_type.dart';
import '../../../models/hotel.dart';
import '../../../repositories/document_type_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/common/app_text_field.dart';

/// إنشاء/تعديل "مجلد" (نوع مستند مرجعي) — نموذج مبسَّط عمداً (اسم،
/// وصف، ونطاق فنادق اختياري) بلا حقول "أنواع المستندات" الأثقل (فئة/إلزامي/
/// يحتاج تجديد) التي لا معنى لها لمجلد تنظيمي مؤقت. مشتركة بين كل أقسام
/// المستندات ذات المجلدات الحرة (الموسمية، مستندات الموظفين، وأي دورة حياة
/// مستقبلية) عبر [lifecycle] — لا يوجد ملف منفصل لكل قسم، بلا أي تكرار كود.
/// المجلد نفسه صف document_types بدون أي تزويد تلقائي للفنادق
/// (autoProvision: false دوماً) — المجلد حاوية مراجع فقط.
class AddEditDocumentFolderPage extends StatefulWidget {
  final DocumentType? folder;
  final String lifecycle;
  final String nameHint;
  final bool showHotelScope;
  const AddEditDocumentFolderPage({
    super.key,
    this.folder,
    required this.lifecycle,
    required this.nameHint,
    this.showHotelScope = true,
  });

  @override
  State<AddEditDocumentFolderPage> createState() => _AddEditDocumentFolderPageState();
}

class _AddEditDocumentFolderPageState extends State<AddEditDocumentFolderPage> {
  final _repository = DocumentTypeRepository();
  final _hotelRepository = HotelRepository();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool get _isEditMode => widget.folder != null;

  List<Hotel> _hotels = [];
  List<DocumentCategory> _categories = [];
  String _scope = 'all';
  Set<int> _selectedHotelIds = {};

  String? _nameError;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.showHotelScope) _hotels = await _hotelRepository.getAllHotels();
    _categories = await _repository.getCategories();

    final folder = widget.folder;
    if (folder != null) {
      _nameController.text = folder.name;
      _descriptionController.text = folder.description ?? '';
      _scope = folder.scope;
      if (widget.showHotelScope && _scope == 'specific') {
        _selectedHotelIds = (await _repository.getHotelsForType(folder.id!)).toSet();
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = "اسم المجلد إجباري");
      return;
    }
    if (widget.showHotelScope && _scope == 'specific' && _selectedHotelIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار فندق واحد على الأقل")));
      return;
    }

    final existing = await _repository.getTypeByName(name);
    if (!mounted) return;
    if (existing != null && existing.id != widget.folder?.id) {
      setState(() => _nameError = "هذا الاسم مستخدم لمجلد أو نوع مستند آخر بالفعل");
      return;
    }
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يجب وجود فئة واحدة على الأقل في البيانات المرجعية أولاً")));
      return;
    }

    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: _isEditMode ? "تأكيد الحفظ" : "تأكيد الإضافة",
      message: _isEditMode ? "هل تريد حفظ التعديلات على هذا المجلد؟" : "هل تريد إنشاء هذا المجلد؟",
      onConfirm: () async {
        setState(() => _isSaving = true);
        final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
        final scope = widget.showHotelScope ? _scope : 'all';
        final hotelIds = widget.showHotelScope && scope == 'specific' ? _selectedHotelIds.toList() : <int>[];

        if (_isEditMode) {
          await _repository.updateType(
            widget.folder!.copyWith(name: name, description: description, scope: scope),
            hotelIds: hotelIds,
            autoProvision: false,
          );
        } else {
          await _repository.addType(
            DocumentType(
              name: name,
              description: description,
              categoryId: _categories.first.id!,
              scope: scope,
              lifecycle: widget.lifecycle,
              createdAt: DateTime.now().toIso8601String(),
            ),
            hotelIds: hotelIds,
            autoProvision: false,
          );
        }
        if (mounted) Navigator.pop(context, true);
      },
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? "تعديل المجلد" : "مجلد جديد", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                AppCard(
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _nameController,
                        hint: widget.nameHint,
                        icon: Icons.folder_outlined,
                        errorText: _nameError,
                        onChanged: (_) {
                          if (_nameError != null) setState(() => _nameError = null);
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      AppTextField(controller: _descriptionController, hint: "وصف (اختياري)", icon: Icons.notes_outlined, maxLines: 3),
                    ],
                  ),
                ),
                if (widget.showHotelScope) ...[
                  const SizedBox(height: AppSizes.md),
                  _buildScopeSection(),
                ],
                const SizedBox(height: AppSizes.xl),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isEditMode ? "حفظ التعديلات" : "إنشاء المجلد"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: AppSizes.md),
              ],
            ),
    );
  }

  Widget _buildScopeSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("نطاق المجلد", style: AppTextStyles.bodyBold),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text("جميع الفنادق"),
            value: 'all',
            groupValue: _scope,
            onChanged: (v) => setState(() => _scope = v!),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text("فنادق محددة"),
            value: 'specific',
            groupValue: _scope,
            onChanged: (v) => setState(() => _scope = v!),
          ),
          if (_scope == 'specific') ...[
            const Divider(height: 1),
            const SizedBox(height: AppSizes.sm),
            if (_hotels.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: AppSizes.sm), child: Text("لا توجد فنادق مسجَّلة", style: AppTextStyles.caption))
            else
              ..._hotels.map((h) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(h.arabicName),
                    value: _selectedHotelIds.contains(h.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedHotelIds.add(h.id!);
                        } else {
                          _selectedHotelIds.remove(h.id);
                        }
                      });
                    },
                  )),
          ],
        ],
      ),
    );
  }
}
