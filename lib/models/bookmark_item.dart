import 'dart:convert';

class BookmarkItem {
  final String id;
  final String filePath;
  final int pageNumber;
  final String note;
  final DateTime createdAt;

  BookmarkItem({
    required this.id,
    required this.filePath,
    required this.pageNumber,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'pageNumber': pageNumber,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BookmarkItem.fromMap(Map<String, dynamic> map) {
    return BookmarkItem(
      id: map['id'] ?? '',
      filePath: map['filePath'] ?? '',
      pageNumber: map['pageNumber'] ?? 1,
      note: map['note'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory BookmarkItem.fromJson(String source) => BookmarkItem.fromMap(json.decode(source));
}
