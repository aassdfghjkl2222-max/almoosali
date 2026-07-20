import 'package:flutter/material.dart';

import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/document_status.dart';
import '../../../models/document.dart';
import '../../../repositories/document_repository.dart';
import '../../dashboard/pages/hotel_document_edit_page.dart';
import '../../dashboard/widgets/document_card.dart';

enum _StatusFilter { all, active, expired, warning30, urgent7 }

/// "المستندات العامة" — استعلام حي على كل مستند `hotelId == null` بغض النظر
/// عن أي مجلد يظهر فيه (راجع DocumentRepository.getGeneralDocuments)، وليست
/// مجلداً/عضوية فعلية — تماماً كبقية شاشات محرك المستندات الموحّد. الإنشاء
/// يبقى حصراً من داخل مجلد ("المستندات الخاصة" ← مجلد ← إنشاء مستند جديد ←
/// اختيار "عام")؛ هذه الشاشة عرض/تعديل فقط بلا زر إضافة.
class FolderlessDocumentListPage extends StatefulWidget {
  const FolderlessDocumentListPage({super.key});

  @override
  State<FolderlessDocumentListPage> createState() => _FolderlessDocumentListPageState();
}

class _FolderlessDocumentListPageState extends State<FolderlessDocumentListPage> {
  final _repository = DocumentRepository();
  final _searchController = TextEditingController();

  _StatusFilter _statusFilter = _StatusFilter.all;
  String _query = '';
  late Future<List<Document>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getGeneralDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = _repository.getGeneralDocuments());

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
    return name.contains(q) || (d.documentNumber?.contains(q) ?? false);
  }

  Future<void> _openDocument(Document document) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => HotelDocumentEditPage(document: document)));
    if (result == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("المستندات العامة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                hintText: "بحث بالاسم أو رقم المستند",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _searchController.clear(); _query = ''; })),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                isDense: true,
              ),
            ),
          ),
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
                if (documents.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isNotEmpty || _statusFilter != _StatusFilter.all ? "لا توجد نتائج مطابقة" : "لا توجد مستندات عامة بعد",
                      style: AppTextStyles.caption,
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                  itemCount: documents.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DocumentCard(document: documents[index], onTap: () => _openDocument(documents[index])),
                  ),
                );
              },
            ),
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
