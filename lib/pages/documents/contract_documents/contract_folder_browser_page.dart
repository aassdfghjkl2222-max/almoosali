import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_page_route.dart';
import '../../../core/app_preferences.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/contract_document_options.dart';
import '../../../models/contract_document.dart';
import '../../../models/contract_folder.dart';
import '../../../repositories/contract_document_repository.dart';
import '../../../widgets/common/app_text_field.dart';
import 'contract_document_audit_log_page.dart';
import 'contract_documents_archive_page.dart';
import 'contract_documents_search_page.dart';
import 'create_edit_document_page.dart';
import 'create_edit_folder_sheet.dart';
import 'document_details_sheet.dart';
import 'folder_actions_sheet.dart';
import 'widgets/contract_empty_state.dart';
import 'widgets/document_tile.dart';
import 'widgets/folder_tile.dart';

/// المتصفح الأساسي لمستندات العقود — صفحة ذاتية التكرار: فتح مجلد فرعي يدفع
/// نسخة جديدة من نفس الصفحة بـ folderId مختلف (بلا حد لعمق التعشيش)،
/// وشريط التنقل (Breadcrumb) يعكس تماماً عدد الصفحات المدفوعة فوق الجذر، لذا
/// التنقل لأي مستوى سابق هو مجرد Navigator.pop بعدد الخطوات المطلوبة.
class ContractFolderBrowserPage extends StatefulWidget {
  final int? folderId;
  const ContractFolderBrowserPage({super.key, this.folderId});

  @override
  State<ContractFolderBrowserPage> createState() => _ContractFolderBrowserPageState();
}

