import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../constants/app_colors.dart';
import '../../models/draft_item.dart';
import '../../services/pdf_service.dart';
import '../../services/draft_service.dart';
import '../../services/storage_service.dart';
import '../common/save_export_dialog.dart';

class PageItemModel {
  final int originalIndex; // 0-based
  int displayOrder;
  Uint8List? thumbnail;
  bool isDeleted;
  bool isNewlyAdded;
  Uint8List? newlyAddedImageBytes;
  String? newlyAddedText;
  int rotation;

  PageItemModel({
    required this.originalIndex,
    required this.displayOrder,
    this.thumbnail,
    this.isDeleted = false,
    this.isNewlyAdded = false,
    this.newlyAddedImageBytes,
    this.newlyAddedText,
    this.rotation = 0,
  });
}

class PdfEditorScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final DraftItem? draftToResume;

  const PdfEditorScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.draftToResume,
  });

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final PdfService _pdfService = PdfService();
  final DraftService _draftService = DraftService();
  final StorageService _storageService = StorageService();

  late Uint8List _originalPdfBytes;
  List<PageItemModel> _pages = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  late String _draftId;

  final Set<int> _selectedPagesToDelete = {};

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftToResume?.id ?? 'draft_pdf_${DateTime.now().millisecondsSinceEpoch}';
    _loadPdfPages();
  }

  Future<void> _loadPdfPages() async {
    setState(() => _isLoading = true);
    try {
      final file = File(widget.filePath);
      _originalPdfBytes = await file.readAsBytes();
      final total = await _pdfService.getPageCount(widget.filePath);

      final List<PageItemModel> loadedPages = [];
      for (int i = 0; i < total; i++) {
        loadedPages.add(
          PageItemModel(
            originalIndex: i,
            displayOrder: i + 1,
            thumbnail: null,
          ),
        );
      }

      // If resuming draft
      if (widget.draftToResume != null) {
        final state = widget.draftToResume!.stateData;
        final deletedIndices = List<int>.from(state['deletedIndices'] ?? []);
        for (final p in loadedPages) {
          if (deletedIndices.contains(p.originalIndex)) {
            p.isDeleted = true;
          }
        }
        _hasUnsavedChanges = true;
      }

      if (mounted) {
        setState(() {
          _pages = loadedPages;
          _isLoading = false;
        });
        _loadThumbnailsInBackground();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('পিডিএফ লোড করতে ত্রুটি: $e')),
        );
      }
    }
  }

  Future<void> _loadThumbnailsInBackground() async {
    for (int i = 0; i < _pages.length; i++) {
      if (!mounted) return;
      if (_pages[i].thumbnail != null || _pages[i].isDeleted) continue;
      try {
        final thumb = await _pdfService.renderPageToImage(
          pdfBytes: _originalPdfBytes,
          pageIndex: _pages[i].originalIndex,
          dpi: 45,
        );
        if (mounted && thumb != null) {
          setState(() {
            _pages[i].thumbnail = thumb;
          });
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 15));
    }
  }

  Future<void> _autoSaveDraft() async {
    if (!_hasUnsavedChanges) return;

    final deleted = _pages.where((p) => p.isDeleted).map((p) => p.originalIndex).toList();

    final draft = DraftItem(
      id: _draftId,
      title: 'এডিটিং: ${widget.fileName}',
      type: DraftType.pdfEditor,
      originalFilePath: widget.filePath,
      stateData: {
        'deletedIndices': deleted,
        'pageCount': _pages.length,
        'remainingCount': _pages.where((p) => !p.isDeleted).length,
      },
      updatedAt: DateTime.now(),
    );

    await _draftService.saveDraft(draft);
  }

  void _markPageForDeletion(PageItemModel page) {
    setState(() {
      page.isDeleted = !page.isDeleted;
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  void _deleteSelectedBulk() {
    if (_selectedPagesToDelete.isEmpty) return;

    setState(() {
      for (final index in _selectedPagesToDelete) {
        _pages[index].isDeleted = true;
      }
      _selectedPagesToDelete.clear();
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('নির্বাচিত পেজগুলো ডিলিট মার্ক করা হয়েছে')),
    );
  }

  void _restoreAllPages() {
    setState(() {
      for (final p in _pages) {
        p.isDeleted = false;
      }
      _selectedPagesToDelete.clear();
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  void _rotatePage(PageItemModel page) {
    setState(() {
      page.rotation = (page.rotation + 90) % 360;
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  void _movePage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
      for (int i = 0; i < _pages.length; i++) {
        _pages[i].displayOrder = i + 1;
      }
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  Future<void> _showAddPageDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'নতুন পেজ যুক্ত করুন',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.note_add, color: Colors.white, size: 20),
              ),
              title: const Text('খালি পেজ (Blank Page) যোগ করুন'),
              subtitle: const Text('কাস্টম নোট বা হেডিং সহ'),
              onTap: () {
                Navigator.pop(context);
                _insertBlankPage();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.secondary,
                child: Icon(Icons.image, color: Colors.white, size: 20),
              ),
              title: const Text('ছবি থেকে পেজ যোগ করুন (Gallery / Camera)'),
              subtitle: const Text('গ্যালারি বা ক্যামেরা দিয়ে পেজ বানান'),
              onTap: () {
                Navigator.pop(context);
                _insertImagePage();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.purple,
                child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
              ),
              title: const Text('অন্য PDF থেকে পেজ মার্জ করুন'),
              subtitle: const Text('ফোনের যেকোনো PDF এর সাথে একত্রিত করুন'),
              onTap: () {
                Navigator.pop(context);
                _mergeOtherPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _insertBlankPage() async {
    final textController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('খালি পেজ যোগ করুন'),
        content: TextField(
          controller: textController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'ঐচ্ছিক: এই পেজে কোনো টেক্সট বা শিরোনাম থাকলে লিখুন...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('যুক্ত করুন')),
        ],
      ),
    );

    if (ok == true) {
      setState(() {
        _pages.add(
          PageItemModel(
            originalIndex: -1,
            displayOrder: _pages.length + 1,
            isNewlyAdded: true,
            newlyAddedText: textController.text.trim(),
          ),
        );
        _hasUnsavedChanges = true;
      });
      _autoSaveDraft();
    }
  }

  Future<void> _insertImagePage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pages.add(
          PageItemModel(
            originalIndex: -1,
            displayOrder: _pages.length + 1,
            isNewlyAdded: true,
            newlyAddedImageBytes: bytes,
            thumbnail: bytes,
          ),
        );
        _hasUnsavedChanges = true;
      });
      _autoSaveDraft();
    }
  }

  Future<void> _mergeOtherPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final otherPath = result.files.single.path!;
      final otherBytes = await File(otherPath).readAsBytes();
      final otherCount = await _pdfService.getPageCount(otherPath);

      for (int i = 0; i < otherCount; i++) {
        final thumb = await _pdfService.renderPageToImage(
          pdfBytes: otherBytes,
          pageIndex: i,
          dpi: 80,
        );

        _pages.add(
          PageItemModel(
            originalIndex: -1,
            displayOrder: _pages.length + 1,
            isNewlyAdded: true,
            thumbnail: thumb,
          ),
        );
      }

      setState(() => _hasUnsavedChanges = true);
      _autoSaveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$otherCount টি নতুন পেজ মার্জ করা হয়েছে!')),
        );
      }
    }
  }

  Future<void> _saveModifiedPdf() async {
    final activePages = _pages.where((p) => !p.isDeleted).toList();
    if (activePages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সব পেজ ডিলিট করা হয়েছে! অন্তত ১টি পেজ থাকতে হবে।')),
      );
      return;
    }

    final saveConfig = await SaveExportDialog.show(
      context,
      defaultFileName: widget.fileName,
      currentExtension: 'pdf',
      availableExtensions: ['pdf'],
      canReplace: true,
      originalFilePath: widget.filePath,
    );

    if (saveConfig == null) return;

    setState(() => _isSaving = true);

    try {
      // 1. Process deletions
      final pagesToRemove = _pages
          .asMap()
          .entries
          .where((e) => e.value.isDeleted && e.value.originalIndex >= 0)
          .map((e) => e.value.originalIndex)
          .toList();

      var finalBytes = await _pdfService.removePages(
        originalBytes: _originalPdfBytes,
        pagesToRemoveIndices: pagesToRemove,
      );

      // 2. Process newly added pages
      for (final p in _pages.where((p) => p.isNewlyAdded && !p.isDeleted)) {
        if (p.newlyAddedImageBytes != null) {
          finalBytes = await _pdfService.insertImagePage(
            originalBytes: finalBytes,
            imageBytes: p.newlyAddedImageBytes!,
          );
        } else {
          finalBytes = await _pdfService.insertBlankPage(
            originalBytes: finalBytes,
            noteText: p.newlyAddedText,
          );
        }
      }

      // 3. Compress/Optimize according to quality
      finalBytes = await _pdfService.compressOrOptimize(
        originalBytes: finalBytes,
        qualityPreset: saveConfig.quality,
      );

      // 4. Determine save path
      String targetPath;
      if (saveConfig.isNewCopy) {
        targetPath = await _storageService.getAvailableFilePath(
          saveConfig.fileName,
          customDirPath: saveConfig.targetDirectoryPath,
        );
      } else {
        targetPath = widget.filePath;
      }

      await File(targetPath).writeAsBytes(finalBytes);

      // Delete draft upon save
      await _draftService.deleteDraft(_draftId);
      _hasUnsavedChanges = false;

      if (mounted) {
        setState(() => _isSaving = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.secondary),
                SizedBox(width: 8),
                Text('সংরক্ষণ সফল!'),
              ],
            ),
            content: Text(
              saveConfig.isNewCopy
                  ? 'নতুন ফাইল হিসেবে সংরক্ষিত হয়েছে:\n$targetPath'
                  : 'আসল ফাইলটি সফলভাবে প্রতিস্থাপিত (Replaced) হয়েছে!',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // return to home/caller
                },
                child: const Text('ঠিক আছে'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সংরক্ষণ করতে ব্যর্থ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _pages.where((p) => !p.isDeleted).length;
    final deletedCount = _pages.where((p) => p.isDeleted).length;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_hasUnsavedChanges) {
          _autoSaveDraft();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.fileName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                'বাকি: $activeCount পেজ${deletedCount > 0 ? ' (ডিলিট: $deletedCount)' : ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            if (deletedCount > 0)
              IconButton(
                icon: const Icon(Icons.restore, color: AppColors.warning),
                tooltip: 'সব পেজ রিস্টোর করুন',
                onPressed: _restoreAllPages,
              ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              tooltip: 'নতুন পেজ যোগ করুন',
              onPressed: _showAddPageDialog,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveModifiedPdf,
                icon: const Icon(Icons.check, size: 16),
                label: Text(_isSaving ? 'সেভ...' : 'সেভ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'পেজ কমাতে ডিলিট আইকনে চাপুন। অ্যাপ থেকে বের হলেও ড্রাফটে সংরক্ষিত থাকবে।',
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                        if (_selectedPagesToDelete.isNotEmpty)
                          TextButton(
                            onPressed: _deleteSelectedBulk,
                            child: Text(
                              'ডিলিট (${_selectedPagesToDelete.length})',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Page Grid
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width > 800 ? 4 : (width > 520 ? 3 : 2);
                        final childAspectRatio = width < 340 ? 0.68 : 0.72;

                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: childAspectRatio,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _pages.length,
                          itemBuilder: (context, index) {
                            final page = _pages[index];
                            return _buildPageCard(page, index);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddPageDialog,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('নতুন পেজ যোগ করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPageCard(PageItemModel page, int index) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: page.isDeleted ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: page.isDeleted
              ? Colors.red.shade300
              : page.isNewlyAdded
                  ? AppColors.secondary
                  : Colors.grey.shade200,
          width: page.isDeleted || page.isNewlyAdded ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Content / Thumbnail
          Column(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: page.rotation ~/ 90,
                  child: Container(
                    color: Colors.grey.shade100,
                    width: double.infinity,
                    child: page.thumbnail != null
                        ? Image.memory(page.thumbnail!, fit: BoxFit.contain)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  page.isNewlyAdded ? Icons.note_add_outlined : Icons.description_outlined,
                                  size: 28,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  page.newlyAddedText ?? 'পেজ ${page.displayOrder}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),

              // Bottom control strip
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Move Left
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: index > 0 ? () => _movePage(index, index - 1) : null,
                    ),
                    // Rotate
                    IconButton(
                      icon: const Icon(Icons.rotate_right, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _rotatePage(page),
                    ),
                    // Delete / Restore
                    IconButton(
                      icon: Icon(
                        page.isDeleted ? Icons.restore : Icons.delete,
                        size: 18,
                        color: page.isDeleted ? AppColors.secondary : AppColors.error,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _markPageForDeletion(page),
                    ),
                    // Move Right
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: index < _pages.length - 1 ? () => _movePage(index, index + 1) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Deleted Overlay
          if (page.isDeleted)
            Container(
              color: Colors.red.withValues(alpha: 0.65),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_forever, color: Colors.white, size: 36),
                    SizedBox(height: 4),
                    Text(
                      'ডিলিট মার্কড',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // Page Badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: page.isNewlyAdded ? AppColors.secondary : AppColors.primaryDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                page.isNewlyAdded ? 'নতুন পেজ' : 'পেজ ${page.displayOrder}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
