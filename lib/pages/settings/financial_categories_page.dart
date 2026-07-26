import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/financial_category.dart';
import '../../models/hotel.dart';
import '../../repositories/financial_category_repository.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/hotel_identity_title.dart';

/// شاشة إدارة الفئات المالية الموحَّدة — المكان الوحيد لإنشاء/تعديل/أرشفة
/// فئات المصروفات والإيرادات في التطبيق بالكامل (بتبويبين مستقلين). أي فئة
/// تُضاف هنا تصبح متاحة فوراً في كل شاشة تُنشئ عملية مالية — راجع
/// FinancialCategoryRepository.
class FinancialCategoriesPage extends StatelessWidget {
  final Hotel? hotel;
  const FinancialCategoriesPage({super.key, this.hotel});

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: hotel != null
              ? HotelIdentityTitle(title: "الفئات المالية", hotel: hotel!)
              : const Text("الفئات المالية", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          backgroundColor: identityColor,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "فئات المصروفات"),
              Tab(text: "فئات الإيرادات"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CategoryTypeTab(type: FinancialCategory.typeExpense, identityColor: identityColor),
            _CategoryTypeTab(type: FinancialCategory.typeRevenue, identityColor: identityColor),
          ],
        ),
      ),
    );
  }
}

class _CategoryTypeTab extends StatefulWidget {
  final String type;
  final Color identityColor;
  const _CategoryTypeTab({required this.type, required this.identityColor});

  @override
  State<_CategoryTypeTab> createState() => _CategoryTypeTabState();
}

