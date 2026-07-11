import '../core/database/database_service.dart';
import '../models/document.dart';

class DocumentRepository {
  final DatabaseService _databaseService = DatabaseService();

  Future<List<Document>> getAllDocuments(int? hotelId) async {
    if (hotelId == null) return [];
    final List<Map<String, dynamic>> maps = await _databaseService.getDocuments(hotelId);
    return maps.map((map) => Document.fromMap(map)).toList();
  }

  Future<void> addDocument(Document document) async {
    await _databaseService.insertDocument(document.toMap());
  }

  Future<void> updateDocument(Document document) async {
    if (document.id != null) {
      await _databaseService.updateById('documents', document.toMap(), document.id!);
    }
  }

  Future<void> deleteDocument(int id) async {
    await _databaseService.deleteById('documents', id);
  }
}
