import '../core/database/database_service.dart';
import '../models/note.dart';

class NoteRepository {
  final _dbService = DatabaseService();

  Future<List<Note>> getAllNotes(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getNotes(hotelId);
    return data.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> addNote(Note note) async {
    return await _dbService.insertNote(note.toMap());
  }

  Future<int> updateNote(Note note) async {
    if (note.id == null) return 0;
    return await _dbService.updateById('notes', note.toMap(), note.id!);
  }

  Future<int> deleteNote(int id) async {
    return await _dbService.deleteById('notes', id);
  }
}
