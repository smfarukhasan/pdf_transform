import 'dart:convert';

class RecentItem {
  final String id;
  final String filePath;
  final String fileName;
  final int lastPage;
  final int totalPages;
  final DateTime lastReadTime;
  final int fileSize;

  RecentItem({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.lastPage,
    required this.totalPages,
    required this.lastReadTime,
    required this.fileSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'lastPage': lastPage,
      'totalPages': totalPages,
      'lastReadTime': lastReadTime.toIso8601String(),
      'fileSize': fileSize,
    };
  }

  factory RecentItem.fromMap(Map<String, dynamic> map) {
    return RecentItem(
      id: map['id'] ?? '',
      filePath: map['filePath'] ?? '',
      fileName: map['fileName'] ?? '',
      lastPage: map['lastPage'] ?? 1,
      totalPages: map['totalPages'] ?? 1,
      lastReadTime: DateTime.tryParse(map['lastReadTime'] ?? '') ?? DateTime.now(),
      fileSize: map['fileSize'] ?? 0,
    );
  }

  String toJson() => json.encode(toMap());
  factory RecentItem.fromJson(String source) => RecentItem.fromMap(json.decode(source));

  double get progress {
    if (totalPages <= 0) return 0.0;
    return (lastPage / totalPages).clamp(0.0, 1.0);
  }

  String get formattedProgress {
    final pct = (progress * 100).toInt();
    return '$pct%';
  }
}
