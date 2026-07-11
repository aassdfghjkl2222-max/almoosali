import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_radius.dart';
import '../../models/expense_category.dart';
import '../../models/hotel.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../core/hotel_visual_identity.dart';

class ManageCategoriesPage extends StatefulWidget {
  final Hotel hotel;
  const ManageCategoriesPage({super.key, required this.hotel});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final _repository = ExpenseRepository();
  List<ExpenseCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _repository.getCategories(widget.hotel.id!);
    setState(() {
      _categories = data;
      _isLoading = false;
    });
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "إدارة أنواع المصروفات", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: _categories.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _buildCategoryTile(category, index);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(),
        label: const Text("إضافة نوع جديد"),
        icon: const Icon(Icons.add),
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryTile(ExpenseCategory category, int index) {
    final color = Color(category.colorValue);
    return Card(
      key: ValueKey(category.id),
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
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          category.isBasic ? "أساسي" : "مضاف",
          style: TextStyle(fontSize: 12, color: category.isBasic ? Colors.grey : Theme.of(context).colorScheme.secondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                category.isVisible ? Icons.visibility : Icons.visibility_off,
                color: category.isVisible ? Colors.blue : Colors.grey,
              ),
              onPressed: () => _toggleVisibility(category),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.orange),
              onPressed: () => _showEditCategoryDialog(category),
            ),
            if (!category.isBasic)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteCategory(category),
              ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _toggleVisibility(ExpenseCategory category) async {
    await _repository.updateCategory(category.copyWith(isVisible: !category.isVisible));
    _loadData();
  }

  void _deleteCategory(ExpenseCategory category) async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف النوع '${category.name}'؟"),
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
    int selectedColor = category?.colorValue ?? 0xFF4CAF50;
    int selectedIcon = category?.iconCode ?? 0xe4f4;

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
          title: Text(category == null ? "إضافة نوع جديد" : "تعديل النوع"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: "اسم النوع"),
                  controller: TextEditingController(text: name)..selection = TextSelection.collapsed(offset: name.length),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 16),
                const Text("اختر لوناً:"),
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
                const Text("اختر أيقونة:"),
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
                if (name.trim().isEmpty) return;
                Navigator.pop(context);
                await AppDialog.confirmAction(
                  context: this.context,
                  title: category == null ? "تأكيد الإضافة" : "تأكيد الحفظ",
                  message: category == null ? "هل تريد إضافة هذا النوع؟" : "هل تريد حفظ التعديلات على هذا النوع؟",
                  onConfirm: () async {
                    if (category == null) {
                      final newCat = ExpenseCategory(
                        hotelId: widget.hotel.id!,
                        name: name.trim(),
                        iconCode: selectedIcon,
                        colorValue: selectedColor,
                        createdAt: DateTime.now().toIso8601String(),
                        sortOrder: _categories.length,
                      );
                      await _repository.addCategory(newCat);
                    } else {
                      await _repository.updateCategory(category.copyWith(
                        name: name.trim(),
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
