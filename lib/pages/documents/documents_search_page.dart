import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/document_status.dart';
import '../../models/document.dart';
import '../../models/document_type.dart';
import '../../models/hotel.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/document_type_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../dashboard/pages/hotel_document_edit_page.dart';
import '../dashboard/widgets/document_card.dart';

enum _StatusFilter { all, active, expired, warning30, urgent7 }

/// "البحث في جميع المستندات" — بحث/فلترة موحَّدة عبر "المستندات الخاصة"
/// بالكامل (كل المجلدات معاً)، بفلاتر: الفندق، المجلد (نوع المستند)،
/// الحالة، والاسم — راجع DocumentRepository.searchDocumentsAdvanced.
class DocumentsSearchPage extends StatefulWidget {
  const DocumentsSearchPage({super.key});

  @override
  State<DocumentsSearchPage> createState() => _DocumentsSearchPageState();
}

class _DocumentsSearchPageState extends State<DocumentsSearchPage> {
  final _repository = DocumentRepository();
  final _typeRepository = DocumentTypeRepository();
  final _hotelRepository = HotelRepository();
  final _searchController = TextEditingController();

  List<Hotel> _hotels = [];
  List<DocumentType> _folders = [];
  Set<int> _selectedHotelIds = {};
  int? _selectedFolderId;
  _StatusFilter _statusFilter = _StatusFilter.all;
  String _query = '';

  bool _isLoading = true;
  List<Document> _documents = [];

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
    _folders = await _typeRepository.getTypes(includeInactive: false);
    await _search();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _search() async {
    final documents = await _repository.searchDocumentsAdvanced(
      query: _query,
      hotelIds: _selectedHotelIds.isEmpty ? null : _selectedHotelIds.toList(),
      documentTypeId: _selectedFolderId,
    );
    if (mounted) setState(() => _documents = documents);
  }

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
                        title: const Text("كل الفنادق"),
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
      _search();
    }
  }

  Future<void> _pickFolderFilter() async {
    final result = await showModalBottomSheet<int?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
              child: Align(alignment: Alignment.centerRight, child: Text("المجلد", style: AppTextStyles.title.copyWith(fontSize: 17))),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  RadioListTile<int?>(
                    title: const Text("كل المجلدات"),
                    value: null,
                    groupValue: _selectedFolderId,
                    onChanged: (v) => Navigator.pop(sheetContext, v),
                  ),
                  ..._folders.map((f) => RadioListTile<int?>(
                        title: Text(f.name),
                        value: f.id,
                        groupValue: _selectedFolderId,
                        onChanged: (v) => Navigator.pop(sheetContext, v),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    setState(() => _selectedFolderId = result);
    _search();
  }

  Future<void> _openDocument(Document document) async {
    Hotel? hotel;
    if (document.hotelId != null) {
      for (final h in _hotels) {
        if (h.id == document.hotelId) {
          hotel = h;
          break;
        }
      }
    }
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => HotelDocumentEditPage(hotel: hotel, document: document)));
    if (result == true && mounted) _search();
  }

  @override
  Widget build(BuildContext context) {
    final hotelLabel = _selectedHotelIds.isEmpty
        ? "كل الفنادق"
        : (_selectedHotelIds.length == 1
            ? (_hotels.firstWhere((h) => h.id == _selectedHotelIds.first, orElse: () => const Hotel(arabicName: '—', englishName: '', city: '')).arabicName)
            : "${_selectedHotelIds.length} فنادق");
    final folderLabel = _selectedFolderId == null
        ? "كل المجلدات"
        : (_folders.firstWhere((f) => f.id == _selectedFolderId, orElse: () => DocumentType(name: '—', categoryId: 0, createdAt: '')).name);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("البحث في جميع المستندات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                    onChanged: (v) {
                      _query = v;
                      _search();
                    },
                    decoration: InputDecoration(
                      hintText: "بحث بالاسم أو رقم المستند",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _query = '';
                                _search();
                              },
                            ),
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
                      OutlinedButton.icon(
                        onPressed: _pickHotelsFilter,
                        icon: const Icon(Icons.apartment_outlined, size: 16),
                        label: Text(hotelLabel, overflow: TextOverflow.ellipsis),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickFolderFilter,
                        icon: const Icon(Icons.folder_outlined, size: 16),
                        label: Text(folderLabel, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                _buildStatusFilterChips(),
                const SizedBox(height: AppSizes.sm),
                Expanded(
                  child: Builder(builder: (context) {
                    final documents = _documents.where(_matchesStatusFilter).toList();
                    if (documents.isEmpty) {
                      return const Center(child: Text("لا توجد نتائج مطابقة", style: AppTextStyles.caption));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                      itemCount: documents.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DocumentCard(document: documents[index], onTap: () => _openDocument(documents[index])),
                      ),
                    );
                  }),
                ),
              ],
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
