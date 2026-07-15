import 'package:flutter/material.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/document_category.dart';
import '../../models/document_type.dart';
import '../../models/hotel.dart';
import '../../repositories/document_type_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';

/// إضافة/تعديل نوع مستند مرجعي واحد — الحقول بالضبط كما هي محددة: اسم
/// (إجباري وفريد)، وصف (اختياري)، فئة، إلزامي؟، يحتاج تجديد؟، نطاق
/// التطبيق (كل الفنادق/فنادق محددة)، تفعيل. الحفظ ينشر النوع فوراً على كل
/// الفنادق المطابقة إن كان مفعَّلاً (راجع DocumentTypeRepository.addType/updateType).
class AddEditDocumentTypePage extends StatefulWidget {
  final DocumentType? documentType;

  /// قيمة مبدئية لدورة الحياة (دائم/موسمي) عند فتح هذه الصفحة من داخل مجلد
  /// معيّن (مثل "المستندات الدائمة") — تُتجاهَل في وضع التعديل (تُستخدم قيمة
  /// النوع الحالية دوماً).
  final String? presetLifecycle;

  /// `false` عند فتح هذه الصفحة من "مجلدات" قسم المستندات (دائم/موسمي) —
  /// تلك حاويات مراجع فقط ولا يجب أن تُنشئ نسخة مستند فارغة تلقائياً لكل
  /// فندق. تبقى `true` (الافتراضي) فقط لأنواع "مستندات الفندق" الحقيقية
  /// المُدارة من "البيانات المرجعية".
  final bool autoProvision;

  const AddEditDocumentTypePage({super.key, this.documentType, this.presetLifecycle, this.autoProvision = true});

  @override
  State<AddEditDocumentTypePage> createState() => _AddEditDocumentTypePageState();
}

class _AddEditDocumentTypePageState extends State<AddEditDocumentTypePage> {
  final _repository = DocumentTypeRepository();
  final _hotelRepository = HotelRepository();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool get _isEditMode => widget.documentType != null;

  List<DocumentCategory> _categories = [];
  int? _selectedCategoryId;
  bool _isMandatory = false;
  bool _requiresRenewal = false;
  String _scope = 'all';
  bool _isActive = true;
  late String _lifecycle;

  List<Hotel> _allHotels = [];
  Set<int> _selectedHotelIds = {};

  String? _nameError;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = widget.documentType?.lifecycle ?? widget.presetLifecycle ?? DocumentType.lifecyclePermanent;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _categories = await _repository.getCategories();
    _allHotels = await _hotelRepository.getAllHotels();

    final type = widget.documentType;
    if (type != null) {
      _nameController.text = type.name;
      _descriptionController.text = type.description ?? '';
      _selectedCategoryId = type.categoryId;
      _isMandatory = type.isMandatory;
      _requiresRenewal = type.requiresRenewal;
      _scope = type.scope;
      _isActive = type.isActive;
      if (_scope == 'specific') {
        _selectedHotelIds = (await _repository.getHotelsForType(type.id!)).toSet();
      }
    } else if (_categories.isNotEmpty) {
      _selectedCategoryId = _categories.first.id;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addCategoryInline() async {
    String name = '';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("فئة جديدة"),
        content: TextField(
          decoration: const InputDecoration(labelText: "اسم الفئة"),
          onChanged: (v) => name = v,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              final trimmed = name.trim();
              if (trimmed.isEmpty) return;
              final existing = await _repository.getCategoryByName(trimmed);
              if (existing != null) {
                if (context.mounted) Navigator.pop(context);
                setState(() => _selectedCategoryId = existing.id);
                return;
              }
              final newId = await _repository.addCategory(DocumentCategory(
                name: trimmed,
                colorValue: 0xFF7A1E2C,
                createdAt: DateTime.now().toIso8601String(),
              ));
              if (context.mounted) Navigator.pop(context);
              _categories = await _repository.getCategories();
              setState(() => _selectedCategoryId = newId);
            },
            child: const Text("إضافة"),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = "اسم المستند إجباري");
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار فئة")));
      return;
    }

