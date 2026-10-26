import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:excel/excel.dart';
import 'storage_service.dart';

class OfficeService {
  static final OfficeService _instance = OfficeService._internal();
  factory OfficeService() => _instance;
  OfficeService._internal();

  final StorageService _storageService = StorageService();

  // ----------------------------------------------------
  // WORD (DOCX) MODIFICATION
  // ----------------------------------------------------

  /// Extract list of paragraphs from a DOCX file
  Future<List<String>> readDocxParagraphs(String docxPath) async {
    try {
      final bytes = await File(docxPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');

      if (docFile == null) return [];

      final content = String.fromCharCodes(docFile.content as List<int>);
      final document = XmlDocument.parse(content);

      final List<String> paragraphs = [];
      final pNodes = document.findAllElements('w:p');

      for (final p in pNodes) {
        final textNodes = p.findAllElements('w:t');
        final text = textNodes.map((t) => t.innerText).join();
        if (text.trim().isNotEmpty) {
          paragraphs.add(text);
        }
      }

      return paragraphs;
    } catch (e) {
      return ['ফাইলের কন্টেন্ট পড়তে ব্যর্থ হয়েছে: $e'];
    }
  }

  /// Save modified paragraphs into a DOCX file
  Future<String> saveDocxFile({
    required String originalPath,
    required List<String> paragraphs,
    bool saveAsNewCopy = true,
    String? newFileName,
  }) async {
    final originalBytes = await File(originalPath).readAsBytes();
    final originalArchive = ZipDecoder().decodeBytes(originalBytes);

    final newArchive = Archive();

    // Reconstruct word/document.xml with updated paragraphs
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.writeln('<w:body>');

    for (final p in paragraphs) {
      final escaped = _escapeXml(p);
      buffer.writeln('  <w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>');
    }

    buffer.writeln('</w:body></w:document>');
    final newDocXml = buffer.toString();

    // Copy all other files except document.xml
    for (final file in originalArchive.files) {
      if (file.name == 'word/document.xml') {
        newArchive.addFile(ArchiveFile('word/document.xml', newDocXml.length, newDocXml.codeUnits));
      } else {
        newArchive.addFile(file);
      }
    }

    // If word/document.xml was not present for some reason, add it
    if (newArchive.findFile('word/document.xml') == null) {
      newArchive.addFile(ArchiveFile('word/document.xml', newDocXml.length, newDocXml.codeUnits));
    }

    final encoded = ZipEncoder().encode(newArchive);
    if (encoded == null) throw Exception('DOCX সংরক্ষণ করতে ব্যর্থ');

    String targetPath;
    if (saveAsNewCopy) {
      final name = newFileName ?? 'Modified_${File(originalPath).uri.pathSegments.last}';
      targetPath = await _storageService.getAvailableFilePath(name);
    } else {
      targetPath = originalPath;
    }

    await File(targetPath).writeAsBytes(encoded);
    return targetPath;
  }

  // ----------------------------------------------------
  // EXCEL (XLSX) MODIFICATION
  // ----------------------------------------------------

  /// Load Excel sheets and grid data
  Future<Map<String, List<List<String>>>> readExcelData(String xlsxPath) async {
    try {
      final bytes = await File(xlsxPath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final Map<String, List<List<String>>> sheetsData = {};

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        final List<List<String>> rowsData = [];

        for (final row in sheet.rows) {
          final rowStrings = row.map((cell) => cell?.value?.toString() ?? '').toList();
          rowsData.add(rowStrings);
        }

        sheetsData[table] = rowsData;
      }

      return sheetsData;
    } catch (e) {
      return {};
    }
  }

  /// Save modified Excel data back to XLSX
  Future<String> saveExcelFile({
    required String originalPath,
    required Map<String, List<List<String>>> sheetsData,
    bool saveAsNewCopy = true,
    String? newFileName,
  }) async {
    final excel = Excel.createExcel();

    for (final sheetName in sheetsData.keys) {
      final rows = sheetsData[sheetName]!;
      for (int r = 0; r < rows.length; r++) {
        for (int c = 0; c < rows[r].length; c++) {
          final val = rows[r][c];
          excel.updateCell(
            sheetName,
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
            TextCellValue(val),
          );
        }
      }
    }

    // Remove default sheet if not in sheetsData
    if (!sheetsData.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final encoded = excel.encode();
    if (encoded == null) throw Exception('Excel এনকোড করতে ব্যর্থ');

    String targetPath;
    if (saveAsNewCopy) {
      final name = newFileName ?? 'Modified_${File(originalPath).uri.pathSegments.last}';
      targetPath = await _storageService.getAvailableFilePath(name);
    } else {
      targetPath = originalPath;
    }

    await File(targetPath).writeAsBytes(encoded);
    return targetPath;
  }

  // ----------------------------------------------------
  // POWERPOINT (PPTX) MODIFICATION
  // ----------------------------------------------------

  /// Extract slide texts from PPTX
  Future<List<Map<String, dynamic>>> readPptxSlides(String pptxPath) async {
    try {
      final bytes = await File(pptxPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final List<Map<String, dynamic>> slides = [];

      // Look for ppt/slides/slide*.xml
      final slideFiles = archive.files
          .where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
          .toList();

      slideFiles.sort((a, b) => a.name.compareTo(b.name));

      for (int i = 0; i < slideFiles.length; i++) {
        final f = slideFiles[i];
        final content = String.fromCharCodes(f.content as List<int>);
        final doc = XmlDocument.parse(content);

        final textNodes = doc.findAllElements('a:t');
        final texts = textNodes.map((n) => n.innerText).where((t) => t.trim().isNotEmpty).toList();

        slides.add({
          'slideNumber': i + 1,
          'fileName': f.name,
          'texts': texts,
        });
      }

      return slides;
    } catch (e) {
      return [];
    }
  }

  /// Save modified slide texts to PPTX
  Future<String> savePptxFile({
    required String originalPath,
    required List<Map<String, dynamic>> modifiedSlides,
    bool saveAsNewCopy = true,
    String? newFileName,
  }) async {
    final originalBytes = await File(originalPath).readAsBytes();
    final originalArchive = ZipDecoder().decodeBytes(originalBytes);
    final newArchive = Archive();

    final Map<String, List<String>> slideTextMap = {};
    for (final s in modifiedSlides) {
      slideTextMap[s['fileName'] as String] = List<String>.from(s['texts'] as List);
    }

    for (final file in originalArchive.files) {
      if (slideTextMap.containsKey(file.name)) {
        final newTexts = slideTextMap[file.name]!;
        final content = String.fromCharCodes(file.content as List<int>);
        final doc = XmlDocument.parse(content);

        final textNodes = doc.findAllElements('a:t').toList();
        for (int i = 0; i < textNodes.length && i < newTexts.length; i++) {
          textNodes[i].innerText = newTexts[i];
        }

        final updatedXml = doc.toXmlString();
        newArchive.addFile(ArchiveFile(file.name, updatedXml.length, updatedXml.codeUnits));
      } else {
        newArchive.addFile(file);
      }
    }

    final encoded = ZipEncoder().encode(newArchive);
    if (encoded == null) throw Exception('PPTX এনকোড করতে ব্যর্থ');

    String targetPath;
    if (saveAsNewCopy) {
      final name = newFileName ?? 'Modified_${File(originalPath).uri.pathSegments.last}';
      targetPath = await _storageService.getAvailableFilePath(name);
    } else {
      targetPath = originalPath;
    }

    await File(targetPath).writeAsBytes(encoded);
    return targetPath;
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
