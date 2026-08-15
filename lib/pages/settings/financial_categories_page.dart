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
import 'financial_category_display_preferences_page.dart';

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
          actions: [
            IconButton(
              tooltip: "تفضيلات العرض",
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialCategoryDisplayPreferencesPage())),
            ),
          ],
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
  bool _isReorderMode = false;

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
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          enabled: !_isReorderMode,
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
                      if (!isSearching || _isReorderMode) ...[
                        const SizedBox(width: 8),
                        _buildReorderToggle(),
                      ],
                    ],
                  ),
                ),
                if (_isReorderMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text("اسحب مقبض الترتيب لإعادة ترتيب الفئات — يُحفَظ الترتيب تلقائياً", style: AppTextStyles.caption),
                    ),
                  ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text("لا توجد فئات مطابقة", style: AppTextStyles.caption))
                      : _isReorderMode
                          ? ReorderableListView.builder(
                              padding: const EdgeInsets.all(AppSizes.md),
                              itemCount: list.length,
                              onReorder: _onReorder,
                              itemBuilder: (context, index) => _buildTile(list[index], index: index, key: ValueKey(list[index].id)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppSizes.md),
                              itemCount: list.length,
                              itemBuilder: (context, index) => _buildTile(list[index], index: index),
                            ),
                ),
              ],
            ),
      floatingActionButton: _isReorderMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showFormDialog(),
              label: const Text("إضافة فئة"),
              icon: const Icon(Icons.add),
              backgroundColor: widget.identityColor,
              foregroundColor: Colors.white,
            ),
    );
  }

  /// يبدّل "وضع الترتيب" — عند تفعيله تظهر مقابض السحب على كل الفئات
  /// (بلا بحث نشط، والحفظ فوري بعد كل سحبة عبر [_onReorder])، وعند إيقافه
  /// تعود الشاشة لمظهرها النظيف المعتاد ببساطة زر "المزيد" لكل فئة.
  Widget _buildReorderToggle() {
    return IconButton(
      tooltip: _isReorderMode ? "إنهاء الترتيب" : "ترتيب الفئات",
      style: IconButton.styleFrom(
        backgroundColor: _isReorderMode ? widget.identityColor : Colors.white,
        side: BorderSide(color: widget.identityColor.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      icon: Icon(_isReorderMode ? Icons.check : Icons.swap_vert, color: _isReorderMode ? Colors.white : widget.identityColor),
      onPressed: () => setState(() => _isReorderMode = !_isReorderMode),
    );
  }

  /// صف فئة نظيف بالحد الأدنى من العناصر (أيقونة/اسم/حالة/مؤشر مفضّلة
  /// اختياري) — كل إجراءات الإدارة (تعديل/أرشفة/مفضّلة/افتراضي/حذف/إحصائيات)
  /// انتقلت إلى قائمة "المزيد" الموحّدة ([_showActionsSheet]) بدل عرض خمسة
  /// أزرار ملوّنة دائماً على كل صف. مقبض السحب لا يظهر إلا في وضع الترتيب.
  Widget _buildTile(FinancialCategory category, {required int index, Key? key}) {
    final color = Color(category.colorValue);
    final parent = category.parentId == null ? null : _categories.where((c) => c.id == category.parentId).firstOrNullSafe;
    return Card(
      key: key ?? ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onLongPress: _isReorderMode ? null : () => _showActionsSheet(category),
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
              if (category.isPinned) ...[const SizedBox(width: 6), const Icon(Icons.star, size: 15, color: Colors.amber)],
            ],
          ),
          subtitle: Text(
            [
              category.isArchived ? "مؤرشَف" : (category.isBasic ? "أساسي" : "مضاف"),
              if (category.isDefault) "افتراضي",
              if (parent != null) "ضمن: ${parent.name}",
              if (category.createdBy != null && category.createdBy!.trim().isNotEmpty) "بواسطة: ${category.createdBy}",
              if (category.description != null && category.description!.trim().isNotEmpty) category.description!,
            ].join(' • '),
            style: TextStyle(fontSize: 12, color: category.isArchived ? Colors.grey : Theme.of(context).colorScheme.secondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _isReorderMode
              ? ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle, color: Colors.grey))
              : IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: "المزيد",
                  onPressed: () => _showActionsSheet(category),
                ),
        ),
      ),
    );
  }

  /// قائمة إجراءات موحّدة لفئة واحدة (Bottom Sheet) — تُفتح من زر "⋮ المزيد"
  /// أو من الضغط المطوَّل على الصف. فحص الاستخدام يتم مرة واحدة هنا عند
  /// الفتح (وليس لكل صف مرئي) لتعطيل خيار الحذف مباشرة مع رسالة توضيحية،
  /// بدل تركه يفتح حواراً منفصلاً بعد الضغط.
  Future<void> _showActionsSheet(FinancialCategory category) async {
    final inUse = await _repository.isCategoryInUse(category);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Color(category.colorValue).withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(IconData(category.iconCode, fontFamily: 'MaterialIcons'), color: Color(category.colorValue)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(category.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.orange),
              title: const Text("تعديل الفئة"),
              onTap: () { Navigator.pop(sheetContext); _openEdit(category); },
            ),
            ListTile(
              leading: Icon(category.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, color: category.isArchived ? Colors.green : Colors.blueGrey),
              title: Text(category.isArchived ? "استعادة الفئة" : "أرشفة الفئة"),
              onTap: () { Navigator.pop(sheetContext); _toggleArchive(category); },
            ),
            ListTile(
              leading: Icon(category.isPinned ? Icons.star : Icons.star_border, color: Colors.amber),
              title: Text(category.isPinned ? "إزالة من المفضلة" : "إضافة للمفضلة"),
              onTap: () { Navigator.pop(sheetContext); _togglePinned(category); },
            ),
            ListTile(
              enabled: !category.isDefault,
              leading: const Icon(Icons.push_pin_outlined, color: Colors.blueGrey),
              title: Text(category.isDefault ? "الفئة الافتراضية الحالية" : "تعيين كافتراضي"),
              subtitle: category.isDefault ? null : const Text("تُستخدم كاختيار مسبق عند إضافة فاتورة ضريبية", style: AppTextStyles.caption),
              onTap: () { Navigator.pop(sheetContext); _setDefault(category); },
            ),
            ListTile(
              enabled: !inUse,
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text("حذف الفئة", style: TextStyle(color: AppColors.danger)),
              subtitle: inUse ? const Text("مستخدَمة في عمليات مالية سابقة — استخدم الأرشفة بدلاً من ذلك", style: AppTextStyles.caption) : null,
              onTap: inUse ? null : () { Navigator.pop(sheetContext); _delete(category); },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined, color: Colors.indigo),
              title: const Text("عرض إحصائيات الاستخدام"),
              onTap: () { Navigator.pop(sheetContext); _showUsageStats(category); },
            ),
            const SizedBox(height: AppSizes.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePinned(FinancialCategory category) async {
    await _repository.updateCategory(category.copyWith(isPinned: !category.isPinned));
    _loadData();
  }

  void _showUsageStats(FinancialCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text("إحصائيات: ${category.name}"),
        content: Text("عدد مرات الاستخدام في عمليات مالية حتى الآن: ${category.usageCount}"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق"))],
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

                final likelyDuplicate = await _repository.findLikelyDuplicate(trimmedName, widget.type, excludeId: category?.id);
                if (!mounted) return;
                if (likelyDuplicate != null) {
                  bool proceedAnyway = false;
                  await AppDialog.confirmAction(
                    context: context,
                    title: "تشابه مع فئة موجودة",
                    message: "\"$trimmedName\" يشبه إلى حد كبير الفئة الموجودة \"${likelyDuplicate.name}\" — قد يمثّلان نفس الغرض المالي. تأكد أنهما فئتان مختلفتان فعلاً قبل المتابعة.",
                    confirmLabel: "متابعة كفئة مختلفة",
                    cancelLabel: "إلغاء",
                    onConfirm: () async => proceedAnyway = true,
                  );
                  if (!proceedAnyway) return;
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
                        createdBy: "مدير النظام",
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
