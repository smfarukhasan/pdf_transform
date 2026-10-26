import 'dart:convert';

enum DraftType {
  pdfEditor,
  docScanner,
  officeDoc,
  imageTool,
}

class DraftItem {
  final String id;
  final String title;
  final DraftType type;
  final String? originalFilePath;
  final Map<String, dynamic> stateData;
  final DateTime updatedAt;

  DraftItem({
    required this.id,
    required this.title,
    required this.type,
    this.originalFilePath,
    required this.stateData,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'originalFilePath': originalFilePath,
      'stateData': stateData,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DraftItem.fromMap(Map<String, dynamic> map) {
    return DraftItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      type: DraftType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DraftType.pdfEditor,
      ),
      originalFilePath: map['originalFilePath'],
      stateData: Map<String, dynamic>.from(map['stateData'] ?? {}),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory DraftItem.fromJson(String source) => DraftItem.fromMap(json.decode(source));

  String get typeLabel {
    switch (type) {
      case DraftType.pdfEditor:
        return 'পিডিএফ এডিটর (PDF Editor)';
      case DraftType.docScanner:
        return 'ডকুমেন্ট স্ক্যানার (Document Scanner)';
      case DraftType.officeDoc:
        return 'অফিস ফাইল (Office Doc)';
      case DraftType.imageTool:
        return 'ইমেজ টুলস (Image Tool)';
    }
  }
}