    final existing = await _repository.getTypeByName(name);
    if (existing != null && existing.id != widget.documentType?.id) {
      setState(() => _nameError = "هذا الاسم مستخدم لنوع مستند آخر بالفعل");
      return;
    }

    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: _isEditMode ? "تأكيد الحفظ" : "تأكيد الإضافة",
      message: _isEditMode
          ? "هل تريد حفظ التعديلات؟ سيظهر الاسم الجديد فوراً في كل الفنادق ولن يُغيَّر أي سجل قديم مرتبط به."
          : "هل تريد إضافة هذا النوع؟ سيُزوَّد به فوراً كل الفنادق المطابقة للنطاق المختار.",
      onConfirm: () async {
        setState(() => _isSaving = true);
        final hotelIds = _scope == 'specific' ? _selectedHotelIds.toList() : <int>[];
        if (_isEditMode) {
          await _repository.updateType(
            widget.documentType!.copyWith(
              name: name,
              description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
              categoryId: _selectedCategoryId,
              isMandatory: _isMandatory,
              requiresRenewal: _requiresRenewal,
              scope: _scope,
              isActive: _isActive,
              lifecycle: _lifecycle,
            ),
            hotelIds: hotelIds,
            autoProvision: widget.autoProvision,
          );
        } else {
          await _repository.addType(
            DocumentType(
              name: name,
              description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
              categoryId: _selectedCategoryId!,
              isMandatory: _isMandatory,
              requiresRenewal: _requiresRenewal,
              scope: _scope,
              isActive: _isActive,
              lifecycle: _lifecycle,
              createdAt: DateTime.now().toIso8601String(),
            ),
            hotelIds: hotelIds,
            autoProvision: widget.autoProvision,
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
        title: Text(_isEditMode ? "تعديل نوع المستند" : "إضافة نوع مستند", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                        hint: "اسم المستند",
                        icon: Icons.description_outlined,
                        errorText: _nameError,
                        onChanged: (_) {
                          if (_nameError != null) setState(() => _nameError = null);
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      AppTextField(
                        controller: _descriptionController,
                        hint: "الوصف (اختياري)",
                        icon: Icons.notes_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _buildCategorySection(),
                const SizedBox(height: AppSizes.md),
                AppCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("هل هذا المستند إلزامي؟"),
                        value: _isMandatory,
                        onChanged: (v) => setState(() => _isMandatory = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("هل يحتاج إلى تجديد؟"),
                        subtitle: const Text("عند التفعيل: يصبح تاريخ الانتهاء إلزامياً وتعمل التنبيهات وترتيب الأولوية", style: AppTextStyles.caption),
                        value: _requiresRenewal,
                        onChanged: (v) => setState(() => _requiresRenewal = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("مفعَّل"),
                        subtitle: const Text("عند الإيقاف: لا يُقترح لفندق جديد، ويبقى محفوظاً في الفنادق التي تستخدمه", style: AppTextStyles.caption),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _buildLifecycleSection(),
                const SizedBox(height: AppSizes.md),
                _buildScopeSection(),
                const SizedBox(height: AppSizes.xl),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isEditMode ? "حفظ التعديلات" : "إضافة النوع"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: AppSizes.md),
              ],
            ),
    );
  }

  Widget _buildCategorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("الفئة", style: AppTextStyles.bodyBold),
              const Spacer(),
              TextButton.icon(onPressed: _addCategoryInline, icon: const Icon(Icons.add, size: 16), label: const Text("فئة جديدة")),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final isSelected = _selectedCategoryId == c.id;
              return ChoiceChip(
                label: Text(c.name, style: const TextStyle(fontSize: 12)),
                avatar: CircleAvatar(backgroundColor: Color(c.colorValue), radius: 6),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategoryId = c.id),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("المجلد (دورة حياة المستند)", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: DocumentType.lifecyclePermanent, label: Text("دائم"), icon: Icon(Icons.verified_outlined, size: 16)),
              ButtonSegment(value: DocumentType.lifecycleSeasonal, label: Text("موسمي"), icon: Icon(Icons.event_repeat_outlined, size: 16)),
            ],
            selected: {_lifecycle},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _lifecycle = v.first),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("نطاق التطبيق", style: AppTextStyles.bodyBold),
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
            if (_allHotels.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: AppSizes.sm), child: Text("لا توجد فنادق مسجَّلة", style: AppTextStyles.caption))
            else
              ..._allHotels.map((h) => CheckboxListTile(
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
