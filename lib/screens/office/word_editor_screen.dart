import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/draft_item.dart';
import '../../services/office_service.dart';
import '../../services/draft_service.dart';
import '../common/save_export_dialog.dart';

class WordEditorScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final DraftItem? draftToResume;

  const WordEditorScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.draftToResume,
  });

  @override
  State<WordEditorScreen> createState() => _WordEditorScreenState();
}

class _WordEditorScreenState extends State<WordEditorScreen> {
  final OfficeService _officeService = OfficeService();
  final DraftService _draftService = DraftService();

  List<String> _paragraphs = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  late String _draftId;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftToResume?.id ?? 'draft_docx_${DateTime.now().millisecondsSinceEpoch}';
    _loadDocx();
  }

  Future<void> _loadDocx() async {
    setState(() => _isLoading = true);
    if (widget.draftToResume != null && widget.draftToResume!.stateData.containsKey('paragraphs')) {
      _paragraphs = List<String>.from(widget.draftToResume!.stateData['paragraphs']);
      _hasUnsavedChanges = true;
    } else {
      _paragraphs = await _officeService.readDocxParagraphs(widget.filePath);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _autoSaveDraft() async {
    if (!_hasUnsavedChanges) return;

    final draft = DraftItem(
      id: _draftId,
      title: 'ওয়ার্ড এডিটিং: ${widget.fileName}',
      type: DraftType.officeDoc,
      originalFilePath: widget.filePath,
      stateData: {
        'paragraphs': _paragraphs,
        'format': 'docx',
      },
      updatedAt: DateTime.now(),
    );

    await _draftService.saveDraft(draft);
  }

  void _editParagraph(int index) async {
    final controller = TextEditingController(text: _paragraphs[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('প্যারাগ্রাফ #${index + 1} এডিট করুন', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 6,
          style: GoogleFonts.hindSiliguri(fontSize: 15, height: 1.5),
          decoration: const InputDecoration(hintText: 'টেক্সট লিখুন...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('আপডেট'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _paragraphs[index] = result;
        _hasUnsavedChanges = true;
      });
      _autoSaveDraft();
    }
  }

  void _addNewParagraph() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('নতুন প্যারাগ্রাফ যোগ করুন', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: GoogleFonts.hindSiliguri(fontSize: 15, height: 1.5),
          decoration: const InputDecoration(hintText: 'এখানে নতুন প্যারাগ্রাফ লিখুন...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _paragraphs.add(result);
        _hasUnsavedChanges = true;
      });
      _autoSaveDraft();
    }
  }

  void _deleteParagraph(int index) {
    setState(() {
      _paragraphs.removeAt(index);
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  Future<void> _saveDocx() async {
    final saveConfig = await SaveExportDialog.show(
      context,
      defaultFileName: widget.fileName,
      currentExtension: 'docx',
      availableExtensions: ['docx', 'txt'],
      canReplace: true,
      originalFilePath: widget.filePath,
    );

    if (saveConfig == null) return;

    setState(() => _isSaving = true);
    try {
      final savedPath = await _officeService.saveDocxFile(
        originalPath: widget.filePath,
        paragraphs: _paragraphs,
        saveAsNewCopy: saveConfig.isNewCopy,
        newFileName: saveConfig.fileName,
      );

      await _draftService.deleteDraft(_draftId);
      _hasUnsavedChanges = false;

      if (mounted) {
        setState(() => _isSaving = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('সংরক্ষণ সফল!'),
            content: Text(
              saveConfig.isNewCopy
                  ? 'নতুন ফাইল হিসেবে সংরক্ষিত হয়েছে:\n$savedPath'
                  : 'আসল ফাইলে পরিবর্তন সেভ করা হয়েছে!',
            ),
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
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সংরক্ষণ করতে ত্রুটি: $e')),
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ওয়ার্ড (DOCX) এডিটর', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(widget.fileName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              tooltip: 'নতুন প্যারাগ্রাফ',
              onPressed: _addNewParagraph,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveDocx,
                icon: const Icon(Icons.save, size: 16),
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
            : _paragraphs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description, size: 50, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('কোনো প্যারাগ্রাফ পাওয়া যায়নি'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _addNewParagraph,
                          icon: const Icon(Icons.add),
                          label: const Text('প্যারাগ্রাফ লিখুন'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _paragraphs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = _paragraphs[index];
                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                    onPressed: () => _editParagraph(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    onPressed: () => _deleteParagraph(index),
                                  ),
                                ],
                              ),
                              const Divider(height: 8),
                              Text(
                                p,
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 14.5,
                                  height: 1.55,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewParagraph,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
