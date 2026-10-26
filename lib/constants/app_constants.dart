class AppConstants {
  // Folder Name required by user
  static const String appFolderName = 'KhubSojaDoc';

  // Storage Keys
  static const String keyRecentFiles = 'recent_files_history_v1';
  static const String keyBookmarks = 'bookmarks_history_v1';
  static const String keyDrafts = 'incomplete_work_drafts_v1';
  static const String keyCustomLocation = 'custom_save_location_v1';

  // Export Quality Presets
  static const String qualityHigh = 'হাই (High Quality)';
  static const String qualityStandard = 'স্বাভাবিক (Standard)';
  static const String qualityCompressed = 'কম্প্রেশন/ছোট সাইজ (Compressed)';

  // Supported File Extensions
  static const List<String> supportedExtensions = [
    'pdf',
    'docx',
    'doc',
    'xlsx',
    'xls',
    'pptx',
    'ppt',
    'txt',
    'jpg',
    'jpeg',
    'png'
  ];
}
