import 'package:flutter/material.dart';
import '../../core/app_sizes.dart';
import '../../core/app_radius.dart';
import '../../models/expense_category.dart';
import '../../models/hotel.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../core/hotel_visual_identity.dart';

/// إدارة تصنيفات المصروفات — قاعدة بيانات واحدة موحّدة على مستوى التطبيق
/// بالكامل (وليست خاصة بفندق [hotel]؛ هو اختياري ويُستخدم فقط لتلوين هذه
/// الشاشة بهوية الفندق عند فتحها من داخل لوحة تحكمه — تُفتح أيضاً من قسم
/// "البيانات المرجعية" العام بلا أي فندق). أي تصنيف يُضاف هنا يصبح متاحاً
/// فوراً في كل الفنادق: الفواتير الضريبية، المصروفات المعلقة، مركز
/// التحليل، المركز المالي، التقارير.
class ManageCategoriesPage extends StatefulWidget {
  final Hotel? hotel;
  const ManageCategoriesPage({super.key, this.hotel});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final _repository = ExpenseRepository();
  final _searchController = TextEditingController();
  List<ExpenseCategory> _categories = [];
  bool _isLoading = true;
  String _query = '';

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
    final data = await _repository.getCategories(includeHidden: true);
    setState(() {
      _categories = data;
      _isLoading = false;
    });
  }

  List<ExpenseCategory> get _visibleList {
    if (_query.trim().isEmpty) return _categories;
    final q = _query.trim();
    return _categories.where((c) => c.name.contains(q) || (c.shortCode?.contains(q) ?? false)).toList();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
    await _repository.updateCategoriesOrder(_categories);
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    final isSearching = _query.trim().isNotEmpty;
    final list = _visibleList;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: widget.hotel != null
            ? HotelIdentityTitle(title: "إدارة تصنيفات المصروفات", hotel: widget.hotel!)
            : const Text("إدارة تصنيفات المصروفات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: identityColor,
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
                      hintText: "بحث عن تصنيف بالاسم أو الرمز المختصر",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _query = '';
                              }),
                            ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text("لا توجد تصنيفات مطابقة"))
                      : isSearching
                          ? ListView.builder(
                              padding: const EdgeInsets.all(AppSizes.md),
                              itemCount: list.length,
                              itemBuilder: (context, index) => _buildCategoryTile(list[index], reorderable: false),
                            )
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.all(AppSizes.md),
                              itemCount: list.length,
                              onReorder: _onReorder,
                              itemBuilder: (context, index) => _buildCategoryTile(list[index], reorderable: true, key: ValueKey(list[index].id)),
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(),
        label: const Text("إضافة تصنيف جديد"),
        icon: const Icon(Icons.add),
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryTile(ExpenseCategory category, {required bool reorderable, Key? key}) {
    final color = Color(category.colorValue);
    return Card(
      key: key ?? ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            IconData(category.iconCode, fontFamily: 'MaterialIcons'),
            color: color,
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (category.shortCode != null && category.shortCode!.trim().isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('(${category.shortCode})', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
            ],
            if (category.isDefault) ...[
              const SizedBox(width: 6),
              const Icon(Icons.star, size: 16, color: Colors.amber),
            ],
          ],
        ),
        subtitle: Text(
          !category.isVisible ? "مخفي" : (category.isBasic ? "أساسي" : "مضاف"),
          style: TextStyle(fontSize: 12, color: !category.isVisible ? Colors.grey : (category.isBasic ? Colors.grey : Theme.of(context).colorScheme.secondary)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(category.isDefault ? Icons.star : Icons.star_border, color: category.isDefault ? Colors.amber : Colors.grey),
              tooltip: "تعيين كتصنيف افتراضي",
              onPressed: () => _setDefault(category),
            ),
            IconButton(
              icon: Icon(
                category.isVisible ? Icons.visibility : Icons.visibility_off,
                color: category.isVisible ? Colors.blue : Colors.grey,
              ),
              tooltip: category.isVisible ? "إخفاء" : "إظهار",
              onPressed: () => _toggleVisibility(category),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.orange),
              onPressed: () => _showEditCategoryDialog(category),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteCategory(category),
            ),
            if (reorderable) const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _setDefault(ExpenseCategory category) async {
    if (category.isDefault) return;
    await _repository.setDefaultCategory(category.id!);
    _loadData();
  }

  void _toggleVisibility(ExpenseCategory category) async {
    await _repository.updateCategory(category.copyWith(isVisible: !category.isVisible));
    _loadData();
  }

  void _deleteCategory(ExpenseCategory category) async {
    final inUse = await _repository.isCategoryInUse(category.id!, category.name);

    if (inUse) {
      if (!mounted) return;
      final hideInstead = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("لا يمكن حذف هذا التصنيف"),
          content: Text("التصنيف '${category.name}' مستخدم فعلياً في مصروفات معلقة أو فواتير ضريبية، لذلك لا يمكن حذفه نهائياً حفاظاً على سلامة البيانات القديمة. يمكنك إخفاؤه بدلاً من ذلك حتى لا يظهر عند اختيار تصنيف جديد."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("إخفاء التصنيف")),
          ],
        ),
      );
      if (hideInstead == true) {
        await _repository.updateCategory(category.copyWith(isVisible: false));
        _loadData();
      }
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف التصنيف '${category.name}' نهائياً؟"),
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

  void _showAddCategoryDialog() {
    _showCategoryFormDialog();
  }

  void _showEditCategoryDialog(ExpenseCategory category) {
    _showCategoryFormDialog(category: category);
  }

  void _showCategoryFormDialog({ExpenseCategory? category}) {
    String name = category?.name ?? "";
    String shortCode = category?.shortCode ?? "";
    int selectedColor = category?.colorValue ?? 0xFF4CAF50;
    int selectedIcon = category?.iconCode ?? 0xe4f4;
    String? errorText;

    final List<int> availableColors = [
      0xFF4CAF50, 0xFFFFC107, 0xFF2196F3, 0xFFFF9800,
      0xFF9C27B0, 0xFFF44336, 0xFF607D8B, 0xFF795548,
      0xFF009688, 0xFFE91E63, 0xFF3F51B5, 0xFF455A64,
    ];

    final List<int> availableIcons = [
      0xe4f4, 0xe098, 0xe6e4, 0xe1bd, 0xe69a, 0xe317,
      0xe3f1, 0xe570, 0xe59c, 0xe0bc, 0xe0cd, 0xe190,
      0xe8b8, 0xe55b, 0xe5d3, 0xe7e9, 0xef62, 0xeb41,
      0xe532, 0xe30c,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? "إضافة تصنيف جديد" : "تعديل التصنيف"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: "اسم التصنيف", errorText: errorText),
                  controller: TextEditingController(text: name)..selection = TextSelection.collapsed(offset: name.length),
                  onChanged: (v) {
                    name = v;
                    if (errorText != null) setDialogState(() => errorText = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: "رمز مختصر (اختياري)"),
                  controller: TextEditingController(text: shortCode)..selection = TextSelection.collapsed(offset: shortCode.length),
                  onChanged: (v) => shortCode = v,
                ),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerRight, child: Text("اختر لوناً (اختياري):")),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableColors.map((c) => InkWell(
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
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerRight, child: Text("اختر أيقونة (اختياري):")),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableIcons.map((icon) => InkWell(
                    onTap: () => setDialogState(() => selectedIcon = icon),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == icon ? Color(selectedColor).withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(IconData(icon, fontFamily: 'MaterialIcons'), color: Color(selectedColor)),
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
                  setDialogState(() => errorText = "هذا الاسم مستخدم لتصنيف آخر بالفعل");
                  return;
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                await AppDialog.confirmAction(
                  context: this.context,
                  title: category == null ? "تأكيد الإضافة" : "تأكيد الحفظ",
                  message: category == null ? "هل تريد إضافة هذا التصنيف؟" : "هل تريد حفظ التعديلات على هذا التصنيف؟ سيظهر الاسم الجديد فوراً في كل الفنادق ولن يُغيَّر أي سجل قديم مرتبط به.",
                  onConfirm: () async {
                    if (category == null) {
                      final newCat = ExpenseCategory(
                        name: trimmedName,
                        shortCode: shortCode.trim().isEmpty ? null : shortCode.trim(),
                        iconCode: selectedIcon,
                        colorValue: selectedColor,
                        createdAt: DateTime.now().toIso8601String(),
                        sortOrder: _categories.length,
                      );
                      await _repository.addCategory(newCat);
                    } else {
                      await _repository.updateCategory(category.copyWith(
                        name: trimmedName,
                        shortCode: shortCode.trim().isEmpty ? null : shortCode.trim(),
                        iconCode: selectedIcon,
                        colorValue: selectedColor,
                      ));
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
