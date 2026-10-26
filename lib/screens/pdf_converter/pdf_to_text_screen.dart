import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../services/pdf_service.dart';
import '../../services/pdf_conversion_service.dart';
import '../common/save_export_dialog.dart';

class PdfToTextScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfToTextScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfToTextScreen> createState() => _PdfToTextScreenState();
}

class _PdfToTextScreenState extends State<PdfToTextScreen> {
  final PdfService _pdfService = PdfService();
  final PdfConversionService _conversionService = PdfConversionService();

  String _extractedText = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _extract();
  }

  Future<void> _extract() async {
    setState(() => _isLoading = true);
    final text = await _pdfService.extractText(widget.filePath);
    if (mounted) {
      setState(() {
        _extractedText = text;
        _isLoading = false;
      });
    }
  }

  void _copyAllToClipboard() {
    if (_extractedText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _extractedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('সম্পূর্ণ টেক্সট সফলভাবে ক্লিপবোর্ডে কপি করা হয়েছে!')),
    );
  }

  Future<void> _saveAsDocument() async {
    final saveConfig = await SaveExportDialog.show(
      context,
      defaultFileName: widget.fileName,
      currentExtension: 'docx',
      availableExtensions: ['docx', 'txt'],
      canReplace: false,
    );

    if (saveConfig == null) return;

    setState(() => _isSaving = true);
    try {
      String savedPath;
      if (saveConfig.fileFormat == 'docx') {
        savedPath = await _conversionService.convertPdfToDocx(
          widget.filePath,
          customName: saveConfig.fileName.replaceAll('.docx', ''),
        );
      } else {
        savedPath = await _conversionService.convertPdfToTextFile(
          widget.filePath,
          customName: saveConfig.fileName.replaceAll('.txt', ''),
        );
      }

      if (mounted) {
        setState(() => _isSaving = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('সংরক্ষণ সফল!'),
            content: Text('ডকুমেন্টটি সংরক্ষিত হয়েছে:\n$savedPath'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
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
        title: const Text('PDF থেকে টেক্সট ও DOCX', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: AppColors.primary),
            tooltip: 'সব টেক্সট কপি করুন',
            onPressed: _extractedText.isNotEmpty ? _copyAllToClipboard : null,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: AppColors.secondary),
            tooltip: 'DOCX / TXT হিসেবে সেভ',
            onPressed: _extractedText.isNotEmpty && !_isSaving ? _saveAsDocument : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'ইংরেজি ও ইউনিকোড টেক্সট কপি করে যেকোনো জায়গায় ব্যবহার করতে পারবেন অথবা DOCX হিসেবে সংরক্ষণ করতে পারবেন।',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _extractedText.isEmpty ? 'কোনো টেক্সট পাওয়া যায়নি।' : _extractedText,
                          style: const TextStyle(fontSize: 14, height: 1.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyAllToClipboard,
                          icon: const Icon(Icons.copy),
                          label: const Text('ক্লিপবোর্ডে কপি করুন'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveAsDocument,
                          icon: const Icon(Icons.description),
                          label: const Text('DOCX বানান'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
