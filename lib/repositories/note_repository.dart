import '../core/database/database_service.dart';
import '../models/note.dart';
import 'trash_repository.dart';

class NoteRepository {
  final _dbService = DatabaseService();
  final _trashRepository = TrashRepository();

  Future<List<Note>> getAllNotes(int? hotelId) async {
    if (hotelId == null) return [];
    final data = await _dbService.getNotes(hotelId);
    return data.map((map) => Note.fromMap(map)).toList();
  }

  /// عبر كل الفنادق معاً — راجع تعليق DatabaseService.getAllNotesAcrossHotels
  /// (البحث الشامل GlobalSearch فقط).
  Future<List<Note>> getAllNotesAcrossHotels() async {
    final data = await _dbService.getAllNotesAcrossHotels();
    return data.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> addNote(Note note) async {
    return await _dbService.insertNote(note.toMap());
  }

  Future<int> updateNote(Note note) async {
    if (note.id == null) return 0;
    return await _dbService.updateById('notes', note.toMap(), note.id!);
  }

  /// نقل ناعم إلى سلة المهملات — راجع TrashRepository. لا حذف فعلي هنا إطلاقاً.
  Future<void> deleteNote(Note note) async {
    await _trashRepository.trash('note', note.id!, note.title);
  }
}
