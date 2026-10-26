import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/document_file.dart';
import '../../services/storage_service.dart';
import '../../services/recent_service.dart';
import 'document_reader_screen.dart';

class FileBrowserModal extends StatefulWidget {
  const FileBrowserModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FileBrowserModal(),
    );
  }

  @override
  State<FileBrowserModal> createState() => _FileBrowserModalState();
}

class _FileBrowserModalState extends State<FileBrowserModal> {
  final StorageService _storageService = StorageService();
  final RecentService _recentService = RecentService();

  List<DocumentFile> _allFiles = [];
  List<DocumentFile> _filteredFiles = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _sortBy = 'date_desc'; // 'date_desc', 'date_asc', 'name_asc', 'name_desc'
  String _filterType = 'all'; // 'all', 'pdf', 'word', 'excel', 'pptx', 'image'

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    await _storageService.requestStoragePermissions();
    final files = await _storageService.scanDeviceDocuments();
    if (mounted) {
      setState(() {
        _allFiles = files;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    var result = List<DocumentFile>.from(_allFiles);

    // Filter by type
    if (_filterType != 'all') {
      result = result.where((f) {
        if (_filterType == 'pdf') return f.isPdf;
        if (_filterType == 'word') return f.isWord;
        if (_filterType == 'excel') return f.isExcel;
        if (_filterType == 'pptx') return f.isPpt;
        if (_filterType == 'image') return f.isImage;
        return true;
      }).toList();
    }

    // Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((f) => f.name.toLowerCase().contains(q)).toList();
    }

    // Sorting
    if (_sortBy == 'date_desc') {
      result.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
    } else if (_sortBy == 'date_asc') {
      result.sort((a, b) => a.modifiedDate.compareTo(b.modifiedDate));
    } else if (_sortBy == 'name_asc') {
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortBy == 'name_desc') {
      result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    _filteredFiles = result;
  }

  Future<void> _pickViaSystemFileManager() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      final size = result.files.single.size;

      await _recentService.recordFileOpened(
        filePath: path,
        fileName: name,
        fileSize: size,
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentReaderScreen(
              filePath: path,
              fileName: name,
            ),
          ),
        );
      }
    }
  }

  void _openFile(DocumentFile file) async {
    await _recentService.recordFileOpened(
      filePath: file.path,
      fileName: file.name,
      fileSize: file.sizeInBytes,
    );

    if (mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentReaderScreen(
            filePath: file.path,
            fileName: file.name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'ফোনের সব ফাইল ওপেন করুন',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _pickViaSystemFileManager,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('ফাইল ম্যানেজার', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ফাইলের নাম দিয়ে সার্চ করুন...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilters();
                });
              },
            ),
          ),

          // Filters and Sorting Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Sort Menu
                PopupMenuButton<String>(
                  initialValue: _sortBy,
                  onSelected: (val) {
                    setState(() {
                      _sortBy = val;
                      _applyFilters();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'date_desc', child: Text('নতুন ফাইল আগে (Date ↓)')),
                    const PopupMenuItem(value: 'date_asc', child: Text('পুরাতন ফাইল আগে (Date ↑)')),
                    const PopupMenuItem(value: 'name_asc', child: Text('নাম অনুসারে (A - Z)')),
                    const PopupMenuItem(value: 'name_desc', child: Text('নাম অনুসারে (Z - A)')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sort, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          _sortBy.contains('date') ? 'তারিখ' : 'নাম',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Format filter chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('সব', 'all'),
                        _buildFilterChip('PDF', 'pdf'),
                        _buildFilterChip('Word', 'word'),
                        _buildFilterChip('Excel', 'excel'),
                        _buildFilterChip('PPT', 'pptx'),
                        _buildFilterChip('Image', 'image'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // File List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 50, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              'কোনো ফাইল পাওয়া যায়নি',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredFiles.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
                        itemBuilder: (context, index) {
                          final file = _filteredFiles[index];
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _getFileColor(file).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_getFileIcon(file), color: _getFileColor(file), size: 22),
                            ),
                            title: Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            subtitle: Text(
                              '${file.formattedSize} • ${DateFormat('dd MMM yyyy, hh:mm a').format(file.modifiedDate)}',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
                            onTap: () => _openFile(file),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : AppColors.textPrimary)),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.grey.shade100,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onSelected: (val) {
          setState(() {
            _filterType = type;
            _applyFilters();
          });
        },
      ),
    );
  }

  IconData _getFileIcon(DocumentFile f) {
    if (f.isPdf) return Icons.picture_as_pdf;
    if (f.isWord) return Icons.description;
    if (f.isExcel) return Icons.table_chart;
    if (f.isPpt) return Icons.slideshow;
    if (f.isImage) return Icons.image;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(DocumentFile f) {
    if (f.isPdf) return Colors.red.shade700;
    if (f.isWord) return Colors.blue.shade700;
    if (f.isExcel) return Colors.green.shade700;
    if (f.isPpt) return Colors.orange.shade800;
    if (f.isImage) return Colors.purple.shade600;
    return Colors.blueGrey;
  }
}
