import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../constants/app_colors.dart';
import '../../reader/file_browser_modal.dart';
import '../../pdf_editor/pdf_editor_screen.dart';
import '../../pdf_converter/pdf_to_image_screen.dart';
import '../../pdf_converter/pdf_to_text_screen.dart';
import '../../scanner/doc_scanner_screen.dart';
import '../../image_tools/image_processor_screen.dart';
import '../../drafts/drafts_screen.dart';
import '../../folder_browser/khubsojadoc_folder_screen.dart';
import '../../office/word_editor_screen.dart';
import '../../office/excel_editor_screen.dart';
import '../../office/pptx_editor_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _pickAndRoute(
    BuildContext context, {
    required List<String> extensions,
    required Function(String path, String name) onPicked,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      Navigator.pop(context); // close drawer
      onPicked(result.files.single.path!, result.files.single.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.auto_stories,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Transformer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'স্মার্ট ডকুমেন্ট ও অফিস স্যুট',
                        style: TextStyle(
                          color: AppColors.accentLight,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Quick Open
                ListTile(
                  leading: const Icon(Icons.file_open, color: AppColors.primary),
                  title: const Text('যেকোনো ফাইল ওপেন করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    FileBrowserModal.show(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_special, color: AppColors.primaryLight),
                  title: const Text('KhubSojaDoc ফোল্ডার', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('অ্যাপের সব কাজের ফাইল দেখুন'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const KhubSojaDocFolderScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.drafts, color: AppColors.warning),
                  title: const Text('অসম্পূর্ণ ড্রাফট তালিকা (Drafts)', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DraftsScreen()),
                    );
                  },
                ),
                const Divider(),

                // Category: PDF Tools
                _buildSectionHeader('পিডিএফ টুলস (PDF Tools)'),
                ListTile(
                  leading: const Icon(Icons.edit_document, color: Colors.red),
                  title: const Text('পিডিএফ পেজ এডিটর'),
                  subtitle: const Text('পেজ ডিলিট ও কমানো, নতুন পেজ যোগ'),
                  onTap: () {
                    _pickAndRoute(
                      context,
                      extensions: ['pdf'],
                      onPicked: (path, name) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfEditorScreen(filePath: path, fileName: name),
                          ),
                        );
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.collections, color: Colors.blue),
                  title: const Text('PDF থেকে ইমেজ কনভার্টার'),
                  subtitle: const Text('সব পেজ ১, ২, ৩... বা মার্ক করা পেজ'),
                  onTap: () {
                    _pickAndRoute(
                      context,
                      extensions: ['pdf'],
                      onPicked: (path, name) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfToImageScreen(filePath: path, fileName: name),
                          ),
                        );
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet, color: Colors.teal),
                  title: const Text('PDF থেকে টেক্সট ও ওয়ার্ড'),
                  subtitle: const Text('ইংরেজি টেক্সট কপি ও DOCX রূপান্তর'),
                  onTap: () {
                    _pickAndRoute(
                      context,
                      extensions: ['pdf'],
                      onPicked: (path, name) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfToTextScreen(filePath: path, fileName: name),
                          ),
                        );
                      },
                    );
                  },
                ),
                const Divider(),

                // Category: Office Suite
                _buildSectionHeader('অফিস ফাইল এডিটর (Office Suite)'),
                ListTile(
                  leading: const Icon(Icons.description, color: Colors.blueAccent),
                  title: const Text('ওয়ার্ড (DOCX) এডিটর'),
                  subtitle: const Text('প্যারাগ্রাফ ও টেক্সট পরিবর্তন'),
                  onTap: () {
                    _pickAndRoute(
                      context,
                      extensions: ['docx', 'doc'],
                      onPicked: (path, name) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WordEditorScreen(filePath: path, fileName: name),
                          ),
                        );
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('এক্সসেল (XLSX) এডিটর'),
                  subtitle: const Text('সেল ভ্যালু ও শিট পরিবর্তন'),
                  onTap: () {
                    _pickAndRoute(
                      context,
                      extensions: ['xlsx', 'xls'],
                      onPicked: (path, name) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExcelEditorScreen(filePath: path, fileName: name),
                          ),
                        );
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.slideshow, color: Colors.orange),
                  title: const Text('পাওয়ারপয়েন্ট (PPTX) এডিটর'),
                  subtitle: const Text('স্লাইড টেক্সট মডিফিকেশন'),
                  onTap: () {
                    _pickAndRoute(
                      context,
                      extensions: ['pptx', 'ppt'],
                      onPicked: (path, name) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PptxEditorScreen(filePath: path, fileName: name),
                          ),
                        );
                      },
                    );
                  },
                ),
                const Divider(),

                // Category: Image & Scanner
                _buildSectionHeader('ইমেজ ও স্ক্যানার (Image & Scan)'),
                ListTile(
                  leading: const Icon(Icons.document_scanner, color: AppColors.secondary),
                  title: const Text('ডকুমেন্ট স্ক্যানার (Scan to PDF)'),
                  subtitle: const Text('ক্যামেরা দিয়ে স্ক্যান করে PDF তৈরি'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DocScannerScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_size_select_actual, color: AppColors.purple),
                  title: const Text('ইমেজ রিসাইজ ও ক্রোপ'),
                  subtitle: const Text('ছবির সাইজ বা KB কমানো'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ImageProcessorScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('KhubSojaDoc v1.0', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text('Android 12+ (minSdk 31)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
