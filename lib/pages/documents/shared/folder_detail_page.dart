import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/document_status.dart';
import '../../../models/document.dart';
import '../../../models/document_type.dart';
import '../../../models/employee.dart';
import '../../../models/hotel.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/employee_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../services/document_merge_service.dart';
import '../../dashboard/pages/hotel_document_edit_page.dart';
import '../../dashboard/widgets/document_card.dart';
import 'create_document_for_folder_page.dart';
import 'document_hotel_label.dart';
import 'employee_picker_sheet.dart';
import 'link_existing_documents_page.dart';
import 'selectable_document_card.dart';

/// "داخل المجلد" — عامة لأي مجلد (نوع مرجعي) بغض النظر عن دورة حياته
/// (دائم/موسمي/مستندات موظفين/أي نوع مستقبلي)، تعرض كل المستندات المرتبطة
/// به عبر جدول المراجع document_folder_links عبر كل الفنادق. اختيار فندق
/// واحد/عدة/الكل، فلتر حالة، بحث فوري، وترتيب حسب أولوية الحالة — كلها فوق
/// DocumentRepository.getDocumentsInFolder. مشتركة بين كل أقسام "المستندات"
/// حتى لا يتكرر هذا الكود لكل دورة حياة جديدة.
///
/// [ownerType] اختياري: عند تركه null (الدائمة/الموسمية) لا تصفية إضافية —
/// السلوك القديم كما هو بلا أي تغيير. عند تمريره (مثلاً
/// [Document.ownerTypeEmployee]) تُضاف تصفية بالمالك نفسه + فلتر موظف إضافي،
/// وتُمرَّر نفس القيمة لصفحتي الإضافة (ربط/إنشاء) حتى يبقى محتوى المجلد
/// مقصوراً على نفس نوع المالك دوماً.
class FolderDetailPage extends StatefulWidget {
  final DocumentType folder;
  final String? ownerType;
  const FolderDetailPage({super.key, required this.folder, this.ownerType});

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

enum _StatusFilter { all, active, expired, warning30, urgent7 }

class _FolderDetailPageState extends State<FolderDetailPage> {
  final _documentRepository = DocumentRepository();
  final _hotelRepository = HotelRepository();
  final _employeeRepository = EmployeeRepository();
  final _searchController = TextEditingController();

  bool get _isEmployeeFolder => widget.ownerType == Document.ownerTypeEmployee;

  List<Hotel> _hotels = [];
  Set<int> _selectedHotelIds = {}; // فارغة = كل الفنادق
  Map<int, List<int>> _specificHotelLinks = {}; // documentId -> hotelIds (نطاق specific فقط)
  List<Employee> _employees = [];
  int? _selectedEmployeeId;
  _StatusFilter _statusFilter = _StatusFilter.all;
  String _query = '';

  bool _selectionMode = false;
  // List وليس Set عمداً — يحفظ ترتيب اختيار المستخدم الفعلي، وهو ما يُستخدم
  // حرفياً كترتيب صفحات الدمج (البند خامس عشر): "متابعة" لا "إعادة فرز".
  final List<int> _selectedIds = [];
  bool _isBusy = false;
  // آخر قائمة مستندات مُحمَّلة فعلياً (بعد الفلاتر) — تحتاجها أزرار المشاركة/
  // الدمج في AppBar وضع التحديد، وهي خارج نطاق FutureBuilder نفسه.
  List<Document> _lastLoadedDocuments = [];

