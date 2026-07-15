import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/document_type.dart';
import '../../repositories/document_type_repository.dart';
import 'add_edit_document_type_page.dart';
import 'document_type_details_page.dart';
import 'manage_document_categories_page.dart';

/// شاشة "أنواع المستندات المرجعية" — المصدر الوحيد لتعريف أنواع المستندات
/// على مستوى التطبيق بالكامل. بحث فوري، عداد، قائمة، إضافة/تفاصيل مستقلة.
class DocumentTypesPage extends StatefulWidget {
  const DocumentTypesPage({super.key});

  @override
  State<DocumentTypesPage> createState() => _DocumentTypesPageState();
}

class _DocumentTypesPageState extends State<DocumentTypesPage> {
  final _repository = DocumentTypeRepository();
  final _searchController = TextEditingController();
  List<DocumentType> _types = [];
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
    final data = await _repository.getTypes();
    setState(() {
      _types = data;
      _isLoading = false;
    });
  }

  List<DocumentType> get _visibleList {
    if (_query.trim().isEmpty) return _types;
    final q = _query.trim();
    return _types.where((t) =>
        t.name.contains(q) ||
        (t.description?.contains(q) ?? false) ||
        (t.categoryName?.contains(q) ?? false)).toList();
  }

  Future<void> _openAdd() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditDocumentTypePage()));
    if (result == true) _loadData();
  }

  Future<void> _openDetails(DocumentType type) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentTypeDetailsPage(documentType: type)));
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final list = _visibleList;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("أنواع المستندات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: "إدارة الفئات",
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageDocumentCategoriesPage()));
              _loadData();
            },
          ),
        ],
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
                      hintText: "بحث بالاسم أو الوصف أو الفئة",
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text("${_types.length} نوع مستند", style: AppTextStyles.caption),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? Center(child: Text(_types.isEmpty ? "لا توجد أنواع مستندات بعد" : "لا توجد نتائج مطابقة", style: AppTextStyles.caption))
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSizes.md),
                          itemCount: list.length,
                          itemBuilder: (context, index) => _buildTile(list[index]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        label: const Text("إضافة نوع مستند"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTile(DocumentType type) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        onTap: () => _openDetails(type),
        title: Row(
          children: [
            Flexible(child: Text(type.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (!type.isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Text("غير مفعَّل", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _tag(type.categoryName ?? '', Color(type.categoryColor ?? 0xFF7A1E2C)),
              if (type.isMandatory) _tag("إلزامي", AppColors.danger),
              if (type.requiresRenewal) _tag("يحتاج تجديد", AppColors.warning),
              _tag(type.isAllHotels ? "كل الفنادق" : "فنادق محددة", AppColors.info),
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
