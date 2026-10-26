import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../models/bookmark_item.dart';
import '../../services/pdf_service.dart';
import '../../services/recent_service.dart';
import '../pdf_editor/pdf_editor_screen.dart';
import '../office/word_editor_screen.dart';
import '../office/excel_editor_screen.dart';
import '../office/pptx_editor_screen.dart';
import '../image_tools/image_processor_screen.dart';

class DocumentReaderScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const DocumentReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  final PdfService _pdfService = PdfService();
  final RecentService _recentService = RecentService();

  int _totalPages = 1;
  int _currentPage = 1;
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _isLoading = true;
  Uint8List? _pdfBytes;
  List<BookmarkItem> _bookmarks = [];

  // Page image cache
  final Map<int, Uint8List> _renderedPages = {};

  final TransformationController _transformationController = TransformationController();

  bool get _isPdf => widget.fileName.toLowerCase().endsWith('.pdf');
  bool get _isWord => widget.fileName.toLowerCase().endsWith('.docx') || widget.fileName.toLowerCase().endsWith('.doc');
  bool get _isExcel => widget.fileName.toLowerCase().endsWith('.xlsx') || widget.fileName.toLowerCase().endsWith('.xls');
  bool get _isPpt => widget.fileName.toLowerCase().endsWith('.pptx') || widget.fileName.toLowerCase().endsWith('.ppt');
  bool get _isImage => ['jpg', 'jpeg', 'png', 'webp', 'bmp'].any((ext) => widget.fileName.toLowerCase().endsWith('.$ext'));
  bool get _isText => widget.fileName.toLowerCase().endsWith('.txt');

  String _textContent = '';

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    setState(() => _isLoading = true);
    final file = File(widget.filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ফাইলটি পাওয়া যায়নি')),
        );
        Navigator.pop(context);
      }
      return;
    }

    _bookmarks = await _recentService.getBookmarksForFile(widget.filePath);

    if (_isPdf) {
      _pdfBytes = await file.readAsBytes();
      _totalPages = await _pdfService.getPageCount(widget.filePath);

      // Check if user had previous reading position
      final recentList = await _recentService.getRecentItems();
      final existing = recentList.where((r) => r.filePath == widget.filePath).toList();
      if (existing.isNotEmpty && existing.first.lastPage <= _totalPages) {
        _currentPage = existing.first.lastPage;
      }

      await _renderCurrentPage();
    } else if (_isText) {
      _textContent = await file.readAsString();
    }

    await _recentService.recordFileOpened(
      filePath: widget.filePath,
      fileName: widget.fileName,
      lastPage: _currentPage,
      totalPages: _totalPages,
      fileSize: await file.length(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _renderCurrentPage() async {
    if (!_isPdf || _pdfBytes == null) return;

    if (_renderedPages.containsKey(_currentPage)) {
      return;
    }

    final pageImg = await _pdfService.renderPageToImage(
      pdfBytes: _pdfBytes!,
      pageIndex: _currentPage - 1,
      dpi: 160,
    );

    if (pageImg != null && mounted) {
      setState(() {
        _renderedPages[_currentPage] = pageImg;
      });
    }
  }

  void _onPageChanged(int newPage) async {
    if (newPage < 1 || newPage > _totalPages) return;
    setState(() {
      _currentPage = newPage;
      _transformationController.value = Matrix4.identity(); // reset zoom on page turn
    });
    await _renderCurrentPage();
    await _recentService.updateReadingProgress(widget.filePath, _currentPage, _totalPages);
  }

  void _rotate() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  Future<void> _addBookmark() async {
    final noteController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('পেজ $_currentPage সেভ মার্ক করুন'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'ঐচ্ছিক নোট লিখুন (যেমন: জরুরি প্যারাগ্রাফ)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('সেভ')),
        ],
      ),
    );

    if (result == true) {
      final bookmark = BookmarkItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: widget.filePath,
        pageNumber: _currentPage,
        note: noteController.text.trim(),
        createdAt: DateTime.now(),
      );
      await _recentService.addBookmark(bookmark);
      _bookmarks = await _recentService.getBookmarksForFile(widget.filePath);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('পেজ $_currentPage সেভ মার্ক করা হয়েছে!')),
        );
      }
    }
  }

  void _showBookmarksList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('সংরক্ষিত বুকমার্কস (Saved Marks)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            if (_bookmarks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('কোনো পেজ মার্ক করা হয়নি')),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) {
                    final b = _bookmarks[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                        child: Text('${b.pageNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                      title: Text(b.note.isNotEmpty ? b.note : 'পেজ নম্বর ${b.pageNumber}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          await _recentService.removeBookmark(b.id);
                          _bookmarks = await _recentService.getBookmarksForFile(widget.filePath);
                          setState(() {});
                          nav.pop();
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _onPageChanged(b.pageNumber);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyEnglishText() async {
    setState(() => _isLoading = true);
    final text = await _pdfService.extractText(widget.filePath, pageIndex: _currentPage - 1);
    setState(() => _isLoading = false);

    if (text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('এই পেজে কোনো কপি করার মতো টেক্সট পাওয়া যায়নি')),
        );
      }
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.copy, color: AppColors.primary),
              SizedBox(width: 8),
              Text('টেক্সট কপি সফল!'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বন্ধ করুন'),
            ),
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ক্লিপবোর্ডে কপি করা হয়েছে!')),
                );
              },
              child: const Text('পুনরায় কপি'),
            ),
          ],
        ),
      );
    }
  }

  void _routeToEditor() {
    if (_isPdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfEditorScreen(
            filePath: widget.filePath,
            fileName: widget.fileName,
          ),
        ),
      );
    } else if (_isWord) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WordEditorScreen(
            filePath: widget.filePath,
            fileName: widget.fileName,
          ),
        ),
      );
    } else if (_isExcel) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExcelEditorScreen(
            filePath: widget.filePath,
            fileName: widget.fileName,
          ),
        ),
      );
    } else if (_isPpt) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PptxEditorScreen(
            filePath: widget.filePath,
            fileName: widget.fileName,
          ),
        ),
      );
    } else if (_isImage) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageProcessorScreen(
            filePath: widget.filePath,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('এই ফরম্যাটের জন্য সাধারণ রিডিং মোড প্রযোজ্য')),
      );
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ডিলিট অপশন নির্বাচন করুন'),
        content: const Text(
          'আপনি কি এটি শুধু অ্যাপের রিসেন্ট তালিকা থেকে সরাতে চান, নাকি ফোন থেকে সম্পূর্ণ ডিলিট করতে চান?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          OutlinedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await _recentService.removeFromRecent(widget.filePath);
              nav.pop();
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('রিসেন্ট তালিকা থেকে রিমুভ করা হয়েছে (আসল ফাইল অক্ষত আছে)')),
              );
            },
            child: const Text('তালিকা থেকে রিমুভ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await File(widget.filePath).delete();
                await _recentService.removeFromRecent(widget.filePath);
                nav.pop();
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('আসল ফাইল ফোন থেকে সম্পূর্ণ মুছে ফেলা হয়েছে')),
                );
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('ডিলিট করতে ব্যর্থ: $e')),
                );
              }
            },
            child: const Text('ফোন থেকে ডিলিট', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Dark slate canvas for comfortable reading
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (_isPdf)
              Text(
                'পেজ $_currentPage / $_totalPages',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          // Rotate
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'রোটেট',
            onPressed: _rotate,
          ),
          // Bookmark save mark
          if (_isPdf) ...[
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'পেজ সেভ মার্ক',
              onPressed: _addBookmark,
            ),
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              tooltip: 'বুকমার্ক তালিকা',
              onPressed: _showBookmarksList,
            ),
            // Text copy
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'টেক্সট কপি',
              onPressed: _copyEnglishText,
            ),
          ],
          // Edit
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.primary),
            tooltip: 'এডিট করুন',
            onPressed: _routeToEditor,
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'ডিলিট',
            onPressed: _showDeleteDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.8,
                      maxScale: 4.5,
                      child: RotatedBox(
                        quarterTurns: _rotationAngle ~/ 90,
                        child: _buildDocumentContent(),
                      ),
                    ),
                  ),
                ),
                if (_isPdf && _totalPages > 1) _buildPdfBottomControls(),
              ],
            ),
    );
  }

  Widget _buildDocumentContent() {
    if (_isPdf) {
      final imgBytes = _renderedPages[_currentPage];
      if (imgBytes == null) {
        return const SizedBox(
          width: 200,
          height: 200,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      }
      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Image.memory(
          imgBytes,
          fit: BoxFit.contain,
        ),
      );
    } else if (_isImage) {
      return Container(
        margin: const EdgeInsets.all(12),
        child: Image.file(
          File(widget.filePath),
          fit: BoxFit.contain,
        ),
      );
    } else if (_isText) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            _textContent,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          ),
        ),
      );
    } else {
      // Office placeholder viewer with instant Open in Editor button
      return Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isWord
                  ? Icons.description
                  : _isExcel
                      ? Icons.table_chart
                      : Icons.slideshow,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.fileName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'এই অফিস ডকুমেন্টটি দেখতে বা পরিবর্তন করতে এডিটরে ওপেন করুন:',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _routeToEditor,
              icon: const Icon(Icons.edit),
              label: const Text('এডিটরে ওপেন ও মডিফাই করুন'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPdfBottomControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: _currentPage > 1 ? () => _onPageChanged(_currentPage - 1) : null,
          ),
          Expanded(
            child: Slider(
              value: _currentPage.toDouble(),
              min: 1,
              max: _totalPages.toDouble(),
              divisions: _totalPages > 1 ? _totalPages - 1 : 1,
              label: 'পেজ $_currentPage',
              activeColor: AppColors.primary,
              onChanged: (val) {
                _onPageChanged(val.toInt());
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: _currentPage < _totalPages ? () => _onPageChanged(_currentPage + 1) : null,
          ),
        ],
      ),
    );
  }
}
