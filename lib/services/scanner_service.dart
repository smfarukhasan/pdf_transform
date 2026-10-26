import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'storage_service.dart';

enum ScanFilter {
  original,
  grayscale,
  documentBw,
}

class ScannerPage {
  final String id;
  final Uint8List originalBytes;
  Uint8List processedBytes;
  ScanFilter filter;
  int rotationAngle; // 0, 90, 180, 270

  ScannerPage({
    required this.id,
    required this.originalBytes,
    required this.processedBytes,
    this.filter = ScanFilter.original,
    this.rotationAngle = 0,
  });
}

class ScannerService {
  static final ScannerService _instance = ScannerService._internal();
  factory ScannerService() => _instance;
  ScannerService._internal();

  final StorageService _storageService = StorageService();

  /// Apply color or B&W document filter to page image
  Uint8List applyFilter(Uint8List inputBytes, ScanFilter filter) {
    if (filter == ScanFilter.original) return inputBytes;

    final image = img.decodeImage(inputBytes);
    if (image == null) return inputBytes;

    if (filter == ScanFilter.grayscale) {
      final gray = img.grayscale(image);
      return Uint8List.fromList(img.encodeJpg(_ensureOpaqueWhite(gray), quality: 90));
    } else if (filter == ScanFilter.documentBw) {
      // Document black & white contrast enhancement
      final gray = img.grayscale(image);
      final contrast = img.adjustColor(gray, contrast: 1.5, brightness: 1.1);
      return Uint8List.fromList(img.encodeJpg(_ensureOpaqueWhite(contrast), quality: 85));
    }

    return inputBytes;
  }

  /// Rotate page image
  Uint8List rotateImage(Uint8List inputBytes, int angle) {
    final image = img.decodeImage(inputBytes);
    if (image == null) return inputBytes;

    final rotated = img.copyRotate(image, angle: angle);
    return Uint8List.fromList(img.encodeJpg(_ensureOpaqueWhite(rotated), quality: 90));
  }

  img.Image _ensureOpaqueWhite(img.Image src) {
    if (!src.hasAlpha) return src;
    final whiteCanvas = img.Image(width: src.width, height: src.height, numChannels: 3);
    img.fill(whiteCanvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(whiteCanvas, src);
    return whiteCanvas;
  }

  /// Create a PDF document from scanned pages
  Future<String> buildPdfFromScannedPages({
    required List<ScannerPage> pages,
    required String pdfFileName,
    String? customDirPath,
  }) async {
    final pdfDoc = PdfDocument();
    pdfDoc.pageSettings.margins.all = 0;

    for (final page in pages) {
      final pdfPage = pdfDoc.pages.add();
      final bitmap = PdfBitmap(page.processedBytes);
      final clientSize = pdfPage.getClientSize();

      pdfPage.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, clientSize.width, clientSize.height),
      );
    }

    final output = await pdfDoc.save();
    pdfDoc.dispose();

    final targetPath = await _storageService.getAvailableFilePath(
      pdfFileName.endsWith('.pdf') ? pdfFileName : '$pdfFileName.pdf',
      customDirPath: customDirPath,
    );

    await File(targetPath).writeAsBytes(output);
    return targetPath;
  }
}