class _ContractFolderBrowserPageState extends State<ContractFolderBrowserPage> {
  final _repo = ContractDocumentRepository();
  bool _isLoading = true;
  List<ContractFolder> _breadcrumb = [];
  List<ContractFolder> _subfolders = [];
  List<ContractDocument> _documents = [];
  ContractDocSortOption _sort = ContractDocSortOption.newest;
  bool _isGrid = true;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _loadData();
  }

  Future<void> _loadViewMode() async {
    final mode = await AppPreferences.getString(AppPreferences.keyContractDocsViewMode, defaultValue: 'grid');
    if (mounted) setState(() => _isGrid = mode != 'list');
  }

  Future<void> _toggleViewMode() async {
    final next = !_isGrid;
    setState(() => _isGrid = next);
    await AppPreferences.setString(AppPreferences.keyContractDocsViewMode, next ? 'grid' : 'list');
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final breadcrumb = await _repo.getBreadcrumb(widget.folderId);
    final subfolders = await _repo.getFolders(parentId: widget.folderId);
    final documents = await _repo.getDocuments(folderId: widget.folderId);
    if (!mounted) return;
    setState(() {
      _breadcrumb = breadcrumb;
      _subfolders = subfolders;
      _documents = _applySort(documents);
      _isLoading = false;
    });
  }

  List<ContractDocument> _applySort(List<ContractDocument> docs) {
    final list = [...docs];
    switch (_sort) {
      case ContractDocSortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ContractDocSortOption.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ContractDocSortOption.recentlyModified:
        list.sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
        break;
      case ContractDocSortOption.alphabetical:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    return list;
  }

  ContractFolder? get _currentFolder => _breadcrumb.isEmpty ? null : _breadcrumb.last;

  void _goToCrumb(int index) {
    // index == -1 يعني الجذر؛ عدد النوافذ المطلوب إغلاقها = العمق الحالي - العمق المستهدف.
    final targetDepth = index + 1;
    final popsNeeded = _breadcrumb.length - targetDepth;
    for (var i = 0; i < popsNeeded; i++) {
      Navigator.pop(context);
    }
  }

  Future<void> _openFolder(ContractFolder folder) async {
    final changed = await Navigator.push(context, premiumRoute(ContractFolderBrowserPage(folderId: folder.id)));
    if (changed == true) _loadData();
  }

  Future<void> _openCreateSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSizes.sm),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: AppSizes.md),
            ListTile(
              leading: const Icon(Icons.create_new_folder_rounded, color: AppColors.primary),
              title: const Text("إنشاء مجلد", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx, 'folder'),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_rounded, color: AppColors.primary),
              title: const Text("إنشاء مستند", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx, 'document'),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
        ),
      ),
    );
    if (choice == 'folder') {
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => CreateEditFolderSheet(parentId: widget.folderId),
      );
      if (created == true) _loadData();
    } else if (choice == 'document') {
      final created = await Navigator.push(context, premiumRoute(CreateEditDocumentPage(folderId: widget.folderId)));
      if (created == true) _loadData();
    }
  }

  Future<void> _openSort() async {
    final chosen = await showModalBottomSheet<ContractDocSortOption>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSizes.sm),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const Padding(padding: EdgeInsets.all(AppSizes.md), child: Align(alignment: Alignment.centerRight, child: Text("الترتيب", style: AppTextStyles.bodyBold))),
            for (final option in ContractDocSortOption.values)
              ListTile(
                leading: Icon(_sort == option ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _sort == option ? AppColors.primary : Colors.grey),
                title: Text(option.label),
                onTap: () => Navigator.pop(ctx, option),
              ),
            const SizedBox(height: AppSizes.sm),
          ],
        ),
      ),
    );
    if (chosen != null) {
      setState(() => _sort = chosen);
      _loadData();
    }
  }

  Future<void> _onFolderMenu(ContractFolder folder) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FolderActionsSheet(folder: folder),
    );
    if (result == true) _loadData();
  }

  Future<void> _onDocumentTap(ContractDocument document) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocumentDetailsSheet(document: document),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentFolder?.name ?? "مستندات العقود";
    final isEmpty = !_isLoading && _subfolders.isEmpty && _documents.isEmpty;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: "بحث",
            onPressed: () => Navigator.push(context, premiumRoute(const ContractDocumentsSearchPage())),
          ),
          IconButton(icon: const Icon(Icons.tune_rounded), tooltip: "الترتيب وطريقة العرض", onPressed: _openSort),
          IconButton(icon: Icon(_isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded), tooltip: "تبديل طريقة العرض", onPressed: _toggleViewMode),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'archive') Navigator.push(context, premiumRoute(const ContractDocumentsArchivePage()));
              if (v == 'log') Navigator.push(context, premiumRoute(const ContractDocumentAuditLogPage()));
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'archive', child: Text("الأرشيف")),
              PopupMenuItem(value: 'log', child: Text("سجل التدقيق")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumb(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : isEmpty
                    ? ContractEmptyState(
                        icon: Icons.folder_open_rounded,
                        title: "لا يوجد شيء هنا بعد",
                        message: "استخدم زر الإضافة أدناه لإنشاء أول مجلد أو مستند.",
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: _isGrid ? _buildGrid() : _buildList(),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            _crumbChip("مستندات العقود", isLast: _breadcrumb.isEmpty, onTap: () => _goToCrumb(-1)),
            for (var i = 0; i < _breadcrumb.length; i++) ...[
              const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.chevron_left_rounded, size: 16, color: Colors.grey)),
              _crumbChip(_breadcrumb[i].name, isLast: i == _breadcrumb.length - 1, onTap: () => _goToCrumb(i)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _crumbChip(String label, {required bool isLast, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: isLast ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: isLast
              ? AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.primary)
              : AppTextStyles.caption.copyWith(fontSize: 13, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: AppSizes.sm, crossAxisSpacing: AppSizes.sm, childAspectRatio: 0.95),
      itemCount: _subfolders.length + _documents.length,
      itemBuilder: (context, i) {
        if (i < _subfolders.length) {
          final f = _subfolders[i];
          return FolderTile(folder: f, isGrid: true, onTap: () => _openFolder(f), onLongPress: () => _onFolderMenu(f));
        }
        final d = _documents[i - _subfolders.length];
        return DocumentTile(document: d, isGrid: true, onTap: () => _onDocumentTap(d));
      },
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, 90),
      itemCount: _subfolders.length + _documents.length,
      itemBuilder: (context, i) {
        if (i < _subfolders.length) {
          final f = _subfolders[i];
          return Padding(padding: const EdgeInsets.only(bottom: AppSizes.sm), child: FolderTile(folder: f, isGrid: false, onTap: () => _openFolder(f), onLongPress: () => _onFolderMenu(f)));
        }
        final d = _documents[i - _subfolders.length];
        return Padding(padding: const EdgeInsets.only(bottom: AppSizes.sm), child: DocumentTile(document: d, isGrid: false, onTap: () => _onDocumentTap(d)));
      },
    );
  }
}
