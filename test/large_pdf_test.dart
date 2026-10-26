import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

enum TestScanFilter { original, grayscale, documentBw }

Uint8List processImageFilter({
  required Uint8List inputBytes,
  required TestScanFilter filter,
  required int rotationAngle,
}) {
  var image = img.decodeImage(inputBytes);
  if (image == null) return inputBytes;

  if (image.width > 2048 || image.height > 2048) {
    image = img.copyResize(
      image,
      width: image.width > image.height ? 2048 : (image.width * 2048 ~/ image.height),
      height: image.height >= image.width ? 2048 : (image.height * 2048 ~/ image.width),
      interpolation: img.Interpolation.linear,
    );
  }

  if (rotationAngle != 0) {
    image = img.copyRotate(image, angle: rotationAngle);
  }

  if (filter == TestScanFilter.grayscale) {
    image = img.grayscale(image);
  } else if (filter == TestScanFilter.documentBw) {
    final gray = img.grayscale(image);
    image = img.adjustColor(gray, contrast: 1.45, brightness: 1.12);
  }

  final whiteCanvas = img.Image(width: image.width, height: image.height, numChannels: 3);
  img.fill(whiteCanvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(whiteCanvas, image);

  return Uint8List.fromList(img.encodeJpg(whiteCanvas, quality: 88));
}

void main() {
  test('Test processImageFilter runs in Isolate without blocking and returns valid white background', () async {
    final sampleImg = img.Image(width: 400, height: 600, numChannels: 4);
    img.fill(sampleImg, color: img.ColorRgba8(0, 0, 0, 0));
    img.drawString(sampleImg, 'Invoice #1024', font: img.arial14, x: 50, y: 50, color: img.ColorRgba8(0, 0, 0, 255));
    final rawPng = img.encodePng(sampleImg);

    final result = await Isolate.run(() {
      return processImageFilter(
        inputBytes: rawPng,
        filter: TestScanFilter.documentBw,
        rotationAngle: 0,
      );
    });

    final decoded = img.decodeJpg(result)!;
    expect(decoded.width, equals(400));
    expect(decoded.height, equals(600));

    final p0 = decoded.getPixel(5, 5);
    expect(p0.r, greaterThan(250), reason: 'Document B&W must have white paper background');
  });
}
