import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/document_status.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/document.dart';
import '../../../models/hotel.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../widgets/common/app_card.dart';

/// قسم "المستندات" داخل مركز التحليل — قراءة فقط. يعرض كل مستندات الفنادق
/// المختارة مجمّعة حسب الفندق والتاريخ (البُعدان الوحيدان المتوفران فعلياً
/// في بيانات المستندات — لا يوجد حالياً حقل نوع/موظف/تقرير على المستند
/// العام في قاعدة البيانات، فلم أخترع تصنيفاً غير موجود).
class DocumentsAnalysisPage extends StatefulWidget {
  final Hotel hotel;
  const DocumentsAnalysisPage({super.key, required this.hotel});

  @override
  State<DocumentsAnalysisPage> createState() => _DocumentsAnalysisPageState();
}

class _DocumentsAnalysisPageState extends State<DocumentsAnalysisPage> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<Hotel> _allHotels = [];
  Set<int> _selectedHotelIds = {};
  List<Document> _documents = [];
  String _search = "";
  String _groupBy = "الفندق"; // 'الفندق' أو 'التاريخ'

  @override
  void initState() {
    super.initState();
    _selectedHotelIds = widget.hotel.id != null ? {widget.hotel.id!} : {};
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _allHotels = await HotelRepository().getAllHotels();
    final docs = <Document>[];
    for (final id in _selectedHotelIds) {
      docs.addAll(await DocumentRepository().getDocumentsForHotel(id));
    }
    if (!mounted) return;
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  Color get _identityColor {
    if (_selectedHotelIds.length == 1) {
      final h = _allHotels.firstWhere((h) => h.id == _selectedHotelIds.first, orElse: () => widget.hotel);
      return HotelVisualIdentity.colorForHotel(h);
    }
    return AppColors.primary;
  }

  Hotel _hotelFor(int? id) => _allHotels.firstWhere((h) => h.id == id, orElse: () => widget.hotel);

  List<Document> get _filtered {
    if (_search.isEmpty) return _documents;
    return _documents.where((d) => d.name.toLowerCase().contains(_search.toLowerCase())).toList();
  }

  Future<void> _openHotelSelector() async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) {
        Set<int> temp = Set.from(_selectedHotelIds);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final allSelected = _allHotels.isNotEmpty && temp.length == _allHotels.length;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("اختيار الفنادق", style: AppTextStyles.title.copyWith(fontSize: 18)),
                    const SizedBox(height: AppSizes.sm),
                    CheckboxListTile(
                      title: const Text("جميع الفنادق", style: TextStyle(fontWeight: FontWeight.bold)),
                      value: allSelected,
                      onChanged: (v) => setSheetState(() {
                        temp = v == true ? _allHotels.map((h) => h.id!).toSet() : <int>{};
                      }),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allHotels.length,
                        itemBuilder: (_, i) {
                          final h = _allHotels[i];
                          return CheckboxListTile(
                            title: Text(h.arabicName),
                            secondary: CircleAvatar(radius: 10, backgroundColor: HotelVisualIdentity.colorForHotel(h)),
                            value: h.id != null && temp.contains(h.id),
                            onChanged: (v) => setSheetState(() {
                              if (h.id == null) return;
                              if (v == true) {
                                temp.add(h.id!);
                              } else {
                                temp.remove(h.id!);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _identityColor, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                      onPressed: temp.isEmpty ? null : () => Navigator.pop(ctx, temp),
                      child: const Text("تطبيق"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _selectedHotelIds = result);
      await _load();
    }
  }

  void _openDocumentDetail(Document d) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.typeName ?? d.name, style: AppTextStyles.title.copyWith(fontSize: 17)),
            const SizedBox(height: AppSizes.md),
            _infoLine("الفندق", _hotelFor(d.hotelId).arabicName),
            _infoLine("تاريخ الانتهاء", d.expiryDate),
            _infoLine("تاريخ الإضافة", d.createdAt.split('T').first),
            const SizedBox(height: AppSizes.md),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(flex: 2, child: Text(label, style: AppTextStyles.caption)), Expanded(flex: 3, child: Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), textAlign: TextAlign.end))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _identityColor;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: color,
        elevation: 0,
        title: const Text("المستندات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                InkWell(
                  onTap: _openHotelSelector,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: color.withOpacity(0.25))),
                    child: Row(children: [Icon(Icons.apartment, color: color, size: 20), const SizedBox(width: 10), Expanded(child: Text(_selectedHotelIds.length == _allHotels.length ? "جميع الفنادق" : "${_selectedHotelIds.length} فندق مختار", style: AppTextStyles.bodyBold.copyWith(fontSize: 13))), Icon(Icons.expand_more, color: color)]),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.trim()),
                  decoration: InputDecoration(
                    hintText: "بحث باسم المستند...",
                    hintStyle: AppTextStyles.caption,
                    prefixIcon: Icon(Icons.search, color: color),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color.withOpacity(0.2))),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Wrap(
                  spacing: 8,
                  children: ["الفندق", "التاريخ"].map((g) {
                    final selected = _groupBy == g;
                    return ChoiceChip(
                      label: Text("تجميع حسب $g", style: TextStyle(fontSize: 12, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                      selected: selected,
                      selectedColor: color,
                      onSelected: (_) => setState(() => _groupBy = g),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSizes.lg),
                AppCard(
                  identityAccent: color,
                  child: Column(
                    children: [
                      const Text("إجمالي المستندات", style: AppTextStyles.caption),
                      Text("${_filtered.length}", style: AppTextStyles.title.copyWith(fontSize: 26, color: color, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                ..._buildGroups(color),
              ],
            ),
    );
  }

  List<Widget> _buildGroups(Color color) {
    if (_filtered.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("لا توجد مستندات مطابقة", style: TextStyle(color: Colors.grey))))];
    }
    final Map<String, List<Document>> grouped = {};
    for (final d in _filtered) {
      final key = _groupBy == "الفندق" ? _hotelFor(d.hotelId).arabicName : (DateTime.tryParse(d.createdAt) != null ? DateFormat('yyyy-MM').format(DateTime.parse(d.createdAt)) : "غير محدد");
      grouped.putIfAbsent(key, () => []).add(d);
    }
    final widgets = <Widget>[];
    grouped.forEach((key, docs) {
      widgets.add(Text("$key (${docs.length})", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 14)));
      widgets.add(const SizedBox(height: AppSizes.sm));
      widgets.addAll(docs.map((d) => _buildDocRow(d, color)));
      widgets.add(const SizedBox(height: AppSizes.md));
    });
    return widgets;
  }

  Widget _buildDocRow(Document d, Color color) {
    final status = DocumentStatus.fromExpiryDate(d.expiryDate);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: status.needsAttention ? status.color.withOpacity(0.1) : color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.description_outlined, color: status.needsAttention ? status.color : color, size: 18),
        ),
        title: Text(d.typeName ?? d.name, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(status.label, style: AppTextStyles.caption.copyWith(color: status.needsAttention ? status.color : null)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
        onTap: () => _openDocumentDetail(d),
      ),
    );
  }
}
