import 'package:flutter/material.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/document_type.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/document_type_repository.dart';
import '../shared/add_edit_document_folder_page.dart';
import '../shared/folder_detail_page.dart';

/// "المستندات الموسمية" — مجلدات مؤقتة/موسمية (موسم الحج، رمضان، العمرة،
/// التفتيش، وزارة السياحة...) بعدد غير محدود. كل مجلد هو نوع مستند مرجعي
/// بدورة حياة 'seasonal'، يحفظ مراجع فقط لمستندات محرك المستندات الموحّد
/// (بلا أي نسخ). خلافاً لأنواع "مستندات الفندق"، حذف مجلد موسمي مسموح
/// دائماً — يحذف المجلد ومراجعه فقط، ولا يحذف أي مستند من النظام أبداً.
class SeasonalDocumentsPage extends StatefulWidget {
  const SeasonalDocumentsPage({super.key});

  @override
  State<SeasonalDocumentsPage> createState() => _SeasonalDocumentsPageState();
}

class _SeasonalDocumentsPageState extends State<SeasonalDocumentsPage> {
  final _typeRepository = DocumentTypeRepository();
  final _documentRepository = DocumentRepository();
  List<DocumentType> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await _typeRepository.getTypes(includeInactive: false, lifecycle: DocumentType.lifecycleSeasonal);
    setState(() {
      _folders = types;
      _isLoading = false;
    });
  }

  Future<void> _createFolder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditDocumentFolderPage(lifecycle: DocumentType.lifecycleSeasonal, nameHint: "اسم المجلد (مثال: موسم الحج)")),
    );
    if (result == true) _load();
  }

  Future<void> _editFolder(DocumentType folder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditDocumentFolderPage(folder: folder, lifecycle: DocumentType.lifecycleSeasonal, nameHint: "اسم المجلد (مثال: موسم الحج)")),
    );
    if (result == true) _load();
  }

  /// حذف مجلد موسمي مسموح دائماً بلا فحص استخدام — الحذف يزيل المجلد وكل
  /// مراجعه (document_folder_links تُحذف تلقائياً عبر ON DELETE CASCADE
  /// المرتبط بـdocument_type_id فقط)، ولا يمسّ صفوف documents نفسها إطلاقاً.
  Future<void> _deleteFolder(DocumentType folder) async {
    final referencedCount = (await _documentRepository.getDocumentsInFolder(folder.id!)).length;
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
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FolderDetailPage(folder: folder)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("المستندات الموسمية", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _folders.length,
                  itemBuilder: (context, index) => _buildFolderTile(_folders[index]),
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
            Icon(Icons.event_repeat_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.md),
            const Text("لا توجد مجلدات موسمية بعد", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            const Text(
              "أنشئ أول مجلد (مثل موسم الحج أو رمضان) بزر \"مجلد جديد\" أدناه.",
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
        subtitle: Text(
          folder.description?.isNotEmpty == true ? folder.description! : (folder.isAllHotels ? "كل الفنادق" : "فنادق محددة"),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption,
        ),
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
