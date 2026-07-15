import 'package:flutter/material.dart';
import '../../core/app_sizes.dart';
import '../../core/app_radius.dart';
import '../../models/document_category.dart';
import '../../repositories/document_type_repository.dart';
import '../../widgets/common/app_dialog.dart';

/// إدارة فئات أنواع المستندات المرجعية — قاعدة موحّدة على مستوى التطبيق
/// بالكامل، تُستخدم كحقل "الفئة" عند إضافة/تعديل نوع مستند.
class ManageDocumentCategoriesPage extends StatefulWidget {
  const ManageDocumentCategoriesPage({super.key});

  @override
  State<ManageDocumentCategoriesPage> createState() => _ManageDocumentCategoriesPageState();
}

class _ManageDocumentCategoriesPageState extends State<ManageDocumentCategoriesPage> {
  final _repository = DocumentTypeRepository();
  final _searchController = TextEditingController();
  List<DocumentCategory> _categories = [];
  bool _isLoading = true;
  String _query = '';

  static const List<int> _availableColors = [
    0xFF4CAF50, 0xFFFFC107, 0xFF2196F3, 0xFFFF9800,
    0xFF9C27B0, 0xFFF44336, 0xFF607D8B, 0xFF795548,
    0xFF009688, 0xFFE91E63, 0xFF3F51B5, 0xFF455A64,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await _repository.getCategories();
    setState(() {
      _categories = data;
      _isLoading = false;
    });
  }

  List<DocumentCategory> get _visibleList {
    if (_query.trim().isEmpty) return _categories;
    final q = _query.trim();
    return _categories.where((c) => c.name.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _visibleList;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إدارة فئات المستندات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: "بحث عن فئة",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text("لا توجد فئات مطابقة"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSizes.md),
                          itemCount: list.length,
                          itemBuilder: (context, index) => _buildTile(list[index]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        label: const Text("فئة جديدة"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTile(DocumentCategory category) {
    final color = Color(category.colorValue);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.orange), onPressed: () => _showFormDialog(category: category)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteCategory(category)),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(DocumentCategory category) async {
    final inUse = await _repository.isCategoryInUse(category.id!);
    if (inUse) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("لا يمكن حذف هذه الفئة"),
          content: Text("الفئة '${category.name}' مستخدمة في نوع مستند مرجعي واحد على الأقل، لذلك لا يمكن حذفها حفاظاً على سلامة البيانات."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))],
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف الفئة '${category.name}'؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("حذف"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repository.deleteCategory(category.id!);
      _loadData();
    }
  }

  void _showFormDialog({DocumentCategory? category}) {
    String name = category?.name ?? "";
    int selectedColor = category?.colorValue ?? _availableColors.first;
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? "فئة جديدة" : "تعديل الفئة"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: "اسم الفئة", errorText: errorText),
                  controller: TextEditingController(text: name)..selection = TextSelection.collapsed(offset: name.length),
                  onChanged: (v) {
                    name = v;
                    if (errorText != null) setDialogState(() => errorText = null);
                  },
                ),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerRight, child: Text("اختر لوناً:")),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableColors.map((c) => InkWell(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selectedColor == c ? Border.all(color: Colors.black, width: 2) : null,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                final trimmedName = name.trim();
                if (trimmedName.isEmpty) return;

                final existing = await _repository.getCategoryByName(trimmedName);
                if (existing != null && existing.id != category?.id) {
                  setDialogState(() => errorText = "هذا الاسم مستخدم لفئة أخرى بالفعل");
                  return;
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                await AppDialog.confirmAction(
                  context: this.context,
                  title: category == null ? "تأكيد الإضافة" : "تأكيد الحفظ",
                  message: category == null ? "هل تريد إضافة هذه الفئة؟" : "هل تريد حفظ التعديلات على هذه الفئة؟",
                  onConfirm: () async {
                    if (category == null) {
                      await _repository.addCategory(DocumentCategory(
                        name: trimmedName,
                        colorValue: selectedColor,
                        createdAt: DateTime.now().toIso8601String(),
                      ));
                    } else {
                      await _repository.updateCategory(category.copyWith(name: trimmedName, colorValue: selectedColor));
                    }
                    _loadData();
                  },
                );
              },
              child: Text(category == null ? "إضافة" : "حفظ"),
            ),
          ],
        ),
      ),
    );
  }
}
