import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../models/document_file.dart';
import '../../services/storage_service.dart';
import '../reader/document_reader_screen.dart';

class KhubSojaDocFolderScreen extends StatefulWidget {
  const KhubSojaDocFolderScreen({super.key});

  @override
  State<KhubSojaDocFolderScreen> createState() => _KhubSojaDocFolderScreenState();
}

class _KhubSojaDocFolderScreenState extends State<KhubSojaDocFolderScreen> {
  final StorageService _storageService = StorageService();

  Directory? _appDir;
  List<DocumentFile> _files = [];
  bool _isLoading = true;
  int _totalSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoading = true);
    final dir = await _storageService.getAppDirectory();
    final fileList = await _storageService.getKhubSojaDocFiles();

    int totalSize = 0;
    for (final f in fileList) {
      totalSize += f.sizeInBytes;
    }

    if (mounted) {
      setState(() {
        _appDir = dir;
        _files = fileList;
        _totalSizeBytes = totalSize;
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _openFile(DocumentFile f) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentReaderScreen(
          filePath: f.path,
          fileName: f.name,
        ),
      ),
    ).then((_) => _loadDirectory());
  }

  void _shareFile(DocumentFile f) {
    SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: f.name));
  }

  void _deleteFile(DocumentFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ফাইল ডিলিট করবেন?'),
        content: Text('আপনি কি নিশ্চিত যে "${f.name}" ফাইলটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ডিলিট', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await File(f.path).delete();
        _loadDirectory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ফাইলটি মুছে ফেলা হয়েছে')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ডিলিট করতে ব্যর্থ: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KhubSojaDoc ফোল্ডার', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_appDir != null)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'সিস্টেমে ওপেন',
              onPressed: () => OpenFilex.open(_appDir!.path),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'রিফ্রেশ',
            onPressed: _loadDirectory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Folder Info Header Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_special, color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'KhubSojaDoc ডেডিকেটেড ফোল্ডার',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_files.length} টি ফাইল',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _appDir?.path ?? '',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'মোট সাইজ: ${_formatSize(_totalSizeBytes)}',
                        style: const TextStyle(color: AppColors.accentLight, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // File List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('এই ফোল্ডারের সমস্ত ফাইল:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Text('${_files.length} items', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),

                // File List
                Expanded(
                  child: _files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('এখনও কোনো ফাইল তৈরি হয়নি', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text(
                                'অ্যাপ থেকে যেকোনো কাজ সেভ করলে সরাসরি এখানে জমা হবে।',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _files.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final f = _files[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _getFileColor(f).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_getFileIcon(f), color: _getFileColor(f), size: 22),
                              ),
                              title: Text(
                                f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                              subtitle: Text(
                                '${f.formattedSize} • ${DateFormat('dd MMM, hh:mm a').format(f.modifiedDate)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share, size: 18, color: AppColors.primary),
                                    onPressed: () => _shareFile(f),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    onPressed: () => _deleteFile(f),
                                  ),
                                ],
                              ),
                              onTap: () => _openFile(f),
                            );
                          },
                        ),
                ),
              ],
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