  late Future<List<Document>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _hotelRepository.getAllHotels().then((h) {
      if (mounted) setState(() => _hotels = h);
    });
    if (_isEmployeeFolder) {
      _employeeRepository.getAllEmployees().then((e) {
        if (mounted) setState(() => _employees = e);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Document>> _load() async {
    final documents = await _documentRepository.getDocumentsInFolder(
      widget.folder.id!,
      hotelIds: _selectedHotelIds.isEmpty ? null : _selectedHotelIds.toList(),
      ownerType: widget.ownerType,
      ownerId: _selectedEmployeeId,
    );
    final specificIds = documents.where((d) => d.hotelScope == Document.hotelScopeSpecific && d.id != null).map((d) => d.id!).toList();
    _specificHotelLinks = await _documentRepository.getDocumentHotelIdsBatch(specificIds);
    return documents;
  }

  void _reload() => setState(() => _future = _load());

  bool _matchesStatusFilter(Document d) {
    final level = DocumentStatus.fromExpiryDate(d.expiryDate).level;
    switch (_statusFilter) {
      case _StatusFilter.all:
        return true;
      case _StatusFilter.active:
        return level == DocumentStatusLevel.active;
      case _StatusFilter.expired:
        return level == DocumentStatusLevel.expired;
      case _StatusFilter.warning30:
        return level == DocumentStatusLevel.warning;
      case _StatusFilter.urgent7:
        return level == DocumentStatusLevel.urgent;
    }
  }

  bool _matchesSearch(Document d) {
    if (_query.trim().isEmpty) return true;
    final q = _query.trim();
    final name = d.typeName ?? d.name;
    final status = DocumentStatus.fromExpiryDate(d.expiryDate).label;
    return name.contains(q) ||
        (d.documentNumber?.contains(q) ?? false) ||
        status.contains(q) ||
        (_isEmployeeFolder && _employeeLabel(d).contains(q));
  }

  String _hotelLabel(Document d) => documentHotelLabel(d, hotels: _hotels, specificHotelLinks: _specificHotelLinks);

  String _employeeLabel(Document d) {
    if (!_isEmployeeFolder || d.ownerId == null) return '';
    for (final e in _employees) {
      if (e.id == d.ownerId) return e.name;
    }
    return "—";
  }

  String _selectedEmployeeLabel() {
    for (final e in _employees) {
      if (e.id == _selectedEmployeeId) return e.name;
    }
    return "موظف محدَّد";
  }

  Future<void> _pickEmployeeFilter() async {
    final result = await showEmployeePicker(
      context,
      employees: _employees,
      hotelNames: {for (final h in _hotels) if (h.id != null) h.id!: h.arabicName},
      allowClear: true,
      title: "تصفية حسب الموظف",
    );
    if (result == null) return;
    setState(() => _selectedEmployeeId = result == 0 ? null : result);
    _reload();
  }

  Future<void> _pickHotelsFilter() async {
    final selected = Set<int>.from(_selectedHotelIds);
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("تصفية حسب الفندق", style: AppTextStyles.title.copyWith(fontSize: 17)),
                const SizedBox(height: AppSizes.sm),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      CheckboxListTile(
                        title: const Text("جميع الفنادق"),
                        value: selected.isEmpty,
                        onChanged: (_) => setSheetState(() => selected.clear()),
                      ),
                      const Divider(height: 1),
                      ..._hotels.map((h) => CheckboxListTile(
                            title: Text(h.arabicName),
                            value: selected.contains(h.id),
                            onChanged: (checked) => setSheetState(() {
                              if (checked == true) {
                                selected.add(h.id!);
                              } else {
                                selected.remove(h.id);
                              }
                            }),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext, selected),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: const Text("تطبيق"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() => _selectedHotelIds = result);
      _reload();
    }
  }

  Future<void> _openDocument(Document document) async {
    // مستند عام (hotelId=null) يُعدَّل بلا أي فندق — لا حاجة لإيجاد/اختلاق
    // فندق له؛ HotelDocumentEditPage تدعم hotel=null وتستخدم الثيم الافتراضي.
    Hotel? hotel;
    if (document.hotelId != null) {
      for (final h in _hotels) {
        if (h.id == document.hotelId) {
          hotel = h;
          break;
        }
      }
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HotelDocumentEditPage(hotel: hotel, document: document)),
    );
    if (result == true && mounted) _reload();
  }

  // ---------------- التحديد المتعدد ----------------

  void _enterSelectionMode(Document document) {
    if (document.id == null) return;
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(document.id!);
    });
  }

