import 'package:flutter/material.dart';

import '../../../repositories/document_repository.dart';
import '../widgets/document_card.dart';
import 'add_document_page.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = DocumentRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text("المستندات"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: repository.documents.length,
        itemBuilder: (context, index) {
          final document = repository.documents[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DocumentCard(
              document: document,
              onTap: () {},
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddDocumentPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}