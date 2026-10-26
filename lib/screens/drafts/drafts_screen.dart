import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/draft_item.dart';
import '../../services/draft_service.dart';
import '../pdf_editor/pdf_editor_screen.dart';
import '../scanner/doc_scanner_screen.dart';
import '../office/word_editor_screen.dart';
import '../office/excel_editor_screen.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  final DraftService _draftService = DraftService();
  List<DraftItem> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    final list = await _draftService.getAllDrafts();
    if (mounted) {
      setState(() {
        _drafts = list;
        _isLoading = false;
      });
    }
  }

  void _resumeDraft(DraftItem draft) {
    if (draft.type == DraftType.pdfEditor && draft.originalFilePath != null) {
      final fileName = draft.originalFilePath!.split('/').last;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfEditorScreen(
            filePath: draft.originalFilePath!,
            fileName: fileName,
            draftToResume: draft,
          ),
        ),
      ).then((_) => _loadDrafts());
    } else if (draft.type == DraftType.docScanner) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocScannerScreen(
            draftToResume: draft,
          ),
        ),
      ).then((_) => _loadDrafts());
    } else if (draft.type == DraftType.officeDoc && draft.originalFilePath != null) {
      final fileName = draft.originalFilePath!.split('/').last;
      if (draft.stateData['format'] == 'docx') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WordEditorScreen(
              filePath: draft.originalFilePath!,
              fileName: fileName,
              draftToResume: draft,
            ),
          ),
        ).then((_) => _loadDrafts());
      } else if (draft.stateData['format'] == 'xlsx') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExcelEditorScreen(
              filePath: draft.originalFilePath!,
              fileName: fileName,
              draftToResume: draft,
            ),
          ),
        ).then((_) => _loadDrafts());
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ড্রাফটটি রিজিউম করতে অক্ষম')),
      );
    }
  }

  void _deleteDraft(String id) async {
    await _draftService.deleteDraft(id);
    _loadDrafts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ড্রাফটটি মুছে ফেলা হয়েছে')),
      );
    }
  }

  void _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('সব ড্রাফট মুছবেন?'),
        content: const Text('আপনার অসম্পূর্ণ সব কাজের ড্রাফট ডিলিট হয়ে যাবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('সব মুছুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _draftService.clearAllDrafts();
      _loadDrafts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('অসম্পূর্ণ কাজের ড্রাফট (Drafts)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_drafts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
              tooltip: 'সব মুছুন',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.drafts_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('কোনো অসম্পূর্ণ ড্রাফট নেই', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'কাজ অসম্পূর্ণ রেখে অ্যাপ থেকে বের হয়ে গেলে এখানে জমা থাকবে।',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _drafts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final d = _drafts[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    d.typeLabel,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('dd MMM, hh:mm a').format(d.updatedAt),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              d.title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _deleteDraft(d.id),
                                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                  label: const Text('মুছে ফেলুন', style: TextStyle(color: AppColors.error)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red.shade200),
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: () => _resumeDraft(d),
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('কন্টিনিউ করুন'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
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
