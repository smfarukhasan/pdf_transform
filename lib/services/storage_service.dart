import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import '../models/document_file.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Directory? _appMainDirectory;

  /// Get or initialize the primary KhubSojaDoc directory
  Future<Directory> getAppDirectory() async {
    if (_appMainDirectory != null && await _appMainDirectory!.exists()) {
      return _appMainDirectory!;
    }

    try {
      if (Platform.isAndroid) {
        // Attempt external public Documents or Downloads folder first
        final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
        Directory? targetDir;

        // Try standard Android 12+ public Documents path
        final publicDocDir = Directory('/storage/emulated/0/Documents/${AppConstants.appFolderName}');
        final publicDownloadDir = Directory('/storage/emulated/0/Download/${AppConstants.appFolderName}');

        try {
          if (await Permission.manageExternalStorage.isGranted ||
              await Permission.storage.isGranted) {
            if (!await publicDocDir.exists()) {
              await publicDocDir.create(recursive: true);
            }
            targetDir = publicDocDir;
          }
        } catch (_) {}

        if (targetDir == null || !await targetDir.exists()) {
          try {
            if (!await publicDownloadDir.exists()) {
              await publicDownloadDir.create(recursive: true);
            }
            targetDir = publicDownloadDir;
          } catch (_) {}
        }

        if (targetDir == null || !await targetDir.exists()) {
          if (externalDirs != null && externalDirs.isNotEmpty) {
            final appExtDir = Directory('${externalDirs.first.path}/${AppConstants.appFolderName}');
            if (!await appExtDir.exists()) {
              await appExtDir.create(recursive: true);
            }
            targetDir = appExtDir;
          }
        }

        if (targetDir != null && await targetDir.exists()) {
          _appMainDirectory = targetDir;
          return _appMainDirectory!;
        }
      }

      // Default fallback to application documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final dedicatedDir = Directory('${appDocDir.path}/${AppConstants.appFolderName}');
      if (!await dedicatedDir.exists()) {
        await dedicatedDir.create(recursive: true);
      }
      _appMainDirectory = dedicatedDir;
      return _appMainDirectory!;
    } catch (e) {
      final fallback = await getApplicationDocumentsDirectory();
      final dir = Directory('${fallback.path}/${AppConstants.appFolderName}');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _appMainDirectory = dir;
      return _appMainDirectory!;
    }
  }

  /// Request storage and media permissions for Android 12+ (minSdk 31)
  Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      // Android 11+ (API 30+) manage external storage check
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // Check media permissions for Android 13+ / 12+
      final photos = await Permission.photos.request();
      final storage = await Permission.storage.request();

      if (photos.isGranted || storage.isGranted) {
        return true;
      }

      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// List all files in the KhubSojaDoc folder
  Future<List<DocumentFile>> getKhubSojaDocFiles() async {
    final dir = await getAppDirectory();
    final List<DocumentFile> list = [];

    try {
      final entities = dir.listSync(recursive: false);
      for (final entity in entities) {
        if (entity is File) {
          final doc = DocumentFile.fromFile(entity);
          if (AppConstants.supportedExtensions.contains(doc.extension)) {
            list.add(doc);
          }
        }
      }
    } catch (_) {}

    list.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
    return list;
  }

  /// Scan common device storage locations for PDFs and documents
  Future<List<DocumentFile>> scanDeviceDocuments() async {
    final List<DocumentFile> results = [];
    final Set<String> seenPaths = {};

    // 1. Files in KhubSojaDoc
    final appFiles = await getKhubSojaDocFiles();
    for (final f in appFiles) {
      if (seenPaths.add(f.path)) {
        results.add(f);
      }
    }

    // 2. Common directories on device
    final List<String> searchDirectories = [];
    if (Platform.isAndroid) {
      searchDirectories.addAll([
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Documents/KhubSojaDoc',
        '/storage/emulated/0/Download/KhubSojaDoc',
      ]);

      try {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (final d in extDirs) {
            searchDirectories.add(d.path);
          }
        }
      } catch (_) {}
    }

    try {
      final appDoc = await getApplicationDocumentsDirectory();
      searchDirectories.add(appDoc.path);
    } catch (_) {}

    for (final dirPath in searchDirectories) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          final entities = dir.listSync(recursive: false);
          for (final entity in entities) {
            if (entity is File) {
              final doc = DocumentFile.fromFile(entity);
              if (AppConstants.supportedExtensions.contains(doc.extension)) {
                if (seenPaths.add(doc.path)) {
                  results.add(doc);
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    // Sort by modified date descending (newest first)
    results.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
    return results;
  }

  /// Helper to generate a unique file path inside KhubSojaDoc or custom dir
  Future<String> getAvailableFilePath(String desiredName, {String? customDirPath}) async {
    final baseDir = customDirPath != null ? Directory(customDirPath) : await getAppDirectory();
    String candidate = '${baseDir.path}/$desiredName';
    int counter = 1;

    final dotIndex = desiredName.lastIndexOf('.');
    final nameWithoutExt = dotIndex != -1 ? desiredName.substring(0, dotIndex) : desiredName;
    final ext = dotIndex != -1 ? desiredName.substring(dotIndex) : '';

    while (await File(candidate).exists()) {
      candidate = '${baseDir.path}/${nameWithoutExt}_$counter$ext';
      counter++;
    }

    return candidate;
  }
}