class _CategoryTypeTabState extends State<_CategoryTypeTab> with AutomaticKeepAliveClientMixin {
  final _repository = FinancialCategoryRepository();
  final _searchController = TextEditingController();
  List<FinancialCategory> _categories = [];
  bool _isLoading = true;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

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
    final data = await _repository.getCategories(type: widget.type, includeArchived: true);
    if (!mounted) return;
    setState(() {
      _categories = data;
      _isLoading = false;
    });
  }

  List<FinancialCategory> get _visibleList {
    if (_query.trim().isEmpty) return _categories;
    final q = _query.trim();
    return _categories.where((c) => c.name.contains(q) || (c.code?.contains(q) ?? false)).toList();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
    await _repository.reorderCategories(_categories);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isSearching = _query.trim().isNotEmpty;
    final list = _visibleList;
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                      hintText: "بحث بالاسم أو الرمز",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _searchController.clear(); _query = ''; })),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text("لا توجد فئات مطابقة", style: AppTextStyles.caption))
                      : isSearching
                          ? ListView.builder(
                              padding: const EdgeInsets.all(AppSizes.md),
                              itemCount: list.length,
                              itemBuilder: (context, index) => _buildTile(list[index], reorderable: false),
                            )
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.all(AppSizes.md),
                              itemCount: list.length,
                              onReorder: _onReorder,
                              itemBuilder: (context, index) => _buildTile(list[index], reorderable: true, key: ValueKey(list[index].id)),
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        label: const Text("إضافة فئة"),
        icon: const Icon(Icons.add),
        backgroundColor: widget.identityColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTile(FinancialCategory category, {required bool reorderable, Key? key}) {
    final color = Color(category.colorValue);
    final parent = category.parentId == null ? null : _categories.where((c) => c.id == category.parentId).firstOrNullSafe;
    return Card(
      key: key ?? ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(IconData(category.iconCode, fontFamily: 'MaterialIcons'), color: color),
        ),
        title: Row(
          children: [
            Flexible(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (category.code != null && category.code!.trim().isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('(${category.code})', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
            ],
            if (category.isDefault) ...[const SizedBox(width: 6), const Icon(Icons.star, size: 16, color: Colors.amber)],
          ],
        ),
        subtitle: Text(
          [
            category.isArchived ? "مؤرشَف" : (category.isBasic ? "أساسي" : "مضاف"),
            if (parent != null) "ضمن: ${parent.name}",
            if (category.description != null && category.description!.trim().isNotEmpty) category.description!,
          ].join(' • '),
          style: TextStyle(fontSize: 12, color: category.isArchived ? Colors.grey : Theme.of(context).colorScheme.secondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(category.isDefault ? Icons.star : Icons.star_border, color: category.isDefault ? Colors.amber : Colors.grey),
              tooltip: "تعيين كافتراضي",
              onPressed: () => _setDefault(category),
            ),
            IconButton(
              icon: Icon(category.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, color: category.isArchived ? Colors.green : Colors.blueGrey),
              tooltip: category.isArchived ? "استعادة" : "أرشفة",
              onPressed: () => _toggleArchive(category),
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.orange), onPressed: () => _openEdit(category)),
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _delete(category)),
            if (reorderable) const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _setDefault(FinancialCategory category) async {
    if (category.isDefault) return;
    await _repository.setDefaultCategory(category.id!, widget.type);
    _loadData();
  }

  Future<void> _toggleArchive(FinancialCategory category) async {
    await AppDialog.confirmAction(
      context: context,
      title: category.isArchived ? "استعادة الفئة" : "أرشفة الفئة",
      message: category.isArchived
          ? "ستعود \"${category.name}\" فوراً لكل شاشات اختيار الفئة."
          : "ستختفي \"${category.name}\" من كل شاشات اختيار الفئة، وتبقى مرتبطة بأي عملية سابقة استخدمتها.",
      confirmLabel: category.isArchived ? "استعادة" : "أرشفة",
      onConfirm: () async {
        if (category.isArchived) {
          await _repository.restoreCategory(category.id!);
        } else {
          await _repository.archiveCategory(category.id!);
        }
        _loadData();
      },
    );
  }

  Future<void> _delete(FinancialCategory category) async {
    final inUse = await _repository.isCategoryInUse(category);
    if (inUse) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text("لا يمكن حذف هذه الفئة"),
          content: Text("\"${category.name}\" مستخدَمة فعلياً في عمليات مالية سابقة، فلا يمكن حذفها نهائياً حفاظاً على سلامة البيانات التاريخية. استخدم \"أرشفة\" بدلاً من ذلك."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق")),
            ElevatedButton(onPressed: () { Navigator.pop(context); _toggleArchive(category); }, child: const Text("أرشفة بدلاً من الحذف")),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: "حذف نهائي",
      message: "لم تُستخدَم \"${category.name}\" في أي عملية مالية بعد، فسيُحذف السجل نهائياً بلا رجعة. هل تريد المتابعة؟",
      confirmLabel: "حذف نهائي",
      isDangerous: true,
      onConfirm: () async {
        await _repository.deleteCategory(category.id!);
        _loadData();
      },
    );
  }

  /// عند التعديل: يتحقق أولاً هل الفئة مستخدَمة فعلياً — إن كانت، يُمنَع تعديل
  /// الرمز المختصر (Category Code) في النموذج (النوع أصلاً ثابت بحكم التبويب
  /// نفسه). الاسم/الترتيب/الأيقونة/اللون/الوصف تبقى قابلة للتعديل دائماً.
  Future<void> _openEdit(FinancialCategory category) async {
    final inUse = await _repository.isCategoryInUse(category);
    if (!mounted) return;
    _showFormDialog(category: category, codeLocked: inUse);
  }

  void _showFormDialog({FinancialCategory? category, bool codeLocked = false}) {
    String name = category?.name ?? "";
    String code = category?.code ?? "";
    String description = category?.description ?? "";
    int selectedColor = category?.colorValue ?? 0xFF4CAF50;
    int selectedIcon = category?.iconCode ?? 0xe4f4;
    int? selectedParentId = category?.parentId;
    String? errorText;

    const availableColors = [
      0xFF4CAF50, 0xFFFFC107, 0xFF2196F3, 0xFFFF9800,
      0xFF9C27B0, 0xFFF44336, 0xFF607D8B, 0xFF795548,
      0xFF009688, 0xFFE91E63, 0xFF3F51B5, 0xFF455A64,
    ];
    const availableIcons = [
      0xe4f4, 0xe098, 0xe6e4, 0xe1bd, 0xe69a, 0xe317,
      0xe3f1, 0xe570, 0xe59c, 0xe0bc, 0xe0cd, 0xe190,
      0xe8b8, 0xe55b, 0xe5d3, 0xe7e9, 0xef62, 0xeb41,
      0xe532, 0xe30c, 0xe227, 0xe318,
    ];
    final parentOptions = _categories.where((c) => c.id != category?.id).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text(category == null ? "إضافة فئة جديدة" : "تعديل الفئة"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: "اسم الفئة", errorText: errorText),
                  controller: TextEditingController(text: name)..selection = TextSelection.collapsed(offset: name.length),
                  onChanged: (v) { name = v; if (errorText != null) setDialogState(() => errorText = null); },
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: !codeLocked,
                  decoration: InputDecoration(
                    labelText: "رمز مختصر (اختياري)",
                    helperText: codeLocked ? "لا يمكن تغيير الرمز بعد استخدام الفئة في عملية مالية" : null,
                  ),
                  controller: TextEditingController(text: code)..selection = TextSelection.collapsed(offset: code.length),
                  onChanged: (v) => code = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: "وصف (اختياري)"),
                  maxLines: 2,
                  controller: TextEditingController(text: description)..selection = TextSelection.collapsed(offset: description.length),
                  onChanged: (v) => description = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: selectedParentId,
                  decoration: const InputDecoration(labelText: "فئة أصل (اختياري، جاهز للمستقبل)"),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text("بلا فئة أصل")),
                    for (final p in parentOptions) DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setDialogState(() => selectedParentId = v),
                ),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerRight, child: Text("اللون:")),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableColors.map((c) => InkWell(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: selectedColor == c ? Border.all(color: Colors.black, width: 2) : null),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerRight, child: Text("الأيقونة:")),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableIcons.map((icon) => InkWell(
                    onTap: () => setDialogState(() => selectedIcon = icon),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: selectedIcon == icon ? Color(selectedColor).withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
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

                final existing = await _repository.getCategoryByName(trimmedName, widget.type, excludeId: category?.id);
                if (existing != null) {
                  setDialogState(() => errorText = "هذا الاسم مستخدم لفئة أخرى من نفس النوع بالفعل");
                  return;
                }

                Navigator.pop(context);
                if (!mounted) return;
                await AppDialog.confirmAction(
                  context: this.context,
                  title: category == null ? "تأكيد الإضافة" : "تأكيد الحفظ",
                  message: category == null ? "هل تريد إضافة هذه الفئة؟" : "هل تريد حفظ التعديلات؟ سيظهر الاسم الجديد فوراً في كل مكان بالتطبيق ولن يُغيَّر أي سجل قديم مرتبط بهذه الفئة.",
                  onConfirm: () async {
                    if (category == null) {
                      final newCat = FinancialCategory(
                        name: trimmedName,
                        type: widget.type,
                        code: code.trim().isEmpty ? null : code.trim(),
                        description: description.trim().isEmpty ? null : description.trim(),
                        parentId: selectedParentId,
                        iconCode: selectedIcon,
                        colorValue: selectedColor,
                        createdAt: DateTime.now().toIso8601String(),
                        sortOrder: _categories.length,
                      );
                      await _repository.addCategory(newCat);
                    } else {
                      await _repository.updateCategory(category.copyWith(
                        name: trimmedName,
                        code: code.trim().isEmpty ? null : code.trim(),
                        description: description.trim().isEmpty ? null : description.trim(),
                        parentId: selectedParentId,
                        clearParentId: selectedParentId == null,
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

extension _FirstOrNullSafe<T> on Iterable<T> {
  T? get firstOrNullSafe => isEmpty ? null : first;
}
