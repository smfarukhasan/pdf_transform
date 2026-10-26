import 'dart:io';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'storage_service.dart';
import 'pdf_service.dart';

class PdfConversionService {
  static final PdfConversionService _instance = PdfConversionService._internal();
  factory PdfConversionService() => _instance;
  PdfConversionService._internal();

  final StorageService _storageService = StorageService();
  final PdfService _pdfService = PdfService();

  /// Convert PDF pages to images.
  /// If [selectedPages] is null or empty, converts all pages (1, 2, 3...).
  /// If [selectedPages] has values, converts only those 1-based page numbers.
  /// Saves each page as 1.jpg, 2.jpg... in a dedicated folder in KhubSojaDoc.
  Future<String> convertPdfToImages({
    required String pdfPath,
    List<int>? selectedPages,
    String format = 'jpg', // 'jpg' or 'png'
    int quality = 90,
    double dpi = 150,
    Function(int current, int total)? onProgress,
  }) async {
    final pdfFile = File(pdfPath);
    final pdfBytes = await pdfFile.readAsBytes();
    final totalPages = await _pdfService.getPageCount(pdfPath);

    // Determine target folder name inside KhubSojaDoc
    final originalName = pdfFile.uri.pathSegments.last;
    final folderBaseName = originalName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final appDir = await _storageService.getAppDirectory();

    var targetFolder = Directory('${appDir.path}/${folderBaseName}_images');
    int counter = 1;
    while (await targetFolder.exists()) {
      targetFolder = Directory('${appDir.path}/${folderBaseName}_images_$counter');
      counter++;
    }
    await targetFolder.create(recursive: true);

    // Determine which pages to rasterize (0-based indices)
    final List<int> pagesToProcess = [];
    if (selectedPages != null && selectedPages.isNotEmpty) {
      for (final p in selectedPages) {
        if (p >= 1 && p <= totalPages) {
          pagesToProcess.add(p - 1);
        }
      }
    } else {
      for (int i = 0; i < totalPages; i++) {
        pagesToProcess.add(i);
      }
    }

    // Process in small batches of 4 pages to ensure smooth memory management for large PDFs (20, 50, 100+ pages)
    const int batchSize = 4;
    int processed = 0;

    for (int b = 0; b < pagesToProcess.length; b += batchSize) {
      final end = (b + batchSize < pagesToProcess.length) ? b + batchSize : pagesToProcess.length;
      final batch = pagesToProcess.sublist(b, end);

      int batchIdx = 0;
      try {
        await for (final rasterPage in Printing.raster(pdfBytes, pages: batch, dpi: dpi)) {
          if (batchIdx >= batch.length) break;
          final pageNumber = batch[batchIdx] + 1; // 1-indexed (1, 2, 3...)
          final pngBytes = await rasterPage.toPng();

          final isJpg = format.toLowerCase() == 'jpg' || format.toLowerCase() == 'jpeg';
          final finalBytes = _applyWhiteBackgroundAndEncode(
            pngBytes: pngBytes,
            format: format,
            quality: quality,
          );
          final fileExt = isJpg ? 'jpg' : 'png';

          final imageFile = File('${targetFolder.path}/$pageNumber.$fileExt');
          await imageFile.writeAsBytes(finalBytes);

          batchIdx++;
          processed++;
          if (onProgress != null) {
            onProgress(processed, pagesToProcess.length);
          }
        }
      } catch (e) {
        // Fallback for this batch: try one by one so even on low memory devices all pages convert
        for (int i = batchIdx; i < batch.length; i++) {
          final singlePageIdx = batch[i];
          final pageNumber = singlePageIdx + 1;
          try {
            await for (final rasterPage in Printing.raster(pdfBytes, pages: [singlePageIdx], dpi: dpi)) {
              final pngBytes = await rasterPage.toPng();
              final isJpg = format.toLowerCase() == 'jpg' || format.toLowerCase() == 'jpeg';
              final finalBytes = _applyWhiteBackgroundAndEncode(
                pngBytes: pngBytes,
                format: format,
                quality: quality,
              );
              final fileExt = isJpg ? 'jpg' : 'png';

              final imageFile = File('${targetFolder.path}/$pageNumber.$fileExt');
              await imageFile.writeAsBytes(finalBytes);
              processed++;
              if (onProgress != null) onProgress(processed, pagesToProcess.length);
              break;
            }
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 25));
        }
      }

      // Short pause to allow Android memory/GC to reclaim native texture buffers
      await Future.delayed(const Duration(milliseconds: 40));
    }

    return targetFolder.path;
  }

  /// Composites transparent PDF page pixels over an opaque white paper canvas.
  /// Prevents transparent paper background from becoming black in JPG or dark-mode viewers.
  Uint8List _applyWhiteBackgroundAndEncode({
    required Uint8List pngBytes,
    required String format,
    required int quality,
  }) {
    final isJpg = format.toLowerCase() == 'jpg' || format.toLowerCase() == 'jpeg';
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) return pngBytes;

    final whiteCanvas = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 3, // RGB without alpha (opaque white paper)
    );
    img.fill(whiteCanvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(whiteCanvas, decoded);

    if (isJpg) {
      return Uint8List.fromList(img.encodeJpg(whiteCanvas, quality: quality.clamp(10, 100)));
    } else {
      return Uint8List.fromList(img.encodePng(whiteCanvas));
    }
  }

  /// Convert PDF to Plain Text File (.txt)
  Future<String> convertPdfToTextFile(String pdfPath, {String? customName}) async {
    final text = await _pdfService.extractText(pdfPath);
    final pdfFile = File(pdfPath);
    final originalName = pdfFile.uri.pathSegments.last.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final targetName = '${customName ?? originalName}.txt';

    final filePath = await _storageService.getAvailableFilePath(targetName);
    await File(filePath).writeAsString(text);
    return filePath;
  }

  /// Convert PDF text into a DOCX file using standard OpenXML structure
  Future<String> convertPdfToDocx(String pdfPath, {String? customName}) async {
    final text = await _pdfService.extractText(pdfPath);
    final pdfFile = File(pdfPath);
    final originalName = pdfFile.uri.pathSegments.last.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final targetName = '${customName ?? originalName}.docx';

    final filePath = await _storageService.getAvailableFilePath(targetName);

    // Build valid .docx (ZIP package with OpenXML)
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.length, contentTypes.codeUnits));

    // 2. _rels/.rels
    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRels.length, rootRels.codeUnits));

    // 3. word/document.xml with escaped paragraphs
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.writeln('<w:body>');

    final lines = text.split('\n');
    for (final line in lines) {
      final escaped = _escapeXml(line);
      buffer.writeln('  <w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>');
    }

    buffer.writeln('</w:body></w:document>');
    final docXml = buffer.toString();
    archive.addFile(ArchiveFile('word/document.xml', docXml.length, docXml.codeUnits));

    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      await File(filePath).writeAsBytes(zipData);
    }

    return filePath;
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
