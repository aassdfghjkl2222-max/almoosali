import 'package:flutter/material.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/document_type.dart';
import '../../../repositories/document_type_repository.dart';
import '../../document_types/add_edit_document_type_page.dart';
import '../shared/folder_detail_page.dart';
import 'folderless_document_list_page.dart';

/// "المستندات الدائمة" — قائمة "المجلدات" (كل مجلد هو نوع مستند مرجعي
/// بدورة حياة `DocumentType.lifecyclePermanent`، مثل البلدية والدفاع
/// المدني والسجل التجاري)، مربوطة بالكامل بمحرك المستندات الموحّد. لا
/// تكرار بيانات: المجلد هو نفسه صف document_types، وفتحه يعرض مستنداته
/// المرتبطة عبر جدول المراجع (FolderDetailPage المشتركة مع "الموسمية").
class PermanentDocumentsPage extends StatefulWidget {
  const PermanentDocumentsPage({super.key});

  @override
  State<PermanentDocumentsPage> createState() => _PermanentDocumentsPageState();
}

class _PermanentDocumentsPageState extends State<PermanentDocumentsPage> {
  final _repository = DocumentTypeRepository();
  List<DocumentType> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await _repository.getTypes(includeInactive: false, lifecycle: DocumentType.lifecyclePermanent);
    setState(() {
      _folders = types;
      _isLoading = false;
    });
  }

  Future<void> _createFolder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditDocumentTypePage(presetLifecycle: DocumentType.lifecyclePermanent, autoProvision: false)),
    );
    if (result == true) _load();
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
        title: const Text("المستندات الدائمة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildGeneralDocumentsEntry(),
                const SizedBox(height: AppSizes.lg),
                Text("المستندات الخاصة", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSizes.xs),
                const Text("مجلدات مستندات الفنادق — أنشئ مستنداً عاماً أو خاصاً بفندق من داخل أي مجلد", style: AppTextStyles.caption),
                const SizedBox(height: AppSizes.sm),
                if (_folders.isEmpty)
                  _buildEmptyState()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSizes.md,
                      crossAxisSpacing: AppSizes.md,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _folders.length,
                    itemBuilder: (context, index) => _buildFolderCard(_folders[index]),
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

  /// بطاقة دخول ثابتة لـ"المستندات العامة" — عرض حي (فلتر hotelId=null) وليس
  /// مجلداً فعلياً، راجع FolderlessDocumentListPage وDocumentRepository
  /// .getGeneralDocuments.
  Widget _buildGeneralDocumentsEntry() {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FolderlessDocumentListPage())),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.corporate_fare_outlined, color: primary),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("المستندات العامة", style: AppTextStyles.bodyBold),
                    const Text("مستندات تخص الشركة بالكامل، لا تتبع فندقاً", style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14),
            ],
          ),
        ),
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
            Icon(Icons.folder_open_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.md),
            const Text("لا توجد مجلدات مستندات دائمة بعد", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            const Text(
              "أنشئ أول مجلد (مثل البلدية أو السجل التجاري) بزر \"مجلد جديد\" أدناه.",
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderCard(DocumentType folder) {
    final primary = Theme.of(context).colorScheme.primary;
    final categoryColor = Color(folder.categoryColor ?? 0xFF7A1E2C);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _openFolder(folder),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.folder_outlined, color: primary),
              ),
              const Spacer(),
              Text(folder.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: categoryColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(folder.categoryName ?? '', style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
