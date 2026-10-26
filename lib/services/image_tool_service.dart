import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'storage_service.dart';

class ImageToolService {
  static final ImageToolService _instance = ImageToolService._internal();
  factory ImageToolService() => _instance;
  ImageToolService._internal();

  final StorageService _storageService = StorageService();

  /// Resize an image
  Uint8List resizeImage({
    required Uint8List inputBytes,
    required int targetWidth,
    required int targetHeight,
    img.Interpolation interpolation = img.Interpolation.linear,
  }) {
    final image = img.decodeImage(inputBytes);
    if (image == null) throw Exception('ইমেজ ডিকোড করতে ব্যর্থ');

    final resized = img.copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
      interpolation: interpolation,
    );

    return Uint8List.fromList(img.encodeJpg(_ensureOpaqueWhite(resized), quality: 90));
  }

  /// Crop an image
  Uint8List cropImage({
    required Uint8List inputBytes,
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    final image = img.decodeImage(inputBytes);
    if (image == null) throw Exception('ইমেজ ডিকোড করতে ব্যর্থ');

    final cropped = img.copyCrop(
      image,
      x: x.clamp(0, image.width - 1),
      y: y.clamp(0, image.height - 1),
      width: width.clamp(1, image.width - x),
      height: height.clamp(1, image.height - y),
    );

    return Uint8List.fromList(img.encodeJpg(_ensureOpaqueWhite(cropped), quality: 90));
  }

  /// Compress image to target quality (1 - 100) or format
  Uint8List compressImage({
    required Uint8List inputBytes,
    required int quality,
    bool asPng = false,
  }) {
    final image = img.decodeImage(inputBytes);
    if (image == null) throw Exception('ইমেজ ডিকোড করতে ব্যর্থ');

    if (asPng) {
      return Uint8List.fromList(img.encodePng(image, level: (9 - (quality * 9 ~/ 100)).clamp(0, 9)));
    } else {
      return Uint8List.fromList(img.encodeJpg(_ensureOpaqueWhite(image), quality: quality.clamp(5, 100)));
    }
  }

  /// Compress image until it meets a target KB size limit
  Uint8List compressToTargetKb({
    required Uint8List inputBytes,
    required int targetKb,
  }) {
    final image = img.decodeImage(inputBytes);
    if (image == null) return inputBytes;

    final baseImage = _ensureOpaqueWhite(image);
    int quality = 90;
    Uint8List current = Uint8List.fromList(img.encodeJpg(baseImage, quality: quality));

    while (current.lengthInBytes > targetKb * 1024 && quality > 15) {
      quality -= 10;
      current = Uint8List.fromList(img.encodeJpg(baseImage, quality: quality));
    }

    // If still too big, downscale dimension
    if (current.lengthInBytes > targetKb * 1024) {
      var resized = baseImage;
      while (current.lengthInBytes > targetKb * 1024 && resized.width > 200) {
        final newW = (resized.width * 0.8).toInt();
        final newH = (resized.height * 0.8).toInt();
        resized = img.copyResize(resized, width: newW, height: newH);
        current = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
      }
    }

    return current;
  }

  img.Image _ensureOpaqueWhite(img.Image src) {
    if (!src.hasAlpha) return src;
    final whiteCanvas = img.Image(width: src.width, height: src.height, numChannels: 3);
    img.fill(whiteCanvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(whiteCanvas, src);
    return whiteCanvas;
  }

  /// Save processed image to KhubSojaDoc or custom path
  Future<String> saveImage({
    required Uint8List imageBytes,
    required String fileName,
    String? customDirPath,
  }) async {
    final path = await _storageService.getAvailableFilePath(fileName, customDirPath: customDirPath);
    await File(path).writeAsBytes(imageBytes);
    return path;
  }
}
