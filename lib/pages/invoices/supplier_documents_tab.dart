import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/document_status.dart';
import '../../models/document.dart';
import '../../models/hotel.dart';
import '../../models/supplier.dart';
import '../../repositories/document_repository.dart';
import '../../widgets/documents/pick_document_type_dialog.dart';
import '../dashboard/pages/hotel_document_edit_page.dart';
import '../dashboard/widgets/document_card.dart';

/// "مستندات المورد" — تبويب داخل بطاقة المورد، مربوط بالكامل بمحرك
/// المستندات الموحّد (owner_type='supplier'). أنواع المستندات تُختار حصراً
/// من البيانات المرجعية عند الإضافة — لا إنشاء نوع جديد من هنا. الترتيب
/// حسب أولوية الحالة (منتهٍ أولاً...)، وليس أبجدياً.
class SupplierDocumentsTab extends StatefulWidget {
  final Hotel hotel;
  final Supplier supplier;
  final Color identityColor;
  const SupplierDocumentsTab({super.key, required this.hotel, required this.supplier, required this.identityColor});

  @override
  State<SupplierDocumentsTab> createState() => _SupplierDocumentsTabState();
}

class _SupplierDocumentsTabState extends State<SupplierDocumentsTab> {
  final _repository = DocumentRepository();
  final _searchController = TextEditingController();
  late Future<List<Document>> _future;
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

  Future<List<Document>> _load() {
    return _repository.getDocumentsForOwner(Document.ownerTypeSupplier, widget.supplier.id!);
  }

  void _reload() => setState(() => _future = _load());

  /// بحث بالاسم، رقم المستند، وحالة المستند فقط (كما هو محدَّد لمستندات الموردين).
  bool _matchesSearch(Document d) {
    if (_query.trim().isEmpty) return true;
    final q = _query.trim();
    final name = d.typeName ?? d.name;
    final status = DocumentStatus.fromExpiryDate(d.expiryDate).label;
    return name.contains(q) || (d.documentNumber?.contains(q) ?? false) || status.contains(q);
  }

  Future<void> _addDocument() async {
    final type = await showPickDocumentTypeDialog(context: context, title: "اختر نوع مستند المورد");
    if (type == null || !mounted) return;

    final document = Document(
      hotelId: widget.hotel.id,
      ownerType: Document.ownerTypeSupplier,
      ownerId: widget.supplier.id!,
      documentTypeId: type.id,
      name: type.name,
      expiryDate: '',
      createdAt: DateTime.now().toIso8601String(),
    );
    final id = await _repository.addDocument(document);
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HotelDocumentEditPage(hotel: widget.hotel, document: document.copyWith(id: id))),
    );
    if (result == true) _reload();
  }

  Future<void> _openDocument(Document document) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HotelDocumentEditPage(hotel: widget.hotel, document: document)),
    );
    if (result == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: "بحث باسم المستند أو رقمه أو حالته",
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
            child: FutureBuilder<List<Document>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("حدث خطأ: ${snapshot.error}"));
                }

                final documents = (snapshot.data ?? []).where(_matchesSearch).toList();
                if (documents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          _query.isNotEmpty ? "لا توجد نتائج مطابقة" : "لا توجد مستندات لهذا المورد بعد",
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                  itemCount: documents.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DocumentCard(
                      document: documents[index],
                      identityAccent: widget.identityColor,
                      onTap: () => _openDocument(documents[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDocument,
        backgroundColor: widget.identityColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("إضافة مستند"),
      ),
    );
  }
}
