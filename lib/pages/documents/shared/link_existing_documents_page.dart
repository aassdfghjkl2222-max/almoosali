import 'package:flutter/material.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/document.dart';
import '../../../models/document_type.dart';
import '../../../models/hotel.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../widgets/common/app_dialog.dart';
import 'document_hotel_label.dart';
import 'selectable_document_card.dart';

/// "إضافة مستند" داخل مجلد — يعرض مستندات النظام مع مربعات اختيار (المستندات
/// المرتبطة بهذا المجلد أصلاً تظهر مُحدَّدة مسبقاً)، ويختار المستخدم مستنداً
/// واحداً أو أكثر لإضافتها كمراجع فقط — بلا أي نسخ للملف أو للسجل (مبدأ
/// References). عامة لأي مجلد بغض النظر عن دورة حياته.
///
/// فلتر الفندق أعلى الشاشة (🏨 الفندق: جميع الفنادق افتراضياً، أو فندق واحد
/// محدَّد) قاعدة تصميم موحّدة لكل شاشة تعرض مستندات عبر أكثر من فندق —
/// راجع [documentHotelLabel] و[SelectableDocumentCard]. عند اختيار "جميع
/// الفنادق" يظهر اسم فندق كل مستند داخل بطاقته؛ عند اختيار فندق محدَّد يُخفى
/// (معروف مسبقاً من الفلتر)، والبحث يعمل داخل نطاق الفندق المُختار فقط.
///
/// [ownerTypeFilter] اختياري: عند تمريره (مثلاً [Document.ownerTypeEmployee]
/// من مجلدات مستندات الموظفين) تُقصَر القائمة على مستندات نفس نوع المالك
/// فقط، حتى لا يُربط مستند فندق أو مورد داخل مجلد مخصَّص للموظفين.
class LinkExistingDocumentsPage extends StatefulWidget {
  final DocumentType folder;
  final String? ownerTypeFilter;
  const LinkExistingDocumentsPage({super.key, required this.folder, this.ownerTypeFilter});

  @override
  State<LinkExistingDocumentsPage> createState() => _LinkExistingDocumentsPageState();
}

class _LinkExistingDocumentsPageState extends State<LinkExistingDocumentsPage> {
  final _documentRepository = DocumentRepository();
  final _hotelRepository = HotelRepository();
  final _searchController = TextEditingController();

  List<Hotel> _hotels = [];
  int? _selectedHotelId; // null = جميع الفنادق

  List<Document> _documents = [];
  Map<int, List<int>> _specificHotelLinks = {};
  Set<int> _alreadyLinkedIds = {};
  final Set<int> _selectedIds = {};

  bool _isLoading = true;
  bool _isLoadingDocuments = false;
  bool _isSaving = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _hotels = await _hotelRepository.getAllHotels();
    final linked = await _documentRepository.getDocumentsInFolder(widget.folder.id!, ownerType: widget.ownerTypeFilter);
    _alreadyLinkedIds = linked.map((d) => d.id!).toSet();
    _selectedIds.addAll(_alreadyLinkedIds);
    await _loadDocuments();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoadingDocuments = true);
    final documents = await _documentRepository.searchDocumentsByName(
      '',
      ownerType: widget.ownerTypeFilter,
      hotelIds: _selectedHotelId == null ? null : [_selectedHotelId!],
    );
    final specificIds = documents.where((d) => d.hotelScope == Document.hotelScopeSpecific && d.id != null).map((d) => d.id!).toList();
    _specificHotelLinks = await _documentRepository.getDocumentHotelIdsBatch(specificIds);
    if (mounted) {
      setState(() {
        _documents = documents;
        _isLoadingDocuments = false;
      });
    }
  }

  /// يُعيد `0` (سنتينل "جميع الفنادق") أو معرّف فندق حقيقي (دوماً >= 1) عند
  /// اختيار فعلي، أو `null` إن أُغلقت النافذة بلا اختيار (سحب للأسفل) — تمييز
  /// ضروري لأن "جميع الفنادق" و"لا اختيار" لا يمكن تمثيلهما بنفس قيمة null.
  Future<void> _pickHotelFilter() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
              child: Align(alignment: Alignment.centerRight, child: Text("🏨 الفندق", style: AppTextStyles.title.copyWith(fontSize: 17))),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  RadioListTile<int>(
                    title: const Text("جميع الفنادق"),
                    value: 0,
                    groupValue: _selectedHotelId ?? 0,
                    onChanged: (v) => Navigator.pop(sheetContext, v),
                  ),
                  const Divider(height: 1),
                  ..._hotels.map((h) => RadioListTile<int>(
                        title: Text(h.arabicName),
                        value: h.id!,
                        groupValue: _selectedHotelId ?? 0,
                        onChanged: (v) => Navigator.pop(sheetContext, v),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    final newHotelId = result == 0 ? null : result;
    if (newHotelId != _selectedHotelId) {
      setState(() => _selectedHotelId = newHotelId);
      _loadDocuments();
    }
  }

  String _hotelNameById(int? hotelId) {
    for (final h in _hotels) {
      if (h.id == hotelId) return h.arabicName;
    }
    return "—";
  }

  List<Document> get _filtered {
    final base = _query.trim().isEmpty
        ? _documents
        : _documents.where((d) => (d.typeName ?? d.name).contains(_query.trim()) || (d.documentNumber?.contains(_query.trim()) ?? false)).toList();
    return base;
  }

  Future<void> _save() async {
    final newlySelected = _selectedIds.difference(_alreadyLinkedIds);
    if (newlySelected.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد الإضافة",
      message: "سيُضاف مرجع لـ ${newlySelected.length} مستند(ات) داخل مجلد \"${widget.folder.name}\" بلا أي نسخ لملفاتها.",
      onConfirm: () async {
        setState(() => _isSaving = true);
        for (final id in newlySelected) {
          await _documentRepository.linkDocumentToFolder(id, widget.folder.id!);
        }
        if (mounted) Navigator.pop(context, true);
      },
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final newlySelectedCount = _selectedIds.difference(_alreadyLinkedIds).length;
    final hotelFilterLabel = _selectedHotelId == null ? "جميع الفنادق" : _hotelNameById(_selectedHotelId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إضافة مستند", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _pickHotelFilter,
                      icon: const Icon(Icons.apartment_outlined, size: 16),
                      label: Text("🏨 $hotelFilterLabel", overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: "بحث عن مستند",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _searchController.clear(); _query = ''; })),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Expanded(
                  child: _isLoadingDocuments
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? const Center(child: Text("لا توجد مستندات مطابقة", style: AppTextStyles.caption))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final doc = _filtered[index];
                                final isSelected = _selectedIds.contains(doc.id);
                                return SelectableDocumentCard(
                                  document: doc,
                                  selected: isSelected,
                                  hotelLabel: _selectedHotelId == null ? documentHotelLabel(doc, hotels: _hotels, specificHotelLinks: _specificHotelLinks) : null,
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIds.remove(doc.id);
                                      } else {
                                        _selectedIds.add(doc.id!);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.link),
                    label: Text(newlySelectedCount > 0 ? "إضافة ($newlySelectedCount)" : "إضافة"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
              ],
            ),
    );
  }
}
