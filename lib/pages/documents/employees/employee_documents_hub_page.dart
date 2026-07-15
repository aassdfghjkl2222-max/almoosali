import 'package:flutter/material.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/document.dart';
import '../../../models/document_type.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/document_type_repository.dart';
import '../shared/add_edit_document_folder_page.dart';
import '../shared/folder_detail_page.dart';

/// "مستندات الموظفين" — قائمة "المجلدات" الحرة غير المقيّدة بأسماء ثابتة
/// (مثل: الهوية، الإقامة، عقد العمل، الشهادات...)، بعدد غير محدود. كل مجلد
/// نوع مستند مرجعي بدورة حياة [DocumentType.lifecycleEmployee]، يحفظ مراجع
/// فقط لمستندات محرك المستندات الموحّد بالمالك 'employee' (بلا أي نسخ) —
/// نفس بنية "المستندات الموسمية" حرفياً عبر الصفحات المشتركة
/// (AddEditDocumentFolderPage / FolderDetailPage) بلا أي تكرار كود، والفارق
/// الوحيد هو تمرير ownerType='employee' الذي يُفعِّل تصفية/عرض الموظف داخل
/// كل مجلد. حذف مجلد موظفين مسموح دائماً — يحذف المجلد ومراجعه فقط.
class EmployeeDocumentsHubPage extends StatefulWidget {
  const EmployeeDocumentsHubPage({super.key});

  @override
  State<EmployeeDocumentsHubPage> createState() => _EmployeeDocumentsHubPageState();
}

class _EmployeeDocumentsHubPageState extends State<EmployeeDocumentsHubPage> {
  final _typeRepository = DocumentTypeRepository();
  final _documentRepository = DocumentRepository();
  final _searchController = TextEditingController();

  List<DocumentType> _folders = [];
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final types = await _typeRepository.getTypes(includeInactive: false, lifecycle: DocumentType.lifecycleEmployee);
    setState(() {
      _folders = types;
      _isLoading = false;
    });
  }

  List<DocumentType> get _filteredFolders {
    if (_query.trim().isEmpty) return _folders;
    final q = _query.trim();
    return _folders.where((f) => f.name.contains(q) || (f.description?.contains(q) ?? false)).toList();
  }

  Future<void> _createFolder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditDocumentFolderPage(lifecycle: DocumentType.lifecycleEmployee, nameHint: "اسم المجلد (مثال: عقود العمل)", showHotelScope: false),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _editFolder(DocumentType folder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditDocumentFolderPage(
          folder: folder,
          lifecycle: DocumentType.lifecycleEmployee,
          nameHint: "اسم المجلد (مثال: عقود العمل)",
          showHotelScope: false,
        ),
      ),
    );
    if (result == true) _load();
  }

  /// حذف مجلد موظفين مسموح دائماً بلا فحص استخدام — الحذف يزيل المجلد وكل
  /// مراجعه (document_folder_links تُحذف تلقائياً عبر ON DELETE CASCADE)،
  /// ولا يمسّ صفوف documents نفسها إطلاقاً.
  Future<void> _deleteFolder(DocumentType folder) async {
    final referencedCount = (await _documentRepository.getDocumentsInFolder(folder.id!, ownerType: Document.ownerTypeEmployee)).length;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف المجلد"),
        content: Text(
          referencedCount == 0
              ? "هل أنت متأكد من حذف مجلد \"${folder.name}\"؟"
              : "يحتوي هذا المجلد على $referencedCount مرجع مستند. حذف المجلد يزيل هذه المراجع فقط ولا يحذف أي مستند من النظام — تبقى كل المستندات محفوظة في أي مجلد آخر تظهر فيه وفي محرك المستندات الموحّد.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("حذف المجلد", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _typeRepository.deleteType(folder.id!);
    _load();
  }

  Future<void> _openFolder(DocumentType folder) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FolderDetailPage(folder: folder, ownerType: Document.ownerTypeEmployee)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("مستندات الموظفين", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: "بحث عن مجلد",
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
                  child: _folders.isEmpty
                      ? _buildEmptyState()
                      : _filteredFolders.isEmpty
                          ? const Center(child: Text("لا توجد مجلدات مطابقة", style: AppTextStyles.caption))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                              itemCount: _filteredFolders.length,
                              itemBuilder: (context, index) => _buildFolderTile(_filteredFolders[index]),
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFolder,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text("مجلد جديد"),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.md),
            const Text("لا توجد مجلدات مستندات موظفين بعد", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            const Text(
              "أنشئ أول مجلد (مثل عقود العمل أو الهوية) بزر \"مجلد جديد\" أدناه.",
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderTile(DocumentType folder) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: ListTile(
        onTap: () => _openFolder(folder),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.folder_outlined, color: primary),
        ),
        title: Text(folder.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
        subtitle: folder.description?.isNotEmpty == true
            ? Text(folder.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption)
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            if (action == 'edit') _editFolder(folder);
            if (action == 'delete') _deleteFolder(folder);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text("تعديل اسم المجلد")),
            PopupMenuItem(value: 'delete', child: Text("حذف المجلد", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
