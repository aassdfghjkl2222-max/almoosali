import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/financial_report_item.dart';
import '../../models/hotel.dart';
import '../../repositories/financial_report_item_repository.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/hotel_identity_title.dart';

/// "إدارة البنود" — الكتالوج الموحّد للبنود الدائمة (إيراد/مصروف) القابلة
/// لإعادة الاستخدام داخل أي تقرير مالي يومي لاحق. نسخة مبسّطة من
/// ManageCategoriesPage (بحث، إعادة ترتيب، إظهار/إخفاء، حذف مباشر — بلا
/// فحص "قيد الاستخدام" لأن التقارير القديمة تحتفظ بنسخة كاملة داخل
/// details_json ولا ترتبط بهذا الجدول عبر مفتاح خارجي إطلاقاً).
class ManageReportItemsPage extends StatefulWidget {
  final Hotel? hotel;
  const ManageReportItemsPage({super.key, this.hotel});

  @override
  State<ManageReportItemsPage> createState() => _ManageReportItemsPageState();
}

class _ManageReportItemsPageState extends State<ManageReportItemsPage> {
  final _repository = FinancialReportItemRepository();
  final _searchController = TextEditingController();

  String _type = FinancialReportItem.typeRevenue;
  List<FinancialReportItem> _items = [];
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
    setState(() => _isLoading = true);
    final data = await _repository.getItems(type: _type, includeHidden: true);
    setState(() {
      _items = data;
      _isLoading = false;
    });
  }

  List<FinancialReportItem> get _visibleList {
    if (_query.trim().isEmpty) return _items;
    final q = _query.trim();
    return _items.where((i) => i.name.contains(q)).toList();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    await _repository.updateItemsOrder(_items);
  }

  void _toggleVisibility(FinancialReportItem item) async {
    await _repository.updateItem(item.copyWith(isVisible: !item.isVisible));
    _loadData();
  }

  Future<void> _deleteItem(FinancialReportItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف بند \"${item.name}\"؟ التقارير المحفوظة سابقاً التي استخدمته لن تتأثر."),
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
      await _repository.deleteItem(item.id!);
      _loadData();
    }
  }

  void _showItemFormDialog({FinancialReportItem? item}) {
    String name = item?.name ?? "";
    String fundingSource = item?.defaultFundingSource ?? "نقد";
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text(item == null ? "إضافة بند جديد" : "تعديل البند"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: "اسم البند", errorText: errorText),
                  controller: TextEditingController(text: name)..selection = TextSelection.collapsed(offset: name.length),
                  onChanged: (v) {
                    name = v;
                    if (errorText != null) setDialogState(() => errorText = null);
                  },
                ),
                if (_type == FinancialReportItem.typeRevenue) ...[
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerRight, child: Text("مصدر التمويل الافتراضي:")),
                  Wrap(
                    spacing: 8,
                    children: ["نقد", "شبكة", "تحويل بنكي"].map((s) => ChoiceChip(
                          label: Text(s),
                          selected: fundingSource == s,
                          onSelected: (_) => setDialogState(() => fundingSource = s),
                        )).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                final trimmedName = name.trim();
                if (trimmedName.isEmpty) return;

                final existing = await _repository.getItemByName(trimmedName, _type);
                if (existing != null && existing.id != item?.id) {
                  setDialogState(() => errorText = "هذا الاسم مستخدم لبند آخر من نفس النوع بالفعل");
                  return;
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                await AppDialog.confirmAction(
                  context: this.context,
                  title: item == null ? "تأكيد الإضافة" : "تأكيد الحفظ",
                  message: item == null ? "هل تريد إضافة هذا البند؟" : "هل تريد حفظ التعديلات على هذا البند؟",
                  onConfirm: () async {
                    if (item == null) {
                      await _repository.addItem(FinancialReportItem(
                        name: trimmedName,
                        type: _type,
                        defaultFundingSource: _type == FinancialReportItem.typeRevenue ? fundingSource : null,
                        sortOrder: _items.length,
                        createdAt: DateTime.now().toIso8601String(),
                      ));
                    } else {
                      await _repository.updateItem(item.copyWith(
                        name: trimmedName,
                        defaultFundingSource: _type == FinancialReportItem.typeRevenue ? fundingSource : null,
                      ));
                    }
                    _loadData();
                  },
                );
              },
              child: Text(item == null ? "إضافة" : "حفظ"),
            ),
          ],
        ),
      ),
    );
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
            ? HotelIdentityTitle(title: "إدارة البنود", hotel: widget.hotel!)
            : const Text("إدارة البنود", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: FinancialReportItem.typeRevenue, label: Text("بنود الإيراد"), icon: Icon(Icons.trending_up)),
                ButtonSegment(value: FinancialReportItem.typeExpense, label: Text("بنود المصروف"), icon: Icon(Icons.trending_down)),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() => _type = s.first);
                _loadData();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.sm),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: "بحث عن بند بالاسم",
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(child: Text("لا توجد بنود مطابقة"))
                    : isSearching
                        ? ListView.builder(
                            padding: const EdgeInsets.all(AppSizes.md),
                            itemCount: list.length,
                            itemBuilder: (context, index) => _buildItemTile(list[index], reorderable: false),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.all(AppSizes.md),
                            itemCount: list.length,
                            onReorder: _onReorder,
                            itemBuilder: (context, index) => _buildItemTile(list[index], reorderable: true, key: ValueKey(list[index].id)),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemFormDialog(),
        label: const Text("إضافة بند جديد"),
        icon: const Icon(Icons.add),
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildItemTile(FinancialReportItem item, {required bool reorderable, Key? key}) {
    return Card(
      key: key ?? ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Icon(item.type == FinancialReportItem.typeRevenue ? Icons.trending_up : Icons.trending_down, color: item.type == FinancialReportItem.typeRevenue ? Colors.green : Colors.red),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          !item.isVisible ? "مخفي" : (item.defaultFundingSource ?? "مضاف"),
          style: TextStyle(fontSize: 12, color: !item.isVisible ? Colors.grey : Theme.of(context).colorScheme.secondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(item.isVisible ? Icons.visibility : Icons.visibility_off, color: item.isVisible ? Colors.blue : Colors.grey),
              tooltip: item.isVisible ? "تعطيل" : "إعادة تفعيل",
              onPressed: () => _toggleVisibility(item),
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.orange), onPressed: () => _showItemFormDialog(item: item)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteItem(item)),
            if (reorderable) const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
