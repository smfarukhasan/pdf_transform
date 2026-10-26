import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/draft_item.dart';

class DraftService {
  static final DraftService _instance = DraftService._internal();
  factory DraftService() => _instance;
  DraftService._internal();

  /// Save or update an incomplete work draft
  Future<void> saveDraft(DraftItem draft) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyDrafts) ?? [];

    // Remove existing with same id if any
    list.removeWhere((item) {
      try {
        final decoded = json.decode(item);
        return decoded['id'] == draft.id;
      } catch (_) {
        return false;
      }
    });

    list.insert(0, draft.toJson());
    await prefs.setStringList(AppConstants.keyDrafts, list);
  }

  /// Get all active drafts
  Future<List<DraftItem>> getAllDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyDrafts) ?? [];
    final List<DraftItem> drafts = [];

    for (final str in list) {
      try {
        drafts.add(DraftItem.fromJson(str));
      } catch (_) {}
    }

    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  /// Delete a draft by ID
  Future<void> deleteDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(AppConstants.keyDrafts) ?? [];

    list.removeWhere((item) {
      try {
        final decoded = json.decode(item);
        return decoded['id'] == id;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(AppConstants.keyDrafts, list);
  }

  /// Clear all drafts
  Future<void> clearAllDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyDrafts);
  }
}