  void _toggleSelection(Document document) {
    if (document.id == null) return;
    setState(() {
      if (_selectedIds.contains(document.id)) {
        _selectedIds.remove(document.id);
      } else {
        _selectedIds.add(document.id!);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// المستندات المحدَّدة بترتيب اختيارها الفعلي (وليس ترتيب عرضها في القائمة).
  List<Document> _selectedDocumentsInOrder(List<Document> allDocuments) {
    final byId = {for (final d in allDocuments) if (d.id != null) d.id!: d};
    return [for (final id in _selectedIds) if (byId.containsKey(id)) byId[id]!];
  }

  Future<void> _shareSelected(List<Document> allDocuments) async {
    final selected = _selectedDocumentsInOrder(allDocuments);
    if (selected.isEmpty || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      final files = <XFile>[];
      for (final doc in selected) {
        if (doc.id == null) continue;
        final attachments = await _documentRepository.getAttachments(doc.id!);
        for (final attachment in attachments) {
          if (await File(attachment.filePath).exists()) files.add(XFile(attachment.filePath));
        }
      }
      if (!mounted) return;
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد مرفقات للمستندات المحددة")));
        return;
      }
      await Share.shareXFiles(files);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// دمج مرفقات المستندات المحدَّدة في ملف PDF واحد — بترتيب الاختيار
  /// بالضبط (راجع DocumentMergeService وحدّها الواقعي المُفصَح عنه: ترقيم
  /// بصري وليس دمجاً متجهياً). الناتج يُعرض فوراً عبر ورقة مشاركة — لا يُنشئ
  /// أي سجل مستند جديد في قاعدة البيانات.
  Future<void> _mergeSelected(List<Document> allDocuments) async {
    final selected = _selectedDocumentsInOrder(allDocuments);
    if (selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اختر مستندَين على الأقل للدمج")));
      return;
    }
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final bytes = await DocumentMergeService.mergeDocuments(selected, _documentRepository);
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/merged_documents_${DateTime.now().millisecondsSinceEpoch}.pdf";
      await File(path).writeAsBytes(bytes);
      if (mounted) await Share.shareXFiles([XFile(path)], text: "مستندات مدموجة");
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تعذّر الدمج: $e")));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// إزالة مرجع المستند من هذا المجلد فقط — لا يحذف المستند نفسه ولا مرفقاته
  /// ولا وجوده في أي مجلد آخر (حذف المستند الأصلي يكون من صفحته الخاصة فقط).
  Future<void> _unlinkDocument(Document document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("إزالة من هذا المجلد"),
        content: Text("سيُزال \"${document.typeName ?? document.name}\" من مجلد \"${widget.folder.name}\" فقط، ويبقى محفوظاً في النظام وفي أي مجلد آخر يظهر فيه."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("إزالة", style: TextStyle(color: AppColors.warning))),
        ],
      ),
    );
    if (confirmed != true || document.id == null) return;
    await _documentRepository.unlinkDocumentFromFolder(document.id!, widget.folder.id!);
    _reload();
  }

  Future<void> _showAddOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text("إضافة مستند"),
              subtitle: const Text("اختيار مستند أو أكثر من المستندات الموجودة في النظام", style: AppTextStyles.caption),
              onTap: () => Navigator.pop(sheetContext, 'existing'),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text("إنشاء مستند جديد"),
              subtitle: const Text("إذا لم يكن المستند موجوداً في النظام بعد", style: AppTextStyles.caption),
              onTap: () => Navigator.pop(sheetContext, 'new'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'existing') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LinkExistingDocumentsPage(folder: widget.folder, ownerTypeFilter: widget.ownerType)),
      );
      if (result == true) _reload();
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateDocumentForFolderPage(folder: widget.folder, ownerType: widget.ownerType ?? Document.ownerTypeHotel)),
      );
      if (result == true) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotelFilterLabel = _selectedHotelIds.isEmpty
        ? "كل الفنادق"
        : (_selectedHotelIds.length == 1
            ? (_hotels.firstWhere((h) => h.id == _selectedHotelIds.first, orElse: () => const Hotel(arabicName: '—', englishName: '', city: '')).arabicName)
            : "${_selectedHotelIds.length} فنادق مُحدَّدة");

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _exitSelectionMode),
              title: Text("${_selectedIds.length} محدَّد", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: _isBusy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.share_outlined, color: Colors.white),
                  tooltip: "مشاركة",
                  onPressed: _isBusy ? null : () => _shareSelected(_lastLoadedDocuments),
                ),
                IconButton(
                  icon: const Icon(Icons.merge_type, color: Colors.white),
                  tooltip: "دمج",
                  onPressed: _isBusy ? null : () => _mergeSelected(_lastLoadedDocuments),
                ),
              ],
            )
          : AppBar(
              title: Text(widget.folder.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: "بحث بالاسم أو رقم المستند أو الحالة",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _searchController.clear(); _query = ''; })),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_isEmployeeFolder)
                  OutlinedButton.icon(
                    onPressed: _pickEmployeeFilter,
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: Text(
                      _selectedEmployeeId == null ? "كل الموظفين" : _selectedEmployeeLabel(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _pickHotelsFilter,
                  icon: const Icon(Icons.apartment_outlined, size: 16),
                  label: Text(hotelFilterLabel, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          _buildStatusFilterChips(),
          const SizedBox(height: AppSizes.sm),
          Expanded(
            child: FutureBuilder<List<Document>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("حدث خطأ: ${snapshot.error}"));
                }

                final documents = (snapshot.data ?? []).where(_matchesStatusFilter).where(_matchesSearch).toList();
                _lastLoadedDocuments = documents;
                if (documents.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isNotEmpty || _statusFilter != _StatusFilter.all ? "لا توجد نتائج مطابقة" : "لا توجد مستندات في هذا المجلد بعد",
                      style: AppTextStyles.caption,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    // إخفاء اسم الفندق داخل البطاقة عند تضييق الفلتر لفندق واحد بعينه
                    // (معروف مسبقاً من الفلتر أعلى الشاشة) — قاعدة تصميم موحّدة لكل
                    // شاشة تعرض مستندات عبر أكثر من فندق، راجع LinkExistingDocumentsPage.
                    final showHotelName = _selectedHotelIds.length != 1;
                    final labelParts = [
                      if (_isEmployeeFolder) _employeeLabel(document),
                      if (showHotelName) _hotelLabel(document),
                    ];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (labelParts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 4, bottom: 2),
                              child: Text(
                                labelParts.join(' — '),
                                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          _selectionMode
                              ? SelectableDocumentCard(
                                  document: document,
                                  selected: _selectedIds.contains(document.id),
                                  onTap: () => _toggleSelection(document),
                                )
                              : GestureDetector(
                                  onLongPress: () => _enterSelectionMode(document),
                                  child: Stack(
                                    children: [
                                      DocumentCard(document: document, onTap: () => _openDocument(document)),
                                      Positioned(
                                        left: 4,
                                        top: 4,
                                        child: GestureDetector(
                                          onTap: () => _unlinkDocument(document),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                            child: const Icon(Icons.link_off, color: Colors.white, size: 15),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddOptions,
              icon: const Icon(Icons.add),
              label: const Text("إضافة مستند"),
            ),
    );
  }

  Widget _buildStatusFilterChips() {
    final entries = <(_StatusFilter, String)>[
      (_StatusFilter.all, "جميع المستندات"),
      (_StatusFilter.active, "سارية"),
      (_StatusFilter.expired, "منتهية"),
      (_StatusFilter.warning30, "تنتهي خلال 30 يوماً"),
      (_StatusFilter.urgent7, "تنتهي خلال 7 أيام"),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        itemCount: entries.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = entries[index];
          final isSelected = _statusFilter == filter;
          return ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: isSelected,
            onSelected: (_) => setState(() => _statusFilter = filter),
          );
        },
      ),
    );
  }
}
