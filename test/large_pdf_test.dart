import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List applyWhiteBackgroundAndEncode({
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
    numChannels: 3,
  );
  img.fill(whiteCanvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(whiteCanvas, decoded);

  if (isJpg) {
    return Uint8List.fromList(img.encodeJpg(whiteCanvas, quality: quality.clamp(10, 100)));
  } else {
    return Uint8List.fromList(img.encodePng(whiteCanvas));
  }
}

void main() {
  test('Test transparent PDF page converts to white JPG without becoming black', () {
    // Simulating transparent PDF page
    final transparentPage = img.Image(width: 200, height: 200, numChannels: 4);
    img.fill(transparentPage, color: img.ColorRgba8(0, 0, 0, 0)); // transparent
    // Black text on transparent page
    img.drawString(transparentPage, 'Hello PDF', font: img.arial14, x: 20, y: 20, color: img.ColorRgba8(0, 0, 0, 255));

    final rawPng = img.encodePng(transparentPage);

    // 1. Process as JPG
    final jpgBytes = applyWhiteBackgroundAndEncode(pngBytes: rawPng, format: 'jpg', quality: 90);
    final decodedJpg = img.decodeJpg(jpgBytes)!;

    // Check corner pixel (background)
    final bgPixel = decodedJpg.getPixel(5, 5);
    expect(bgPixel.r, greaterThan(250), reason: 'JPG background must be white, not black');
    expect(bgPixel.g, greaterThan(250));
    expect(bgPixel.b, greaterThan(250));

    // 2. Process as PNG
    final pngResult = applyWhiteBackgroundAndEncode(pngBytes: rawPng, format: 'png', quality: 90);
    final decodedPng = img.decodePng(pngResult)!;

    final bgPixelPng = decodedPng.getPixel(5, 5);
    expect(bgPixelPng.r, equals(255), reason: 'PNG background must be white, not transparent/black');
    expect(bgPixelPng.g, equals(255));
    expect(bgPixelPng.b, equals(255));
  });
}
