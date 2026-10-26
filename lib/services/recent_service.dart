import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/recent_item.dart';
import '../models/bookmark_item.dart';

class RecentService {
  static final RecentService _instance = RecentService._internal();
  factory RecentService() => _instance;
  RecentService._internal();

  /// Add or update file in recent reading list
  Future<void> recordFileOpened({
    required String filePath,
    required String fileName,
    int lastPage = 1,
    int totalPages = 1,
    int fileSize = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyRecentFiles) ?? [];

    final id = filePath.hashCode.toString();
    list.removeWhere((item) {
      try {
        final decoded = json.decode(item);
        return decoded['filePath'] == filePath;
      } catch (_) {
        return false;
      }
    });

    final item = RecentItem(
      id: id,
      filePath: filePath,
      fileName: fileName,
      lastPage: lastPage,
      totalPages: totalPages,
      lastReadTime: DateTime.now(),
      fileSize: fileSize,
    );

    list.insert(0, item.toJson());

    // Keep top 50 recent items
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }

    await prefs.setStringList(AppConstants.keyRecentFiles, list);
  }

  /// Update reading progress (last page)
  Future<void> updateReadingProgress(String filePath, int page, int totalPages) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyRecentFiles) ?? [];

    for (int i = 0; i < list.length; i++) {
      try {
        final map = json.decode(list[i]);
        if (map['filePath'] == filePath) {
          map['lastPage'] = page;
          if (totalPages > 0) map['totalPages'] = totalPages;
          map['lastReadTime'] = DateTime.now().toIso8601String();
          list[i] = json.encode(map);
          break;
        }
      } catch (_) {}
    }

    await prefs.setStringList(AppConstants.keyRecentFiles, list);
  }

  /// Get list of recent items
  Future<List<RecentItem>> getRecentItems() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyRecentFiles) ?? [];
    final List<RecentItem> items = [];

    for (final str in list) {
      try {
        items.add(RecentItem.fromJson(str));
      } catch (_) {}
    }

    return items;
  }

  /// Remove item from recent list ONLY (does NOT delete actual file)
  Future<void> removeFromRecent(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyRecentFiles) ?? [];

    list.removeWhere((item) {
      try {
        final decoded = json.decode(item);
        return decoded['filePath'] == filePath;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(AppConstants.keyRecentFiles, list);
  }

  /// Clear all recent items
  Future<void> clearAllRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyRecentFiles);
  }

  // Bookmarking Feature
  Future<void> addBookmark(BookmarkItem bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyBookmarks) ?? [];

    // Remove duplicates for same page in same file
    list.removeWhere((item) {
      try {
        final decoded = json.decode(item);
        return decoded['filePath'] == bookmark.filePath &&
            decoded['pageNumber'] == bookmark.pageNumber;
      } catch (_) {
        return false;
      }
    });

    list.insert(0, bookmark.toJson());
    await prefs.setStringList(AppConstants.keyBookmarks, list);
  }

  Future<List<BookmarkItem>> getBookmarksForFile(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyBookmarks) ?? [];
    final List<BookmarkItem> results = [];

    for (final str in list) {
      try {
        final b = BookmarkItem.fromJson(str);
        if (b.filePath == filePath) {
          results.add(b);
        }
      } catch (_) {}
    }

    results.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return results;
  }

  Future<void> removeBookmark(String bookmarkId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyBookmarks) ?? [];

    list.removeWhere((item) {
      try {
        final decoded = json.decode(item);
        return decoded['id'] == bookmarkId;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(AppConstants.keyBookmarks, list);
  }
}
