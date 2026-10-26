import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../constants/app_colors.dart';
import '../../services/pdf_service.dart';
import '../../services/pdf_conversion_service.dart';

class PdfToImageScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfToImageScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  final PdfService _pdfService = PdfService();
  final PdfConversionService _conversionService = PdfConversionService();

  int _totalPages = 1;
  bool _isLoading = true;
  bool _isConverting = false;
  int _progressCurrent = 0;
  int _progressTotal = 0;

  bool _isAllPages = true; // true = all pages 1, 2, 3..., false = marked pages
  final Set<int> _markedPages = {}; // 1-based page numbers
  final Map<int, Uint8List?> _pageThumbnails = {};
  final List<int> _renderQueue = [];
  bool _isProcessingQueue = false;

  // Batching for large PDFs (> 20 pages)
  static const int _batchSize = 20;
  int _activeBatchIndex = 0; // 0 = pages 1-20, 1 = 21-40, etc. -1 = All Pages
  final TextEditingController _rangeInputController = TextEditingController();

  Uint8List? _pdfBytesCache;

  String _format = 'jpg';
  int _quality = 90;

  @override
  void initState() {
    super.initState();
    _loadPagesInfo();
  }

  @override
  void dispose() {
    _rangeInputController.dispose();
    super.dispose();
  }

  Future<void> _loadPagesInfo() async {
    setState(() => _isLoading = true);
    try {
      final count = await _pdfService.getPageCount(widget.filePath);
      _pdfBytesCache = await File(widget.filePath).readAsBytes();

      _totalPages = count > 0 ? count : 1;
      // Pre-mark all pages initially
      for (int i = 1; i <= _totalPages; i++) {
        _markedPages.add(i);
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }

      // Prioritize thumbnails for the first batch
      _enqueueCurrentBatchThumbnails();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<int> _getCurrentBatchPages() {
    if (_activeBatchIndex == -1 || _totalPages <= _batchSize) {
      return List<int>.generate(_totalPages, (i) => i + 1);
    }
    final start = _activeBatchIndex * _batchSize + 1;
    final end = min((_activeBatchIndex + 1) * _batchSize, _totalPages);
    if (start > _totalPages) return [];
    return List<int>.generate(end - start + 1, (i) => start + i);
  }

  void _enqueueCurrentBatchThumbnails() {
    final pages = _getCurrentBatchPages();
    for (final p in pages) {
      if (!_pageThumbnails.containsKey(p) && !_renderQueue.contains(p)) {
        _renderQueue.add(p);
      }
    }
    _processRenderQueue();
  }

  Future<void> _processRenderQueue() async {
    if (_isProcessingQueue || _pdfBytesCache == null) return;
    _isProcessingQueue = true;

    while (_renderQueue.isNotEmpty) {
      if (!mounted) break;
      final pageNum = _renderQueue.removeAt(0);
      if (_pageThumbnails[pageNum] != null) continue;

      try {
        final thumb = await _pdfService.renderPageToImage(
          pdfBytes: _pdfBytesCache!,
          pageIndex: pageNum - 1,
          dpi: 45, // Lightweight, fast and crisp for ~100px thumbnails
        );
        if (mounted && thumb != null) {
          setState(() {
            _pageThumbnails[pageNum] = thumb;
          });
        }
      } catch (_) {
        // Allow retry later instead of permanently failing
      }

      // Small pause to keep UI silky smooth and allow GC
      await Future.delayed(const Duration(milliseconds: 10));
    }

    _isProcessingQueue = false;
  }

  void _requestThumbnail(int pageNum) {
    if (!_pageThumbnails.containsKey(pageNum) && !_renderQueue.contains(pageNum)) {
      _renderQueue.insert(0, pageNum);
      _processRenderQueue();
    }
  }

  void _toggleMarkPage(int pageNumber) {
    setState(() {
      if (_markedPages.contains(pageNumber)) {
        _markedPages.remove(pageNumber);
      } else {
        _markedPages.add(pageNumber);
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (int i = 1; i <= _totalPages; i++) {
        _markedPages.add(i);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _markedPages.clear();
    });
  }

  void _selectCurrentBatch() {
    final batchPages = _getCurrentBatchPages();
    setState(() {
      _markedPages.addAll(batchPages);
    });
  }

  void _unselectCurrentBatch() {
    final batchPages = _getCurrentBatchPages();
    setState(() {
      _markedPages.removeAll(batchPages);
    });
  }

  void _applyCustomRange(String input) {
    final parts = input.split(RegExp(r'[,;\s]+'));
    final newSelected = <int>{};
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('-')) {
        final rangeParts = trimmed.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null) {
            final s = start < end ? start : end;
            final e = start < end ? end : start;
            for (int p = s; p <= e; p++) {
              if (p >= 1 && p <= _totalPages) newSelected.add(p);
            }
          }
        }
      } else {
        final p = int.tryParse(trimmed);
        if (p != null && p >= 1 && p <= _totalPages) {
          newSelected.add(p);
        }
      }
    }

    if (newSelected.isNotEmpty) {
      setState(() {
        _markedPages.addAll(newSelected);
      });
      _rangeInputController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newSelected.length} টি পেজ মার্ক করা হয়েছে (মোট: ${_markedPages.length})'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সঠিক পেজ নম্বর লিখুন (যেমন: 1-5, 8, 21-35)')),
      );
    }
  }

  Future<void> _startConversion() async {
    final List<int>? pagesToConvert = _isAllPages ? null : (_markedPages.toList()..sort());

    if (!_isAllPages && (pagesToConvert == null || pagesToConvert.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুগ্রহ করে অন্তত ১টি পেজ মার্ক করুন')),
      );
      return;
    }

    setState(() {
      _isConverting = true;
      _progressCurrent = 0;
      _progressTotal = _isAllPages ? _totalPages : pagesToConvert!.length;
    });

    try {
      final folderPath = await _conversionService.convertPdfToImages(
        pdfPath: widget.filePath,
        selectedPages: pagesToConvert,
        format: _format,
        quality: _quality,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isConverting = false);
        _showSuccessDialog(folderPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('কনভার্ট করতে ত্রুটি: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(String folderPath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.secondary, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('ইমেজ তৈরি সম্পন্ন!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'মোট ${_isAllPages ? _totalPages : _markedPages.length} টি পেজ ১, ২, ৩... ক্রমানুসারে KhubSojaDoc ফোল্ডারে সফলভাবে সংরক্ষিত হয়েছে:',
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                folderPath,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বন্ধ করুন'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('ফোল্ডার ওপেন করুন'),
            onPressed: () {
              Navigator.pop(context);
              OpenFilex.open(folderPath);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final totalBatches = (_totalPages / _batchSize).ceil();
    final currentBatchPages = _getCurrentBatchPages();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PDF থেকে ইমেজ কনভার্টার', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode Selector Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'কনভার্ট অপশন নির্বাচন করুন:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => setState(() => _isAllPages = true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isAllPages ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isAllPages ? AppColors.primary : Colors.grey.shade300,
                                  width: _isAllPages ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isAllPages ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: _isAllPages ? AppColors.primary : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('সম্পূর্ণ PDF (সব পেজ ১, ২, ৩... নম্বর অনুসারে)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                        Text('মোট $_totalPages টি পেজের প্রতিটি আলাদা ইমেজ ফোল্ডারে জমা হবে', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              setState(() => _isAllPages = false);
                              _enqueueCurrentBatchThumbnails();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: !_isAllPages ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !_isAllPages ? AppColors.primary : Colors.grey.shade300,
                                  width: !_isAllPages ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    !_isAllPages ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: !_isAllPages ? AppColors.primary : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('ইচ্ছা মতো পেজ মার্ক করে ইমেজ বানান', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                        Text('শুধু আপনার পছন্দের মার্ক করা পেজগুলো ইমেজ হবে (মোট সিলেক্টেড: ${_markedPages.length}/$_totalPages)', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Format & Quality settings
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Text('ইমেজ ফরম্যাট: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ChoiceChip(
                                label: const Text('JPG (ছোট সাইজ)'),
                                selected: _format == 'jpg',
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(color: _format == 'jpg' ? Colors.white : AppColors.textPrimary, fontSize: 12),
                                onSelected: (s) => setState(() => _format = 'jpg'),
                              ),
                              ChoiceChip(
                                label: const Text('PNG (হাই কোয়ালিটি)'),
                                selected: _format == 'png',
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(color: _format == 'png' ? Colors.white : AppColors.textPrimary, fontSize: 12),
                                onSelected: (s) => setState(() => _format = 'png'),
                              ),
                            ],
                          ),
                          if (_format == 'jpg') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('কোয়ালিটি: $_quality%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Expanded(
                                  child: Slider(
                                    value: _quality.toDouble(),
                                    min: 40,
                                    max: 100,
                                    divisions: 6,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) => setState(() => _quality = val.toInt()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Selective page picker (with responsive batches for 20+ pages)
                  if (!_isAllPages) ...[
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with selection count
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'পেজ নির্বাচন (${_markedPages.length}/$_totalPages সিলেক্টেড):',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: _selectAll,
                                      child: const Text('সবগুলো', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    TextButton(
                                      onPressed: _clearAll,
                                      child: const Text('ক্লিয়ার', style: TextStyle(fontSize: 12, color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Batch Selector Tabs when totalPages > 20
                            if (_totalPages > _batchSize) ...[
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'পেজ ব্যাচ বেছে নিন:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.primary),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'পূর্ববর্তী ব্যাচ',
                                        onPressed: _activeBatchIndex > 0
                                            ? () {
                                                setState(() => _activeBatchIndex--);
                                                _enqueueCurrentBatchThumbnails();
                                              }
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _activeBatchIndex == -1
                                            ? 'সব পেজ'
                                            : 'ব্যাচ ${_activeBatchIndex + 1}/$totalBatches',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'পরবর্তী ব্যাচ',
                                        onPressed: _activeBatchIndex >= 0 && _activeBatchIndex < totalBatches - 1
                                            ? () {
                                                setState(() => _activeBatchIndex++);
                                                _enqueueCurrentBatchThumbnails();
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ...List.generate(totalBatches, (b) {
                                      final start = b * _batchSize + 1;
                                      final end = min((b + 1) * _batchSize, _totalPages);
                                      final isSelected = _activeBatchIndex == b;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          label: Text('পেজ $start - $end'),
                                          selected: isSelected,
                                          selectedColor: AppColors.primary,
                                          labelStyle: TextStyle(
                                            color: isSelected ? Colors.white : AppColors.textPrimary,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 11.5,
                                          ),
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() => _activeBatchIndex = b);
                                              _enqueueCurrentBatchThumbnails();
                                            }
                                          },
                                        ),
                                      );
                                    }),
                                    // Option to view all pages
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text('সব পেজ ($_totalPages)'),
                                        selected: _activeBatchIndex == -1,
                                        selectedColor: AppColors.primary,
                                        labelStyle: TextStyle(
                                          color: _activeBatchIndex == -1 ? Colors.white : AppColors.textPrimary,
                                          fontWeight: _activeBatchIndex == -1 ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 11.5,
                                        ),
                                        onSelected: (val) {
                                          if (val) {
                                            setState(() => _activeBatchIndex = -1);
                                            _enqueueCurrentBatchThumbnails();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Batch selection shortcut actions
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.check_box_outlined, size: 15),
                                    label: const Text('এই ব্যাচ সব সিলেক্ট', style: TextStyle(fontSize: 11.5)),
                                    onPressed: _selectCurrentBatch,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.check_box_outline_blank, size: 15),
                                    label: const Text('এই ব্যাচ আনসিলেক্ট', style: TextStyle(fontSize: 11.5)),
                                    onPressed: _unselectCurrentBatch,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const Divider(height: 18),
                            // Quick Range Input Box for custom typing (e.g. 1-10, 21-35)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _rangeInputController,
                                    decoration: InputDecoration(
                                      hintText: 'কাস্টম রেঞ্জ (যেমন: 1-5, 21-30)',
                                      hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                    keyboardType: TextInputType.text,
                                    onSubmitted: (val) => _applyCustomRange(val),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _applyCustomRange(_rangeInputController.text),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('মার্ক করুন', style: TextStyle(fontSize: 11.5)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Active Batch Info Bar
                    if (_totalPages > _batchSize && _activeBatchIndex >= 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'প্রদর্শিত হচ্ছে পেজ ${currentBatchPages.first} থেকে ${currentBatchPages.last}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Text(
                              'মোট: $_totalPages পেজ',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Responsive Page Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width > 800 ? 5 : (width > 500 ? 4 : (width < 340 ? 2 : 3));
                        final aspectRatio = width < 340 ? 0.76 : 0.72;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: aspectRatio,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: currentBatchPages.length,
                          itemBuilder: (context, index) {
                            final pageNum = currentBatchPages[index];
                            final isMarked = _markedPages.contains(pageNum);
                            final thumb = _pageThumbnails[pageNum];

                            // Trigger queue loading if thumb not available
                            if (thumb == null) {
                              _requestThumbnail(pageNum);
                            }

                            return InkWell(
                              onTap: () => _toggleMarkPage(pageNum),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isMarked ? AppColors.primary : Colors.grey.shade300,
                                    width: isMarked ? 2.5 : 1,
                                  ),
                                  color: isMarked ? AppColors.primary.withValues(alpha: 0.04) : Colors.grey.shade100,
                                ),
                                child: Stack(
                                  children: [
                                    if (thumb != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          color: Colors.white,
                                          width: double.infinity,
                                          height: double.infinity,
                                          child: Image.memory(
                                            thumb,
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        ),
                                      )
                                    else
                                      Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.description_outlined,
                                              size: 32,
                                              color: isMarked ? AppColors.primary : Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 6),
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 1.8),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'পেজ $pageNum',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isMarked ? AppColors.primary : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Checkmark Badge (Top-Right)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: isMarked ? AppColors.primary : Colors.white.withValues(alpha: 0.9),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          isMarked ? Icons.check : Icons.circle_outlined,
                                          size: 14,
                                          color: isMarked ? Colors.white : Colors.grey,
                                        ),
                                      ),
                                    ),

                                    // Page Number Chip (Bottom-Left)
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isMarked ? AppColors.primary : Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'পেজ $pageNum',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Progress when converting
                  if (_isConverting) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _progressTotal > 0 ? _progressCurrent / _progressTotal : null,
                            color: AppColors.primary,
                            minHeight: 6,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'ইমেজ তৈরি হচ্ছে: $_progressCurrent / $_progressTotal...',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Convert Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isConverting ? null : _startConversion,
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        _isAllPages
                            ? 'সম্পূর্ণ PDF ($_totalPages পেজ) রূপান্তর করুন'
                            : 'মার্ক করা (${_markedPages.length} পেজ) ইমেজ বানান',
                        style: TextStyle(
                          fontSize: screenWidth < 350 ? 13 : 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
