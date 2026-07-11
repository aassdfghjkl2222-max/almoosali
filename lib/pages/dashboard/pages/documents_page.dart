import 'package:flutter/material.dart';

import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../models/document.dart';
import '../../../repositories/document_repository.dart';
import '../../../widgets/common/app_loading.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../widgets/document_card.dart';
import 'add_document_page.dart';

import 'document_details_page.dart';

import '../../../widgets/common/app_drawer.dart';

class DocumentsPage extends StatefulWidget {
  final Hotel hotel;
  final bool alertsOnly;
  const DocumentsPage({super.key, required this.hotel, this.alertsOnly = false});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final repository = DocumentRepository();

  List<Document> _filterAlerts(List<Document> documents) {
    if (!widget.alertsOnly) return documents;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return documents.where((doc) {
      final expiry = DateTime.tryParse(doc.expiryDate);
      if (expiry == null) return false;
      final days = expiry.difference(today).inDays;
      return days <= 30;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      appBar: AppBar(
        title: HotelIdentityTitle(
          title: widget.alertsOnly ? "المستندات المنتهية والتنبيهات" : "المستندات",
          hotel: widget.hotel,
        ),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      body: FutureBuilder<List<Document>>(
        future: repository.getAllDocuments(widget.hotel.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("حدث خطأ: ${snapshot.error}"),
            );
          }

          final documents = _filterAlerts(snapshot.data ?? []);

          if (documents.isEmpty) {
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
                    widget.alertsOnly ? "لا توجد مستندات تحتاج تنبيهاً" : "لا توجد مستندات",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DocumentCard(
                  document: document,
                  identityAccent: identityColor,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentDetailsPage(document: document),
                      ),
                    );
                    if (result == true) {
                      setState(() {});
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddDocumentPage(hotelId: widget.hotel.id!),
            ),
          );
          if (result == true) {
            setState(() {});
          }
        },
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}