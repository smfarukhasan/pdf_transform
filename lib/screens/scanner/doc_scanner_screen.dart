import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../models/draft_item.dart';
import '../../services/scanner_service.dart';
import '../../services/draft_service.dart';
import '../common/save_export_dialog.dart';

class DocScannerScreen extends StatefulWidget {
  final DraftItem? draftToResume;

  const DocScannerScreen({super.key, this.draftToResume});

  @override
  State<DocScannerScreen> createState() => _DocScannerScreenState();
}

class _DocScannerScreenState extends State<DocScannerScreen> {
  final ScannerService _scannerService = ScannerService();
  final DraftService _draftService = DraftService();

  final List<ScannerPage> _pages = [];
  bool _isBuildingPdf = false;
  bool _hasUnsavedChanges = false;
  late String _draftId;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftToResume?.id ?? 'draft_scan_${DateTime.now().millisecondsSinceEpoch}';

    // If resuming draft, or start camera
    if (widget.draftToResume == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _takePhoto(ImageSource.camera);
      });
    }
  }

  Future<void> _takePhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final page = ScannerPage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalBytes: bytes,
        processedBytes: bytes,
        filter: ScanFilter.original,
      );

      setState(() {
        _pages.add(page);
        _hasUnsavedChanges = true;
      });
      _autoSaveDraft();
    }
  }

  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage();
    if (pickedList.isNotEmpty) {
      for (final p in pickedList) {
        final bytes = await p.readAsBytes();
        _pages.add(
          ScannerPage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            originalBytes: bytes,
            processedBytes: bytes,
            filter: ScanFilter.original,
          ),
        );
      }
      setState(() => _hasUnsavedChanges = true);
      _autoSaveDraft();
    }
  }

  Future<void> _autoSaveDraft() async {
    if (!_hasUnsavedChanges || _pages.isEmpty) return;

    final draft = DraftItem(
      id: _draftId,
      title: 'স্ক্যান ড্রাফট (${_pages.length} টি পেজ)',
      type: DraftType.docScanner,
      stateData: {
        'pageCount': _pages.length,
      },
      updatedAt: DateTime.now(),
    );

    await _draftService.saveDraft(draft);
  }

  void _applyFilter(ScannerPage page, ScanFilter filter) {
    setState(() {
      page.filter = filter;
      var current = _scannerService.applyFilter(page.originalBytes, filter);
      if (page.rotationAngle != 0) {
        current = _scannerService.rotateImage(current, page.rotationAngle);
      }
      page.processedBytes = current;
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  void _rotatePage(ScannerPage page) {
    setState(() {
      page.rotationAngle = (page.rotationAngle + 90) % 360;
      var current = _scannerService.applyFilter(page.originalBytes, page.filter);
      if (page.rotationAngle != 0) {
        current = _scannerService.rotateImage(current, page.rotationAngle);
      }
      page.processedBytes = current;
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  void _deletePage(int index) {
    setState(() {
      _pages.removeAt(index);
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  Future<void> _buildPdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অন্তত একটি ছবি স্ক্যান করুন')),
      );
      return;
    }

    final saveConfig = await SaveExportDialog.show(
      context,
      defaultFileName: 'ScannedDoc_${DateTime.now().millisecondsSinceEpoch}',
      currentExtension: 'pdf',
      availableExtensions: ['pdf'],
      canReplace: false,
    );

    if (saveConfig == null) return;

    setState(() => _isBuildingPdf = true);
    try {
      final pdfPath = await _scannerService.buildPdfFromScannedPages(
        pages: _pages,
        pdfFileName: saveConfig.fileName,
        customDirPath: saveConfig.targetDirectoryPath,
      );

      await _draftService.deleteDraft(_draftId);
      _hasUnsavedChanges = false;

      if (mounted) {
        setState(() => _isBuildingPdf = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.secondary),
                SizedBox(width: 8),
                Text('স্ক্যান PDF তৈরি সফল!'),
              ],
            ),
            content: Text('KhubSojaDoc ফোল্ডারে সংরক্ষিত হয়েছে:\n$pdfPath'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('ঠিক আছে'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBuildingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF তৈরি করতে ব্যর্থ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_hasUnsavedChanges) _autoSaveDraft();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('ডকুমেন্ট স্ক্যানার (${_pages.length} পেজ)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt, color: AppColors.primary),
              tooltip: 'ক্যামেরা',
              onPressed: () => _takePhoto(ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library, color: AppColors.primary),
              tooltip: 'গ্যালারি',
              onPressed: _pickMultipleImages,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _pages.isNotEmpty && !_isBuildingPdf ? _buildPdf : null,
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: Text(_isBuildingPdf ? 'তৈরি...' : 'PDF বানান'),
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
        body: _pages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.document_scanner, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('কোনো পেজ স্ক্যান করা হয়নি', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('নিচের বাটন দিয়ে ক্যামেরা বা গ্যালারি থেকে ছবি যোগ করুন'),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _takePhoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('ক্যামেরা'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _pickMultipleImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('গ্যালারি'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primary,
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text('স্ক্যান পেজ #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.rotate_right),
                                onPressed: () => _rotatePage(page),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                onPressed: () => _deletePage(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              height: 260,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(page.processedBytes, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('ডকুমেন্ট ফিল্টার:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildFilterButton(page, ScanFilter.original, 'আসল রঙ'),
                              const SizedBox(width: 8),
                              _buildFilterButton(page, ScanFilter.grayscale, 'গ্রে-স্কেল'),
                              const SizedBox(width: 8),
                              _buildFilterButton(page, ScanFilter.documentBw, 'B&W ডকুমেন্টস'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        bottomNavigationBar: _pages.isNotEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _takePhoto(ImageSource.camera),
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('+ আরও পেজ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _buildPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF তৈরি করুন'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildFilterButton(ScannerPage page, ScanFilter filter, String label) {
    final isSelected = page.filter == filter;
    return Expanded(
      child: InkWell(
        onTap: () => _applyFilter(page, filter),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
