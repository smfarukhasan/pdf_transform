import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  /// Get page count of a PDF file
  Future<int> getPageCount(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();
      return count;
    } catch (e) {
      return 1;
    }
  }

  /// Extract text from a PDF file
  Future<String> extractText(String filePath, {int? pageIndex}) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(doc);

      String result = '';
      if (pageIndex != null && pageIndex >= 0 && pageIndex < doc.pages.count) {
        result = extractor.extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
      } else {
        result = extractor.extractText();
      }

      doc.dispose();
      return result;
    } catch (e) {
      return 'টেক্সট এক্সট্র্যাক্ট করতে ব্যর্থ হয়েছে: $e';
    }
  }

  /// Render a specific PDF page to Image bytes (PNG)
  Future<Uint8List?> renderPageToImage({
    required Uint8List pdfBytes,
    required int pageIndex,
    double dpi = 150,
  }) async {
    try {
      await for (final page in Printing.raster(pdfBytes, pages: [pageIndex], dpi: dpi)) {
        return await page.toPng();
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  /// Remove specified page indices (0-indexed) and save
  Future<Uint8List> removePages({
    required Uint8List originalBytes,
    required List<int> pagesToRemoveIndices,
  }) async {
    final doc = PdfDocument(inputBytes: originalBytes);

    // Sort descending so indices don't shift when removing
    final sortedIndices = List<int>.from(pagesToRemoveIndices)
      ..sort((a, b) => b.compareTo(a));

    for (final index in sortedIndices) {
      if (index >= 0 && index < doc.pages.count) {
        doc.pages.removeAt(index);
      }
    }

    final output = await doc.save();
    doc.dispose();
    return Uint8List.fromList(output);
  }

  /// Insert an image as a new page at targetIndex
  Future<Uint8List> insertImagePage({
    required Uint8List originalBytes,
    required Uint8List imageBytes,
    int? targetIndex,
  }) async {
    final doc = PdfDocument(inputBytes: originalBytes);
    final target = targetIndex ?? doc.pages.count;

    final page = doc.pages.insert(target);
    final bitmap = PdfBitmap(imageBytes);

    // Fit image on page
    final pageSize = page.getClientSize();
    page.graphics.drawImage(
      bitmap,
      Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
    );

    final output = await doc.save();
    doc.dispose();
    return Uint8List.fromList(output);
  }

  /// Insert a blank page with optional title or note
  Future<Uint8List> insertBlankPage({
    required Uint8List originalBytes,
    int? targetIndex,
    String? noteText,
  }) async {
    final doc = PdfDocument(inputBytes: originalBytes);
    final target = targetIndex ?? doc.pages.count;

    final page = doc.pages.insert(target);
    if (noteText != null && noteText.trim().isNotEmpty) {
      final font = PdfStandardFont(PdfFontFamily.helvetica, 16);
      page.graphics.drawString(
        noteText,
        font,
        bounds: Rect.fromLTWH(40, 50, page.getClientSize().width - 80, 400),
      );
    }

    final output = await doc.save();
    doc.dispose();
    return Uint8List.fromList(output);
  }

  /// Merge another PDF into the current PDF
  Future<Uint8List> mergePdf({
    required Uint8List originalBytes,
    required Uint8List bytesToMerge,
    int? insertAt,
  }) async {
    final doc1 = PdfDocument(inputBytes: originalBytes);
    final doc2 = PdfDocument(inputBytes: bytesToMerge);

    final target = insertAt ?? doc1.pages.count;
    for (int i = 0; i < doc2.pages.count; i++) {
      final template = doc2.pages[i].createTemplate();
      final newPage = doc1.pages.insert(target + i);
      newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
    }

    final output = await doc1.save();
    doc1.dispose();
    doc2.dispose();
    return Uint8List.fromList(output);
  }

  /// Reorder pages according to a new order of indices
  Future<Uint8List> reorderPages({
    required Uint8List originalBytes,
    required List<int> newOrderIndices,
  }) async {
    final sourceDoc = PdfDocument(inputBytes: originalBytes);
    final newDoc = PdfDocument();

    for (final index in newOrderIndices) {
      if (index >= 0 && index < sourceDoc.pages.count) {
        final template = sourceDoc.pages[index].createTemplate();
        final newPage = newDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
    }

    final output = await newDoc.save();
    sourceDoc.dispose();
    newDoc.dispose();
    return Uint8List.fromList(output);
  }

  /// Rotate specific page by 90 degrees clockwise
  Future<Uint8List> rotatePage({
    required Uint8List originalBytes,
    required int pageIndex,
  }) async {
    final doc = PdfDocument(inputBytes: originalBytes);
    if (pageIndex >= 0 && pageIndex < doc.pages.count) {
      final page = doc.pages[pageIndex];
      final currentRotation = page.rotation;
      PdfPageRotateAngle next;
      switch (currentRotation) {
        case PdfPageRotateAngle.rotateAngle0:
          next = PdfPageRotateAngle.rotateAngle90;
          break;
        case PdfPageRotateAngle.rotateAngle90:
          next = PdfPageRotateAngle.rotateAngle180;
          break;
        case PdfPageRotateAngle.rotateAngle180:
          next = PdfPageRotateAngle.rotateAngle270;
          break;
        case PdfPageRotateAngle.rotateAngle270:
          next = PdfPageRotateAngle.rotateAngle0;
          break;
      }
      page.rotation = next;
    }

    final output = await doc.save();
    doc.dispose();
    return Uint8List.fromList(output);
  }

  /// Save PDF with quality/compression options
  Future<Uint8List> compressOrOptimize({
    required Uint8List originalBytes,
    required String qualityPreset,
  }) async {
    final doc = PdfDocument(inputBytes: originalBytes);
    if (qualityPreset.contains('Compressed') || qualityPreset.contains('ছোট সাইজ')) {
      doc.compressionLevel = PdfCompressionLevel.best;
    } else if (qualityPreset.contains('High') || qualityPreset.contains('হাই')) {
      doc.compressionLevel = PdfCompressionLevel.none;
    } else {
      doc.compressionLevel = PdfCompressionLevel.normal;
    }

    final output = await doc.save();
    doc.dispose();
    return Uint8List.fromList(output);
  }
}
