class Note {
  final int? id;
  final int hotelId;
  final String title;
  final String content;
  final String createdAt;

  const Note({
    this.id,
    required this.hotelId,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'title': title,
      'content': content,
      'created_at': createdAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] ?? 0,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
