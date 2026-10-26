import 'dart:io';

class DocumentFile {
  final String name;
  final String path;
  final String extension;
  final int sizeInBytes;
  final DateTime modifiedDate;
  final int? pageCount;

  DocumentFile({
    required this.name,
    required this.path,
    required this.extension,
    required this.sizeInBytes,
    required this.modifiedDate,
    this.pageCount,
  });

  factory DocumentFile.fromFile(File file) {
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path.split(Platform.pathSeparator).last;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final stat = file.statSync();

    return DocumentFile(
      name: fileName,
      path: file.path,
      extension: ext,
      sizeInBytes: stat.size,
      modifiedDate: stat.modified,
    );
  }

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  bool get isPdf => extension == 'pdf';
  bool get isWord => extension == 'docx' || extension == 'doc';
  bool get isExcel => extension == 'xlsx' || extension == 'xls';
  bool get isPpt => extension == 'pptx' || extension == 'ppt';
  bool get isImage => ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(extension);
  bool get isText => extension == 'txt';
}
