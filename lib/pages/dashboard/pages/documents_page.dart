import 'package:flutter/material.dart';

import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/document_status.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../models/document.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/employee_repository.dart';
import '../../../widgets/common/app_loading.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../widgets/document_card.dart';
import 'hotel_document_edit_page.dart';

import '../../../widgets/common/app_drawer.dart';

class _DocumentsPageBundle {
  final List<Document> hotelDocuments;
  final List<Document> employeeDocuments;
  final Map<int, String> employeeNames;
  const _DocumentsPageBundle({required this.hotelDocuments, required this.employeeDocuments, required this.employeeNames});
}

/// "مستندات الفندق" — يعرض كل مستند مُسجَّل بهذا الفندق عبر محرك المستندات
/// الموحّد بغض النظر عن الجهة المالكة الفعلية (الفندق مباشرة أو أحد
/// موظفيه...)، مُقسَّمة إلى "مستندات الفندق" (نُسخ الفندق من الأنواع
/// المرجعية، تُزوَّد تلقائياً — لا يُسمح بإنشاء نوع جديد من هنا) و"مستندات
/// الموظفين" (مُجمَّعة باسم كل موظف). الترتيب داخل كل مجموعة حسب أولوية
/// الحالة (منتهٍ أولاً...)، وليس أبجدياً.
class DocumentsPage extends StatefulWidget {
  final Hotel hotel;
  final bool alertsOnly;
  const DocumentsPage({super.key, required this.hotel, this.alertsOnly = false});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _documentRepository = DocumentRepository();
  final _employeeRepository = EmployeeRepository();
  final _searchController = TextEditingController();

  late Future<_DocumentsPageBundle> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<_DocumentsPageBundle> _load() async {
    final all = await _documentRepository.getDocumentsForHotel(widget.hotel.id!);
    final filtered = widget.alertsOnly ? all.where((d) => DocumentStatus.fromExpiryDate(d.expiryDate).needsAttention).toList() : all;
    final hotelDocs = filtered.where((d) => d.ownerType == Document.ownerTypeHotel).toList();
    final employeeDocs = filtered.where((d) => d.ownerType == Document.ownerTypeEmployee).toList();

    Map<int, String> employeeNames = {};
    if (employeeDocs.isNotEmpty) {
      final employees = await _employeeRepository.getEmployees(widget.hotel.id!);
      employeeNames = {for (final e in employees) if (e.id != null) e.id!: e.name};
    }

    return _DocumentsPageBundle(hotelDocuments: hotelDocs, employeeDocuments: employeeDocs, employeeNames: employeeNames);
  }

  /// بحث فوري في اسم المستند، رقم المستند، الجهة المصدرة، ونص الحالة.
  bool _matchesSearch(Document d) {
    if (_query.trim().isEmpty) return true;
    final q = _query.trim();
    final name = d.typeName ?? d.name;
    final status = DocumentStatus.fromExpiryDate(d.expiryDate).label;
    return name.contains(q) ||
        (d.documentNumber?.contains(q) ?? false) ||
        (d.issuingAuthority?.contains(q) ?? false) ||
        status.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      appBar: AppBar(
        title: HotelIdentityTitle(
          title: widget.alertsOnly ? "المستندات المنتهية والتنبيهات" : "مستندات الفندق",
          hotel: widget.hotel,
        ),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: "بحث بالاسم أو رقم المستند أو الجهة المصدرة أو الحالة",
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
          Expanded(
            child: FutureBuilder<_DocumentsPageBundle>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoading();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text("حدث خطأ: ${snapshot.error}"),
                  );
                }

                final bundle = snapshot.data;
                final hotelDocs = (bundle?.hotelDocuments ?? []).where(_matchesSearch).toList();
                final employeeDocs = (bundle?.employeeDocuments ?? []).where(_matchesSearch).toList();
                final isEmpty = hotelDocs.isEmpty && employeeDocs.isEmpty;

                if (isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.description,
                          size: 70,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _query.isNotEmpty
                              ? "لا توجد نتائج مطابقة"
                              : (widget.alertsOnly ? "لا توجد مستندات تحتاج تنبيهاً" : "لا توجد مستندات"),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final linked = hotelDocs.where((d) => d.isLinkedToType).toList();
                final legacy = hotelDocs.where((d) => !d.isLinkedToType).toList();
                final employeeByOwner = <int, List<Document>>{};
                for (final d in employeeDocs) {
                  if (d.ownerId == null) continue;
                  employeeByOwner.putIfAbsent(d.ownerId!, () => []).add(d);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ...linked.map((document) => _documentTile(document, identityColor)),
                    if (legacy.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text("مستندات قديمة غير مرتبطة بنوع مرجعي", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      ...legacy.map((document) => _documentTile(document, identityColor)),
                    ],
                    if (employeeByOwner.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text("مستندات الموظفين", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      for (final entry in employeeByOwner.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text(bundle?.employeeNames[entry.key] ?? "موظف", style: TextStyle(fontWeight: FontWeight.bold, color: identityColor, fontSize: 13)),
                        ),
                        ...entry.value.map((document) => _documentTile(document, identityColor)),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentTile(Document document, Color identityColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DocumentCard(
        document: document,
        identityAccent: identityColor,
        onTap: () => _openDocument(document),
      ),
    );
  }

  Future<void> _openDocument(Document document) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelDocumentEditPage(hotel: widget.hotel, document: document),
      ),
    );
    if (result == true && mounted) {
      _reload();
    }
  }
}
