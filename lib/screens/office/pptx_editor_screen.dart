import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/office_service.dart';
import '../common/save_export_dialog.dart';

class PptxEditorScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PptxEditorScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PptxEditorScreen> createState() => _PptxEditorScreenState();
}

class _PptxEditorScreenState extends State<PptxEditorScreen> {
  final OfficeService _officeService = OfficeService();

  List<Map<String, dynamic>> _slides = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPptx();
  }

  Future<void> _loadPptx() async {
    setState(() => _isLoading = true);
    final slides = await _officeService.readPptxSlides(widget.filePath);
    if (mounted) {
      setState(() {
        _slides = slides;
        _isLoading = false;
      });
    }
  }

  void _editText(int slideIndex, int textIndex) async {
    final texts = _slides[slideIndex]['texts'] as List<String>;
    final controller = TextEditingController(text: texts[textIndex]);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('স্লাইড #${slideIndex + 1} টেক্সট এডিট'),
        content: TextField(
          controller: controller,
          maxLines: 4,
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
        texts[textIndex] = result;
      });
    }
  }

  Future<void> _savePptx() async {
    final saveConfig = await SaveExportDialog.show(
      context,
      defaultFileName: widget.fileName,
      currentExtension: 'pptx',
      availableExtensions: ['pptx'],
      canReplace: true,
      originalFilePath: widget.filePath,
    );

    if (saveConfig == null) return;

    setState(() => _isSaving = true);
    try {
      final savedPath = await _officeService.savePptxFile(
        originalPath: widget.filePath,
        modifiedSlides: _slides,
        saveAsNewCopy: saveConfig.isNewCopy,
        newFileName: saveConfig.fileName,
      );

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
          SnackBar(content: Text('সংরক্ষণ করতে ব্যর্থ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('পাওয়ার পয়েন্ট (PPTX) এডিটর', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.fileName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePptx,
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
          : _slides.isEmpty
              ? const Center(child: Text('কোনো স্লাইড বা এডিটেবল টেক্সট পাওয়া যায়নি'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _slides.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, slideIdx) {
                    final slide = _slides[slideIdx];
                    final texts = slide['texts'] as List<String>;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade800,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'স্লাইড #${slide['slideNumber']}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                const Spacer(),
                                Text('${texts.length} টি টেক্সট উপাদান', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                            const Divider(height: 16),
                            if (texts.isEmpty)
                              const Text('এই স্লাইডে কোনো টেক্সট নেই', style: TextStyle(color: Colors.grey, fontSize: 13))
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: texts.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, textIdx) {
                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            texts[textIdx],
                                            style: const TextStyle(fontSize: 13.5),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                                          onPressed: () => _editText(slideIdx, textIdx),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
