import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../constants/app_colors.dart';
import '../../models/recent_item.dart';
import '../../models/draft_item.dart';
import '../../services/storage_service.dart';
import '../../services/recent_service.dart';
import '../../services/draft_service.dart';
import '../reader/file_browser_modal.dart';
import '../pdf_editor/pdf_editor_screen.dart';
import '../pdf_converter/pdf_to_image_screen.dart';
import '../pdf_converter/pdf_to_text_screen.dart';
import '../scanner/doc_scanner_screen.dart';
import '../image_tools/image_processor_screen.dart';
import '../drafts/drafts_screen.dart';
import '../folder_browser/khubsojadoc_folder_screen.dart';
import '../office/word_editor_screen.dart';
import '../office/excel_editor_screen.dart';
import '../office/pptx_editor_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/recent_list_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final RecentService _recentService = RecentService();
  final DraftService _draftService = DraftService();

  List<RecentItem> _recentItems = [];
  List<DraftItem> _activeDrafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Initialize KhubSojaDoc dedicated folder
    await _storageService.getAppDirectory();
    // 2. Request permissions
    await _storageService.requestStoragePermissions();
    // 3. Load data
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final recent = await _recentService.getRecentItems();
    final drafts = await _draftService.getAllDrafts();

    if (mounted) {
      setState(() {
        _recentItems = recent;
        _activeDrafts = drafts;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndOpenTool({
    required List<String> allowedExtensions,
    required Function(String path, String name) onSelected,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result != null && result.files.single.path != null) {
      onSelected(result.files.single.path!, result.files.single.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'KhubSojaDoc',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'খুব সোজা ডক',
                style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          // Drafts quick icon
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.drafts_outlined),
                tooltip: 'ড্রাফট তালিকা',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DraftsScreen()),
                  ).then((_) => _loadDashboardData());
                },
              ),
              if (_activeDrafts.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_activeDrafts.length}',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          // KhubSojaDoc Folder
          IconButton(
            icon: const Icon(Icons.folder_special, color: AppColors.primary),
            tooltip: 'KhubSojaDoc ফোল্ডার',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KhubSojaDocFolderScreen()),
              ).then((_) => _loadDashboardData());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Incomplete Work Drafts Banner (if any)
                    if (_activeDrafts.isNotEmpty) _buildDraftsAlertBanner(),

                    const SizedBox(height: 12),

                    // Primary Prominent "Open File" Button Section
                    _buildPrimaryOpenSection(),

                    // Recent Reading Section (Right below Open Button)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 18, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'সম্প্রতি পঠিত ফাইল (Recent Reading)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_recentItems.isNotEmpty)
                            Text(
                              '${_recentItems.length} টি ফাইল',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    RecentListWidget(
                      items: _recentItems,
                      onRefresh: _loadDashboardData,
                    ),

                    const SizedBox(height: 16),

                    // Feature Grid (হোম স্ক্রিনের সব টুলস)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.apps, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'অ্যাপের সমস্ত ফিচার ও টুলস',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    _buildFeaturesGrid(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }


  Widget _buildDraftsAlertBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DraftsScreen()),
          ).then((_) => _loadDashboardData());
        },
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'আপনার ${_activeDrafts.length} টি অসম্পূর্ণ ড্রাফট রয়েছে',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
                  ),
                  const Text(
                    'আগের কাজটি চালিয়ে যেতে এখানে ট্যাপ করুন',
                    style: TextStyle(fontSize: 11.5, color: Colors.brown),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DraftsScreen()),
                ).then((_) => _loadDashboardData());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text('কন্টিনিউ', style: TextStyle(fontSize: 11, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryOpenSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            FileBrowserModal.show(context).then((_) => _loadDashboardData());
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.file_open, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'যেকোনো ফাইল ওপেন করুন',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ফোনের সব ফাইল লিস্ট, সার্চ, ফিল্টার ও ফাইল ম্যানেজার',
                        style: TextStyle(
                          color: AppColors.accentLight,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    final List<Map<String, dynamic>> tools = [
      {
        'title': 'পিডিএফ পেজ এডিটর',
        'subtitle': 'পেজ ডিলিট ও কমানো, নতুন পেজ যোগ',
        'icon': Icons.edit_document,
        'gradient': AppColors.primaryGradient,
        'onTap': () {
          _pickAndOpenTool(
            allowedExtensions: ['pdf'],
            onSelected: (path, name) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PdfEditorScreen(filePath: path, fileName: name)),
              ).then((_) => _loadDashboardData());
            },
          );
        },
      },
      {
        'title': 'PDF থেকে ইমেজ কনভার্টার',
        'subtitle': 'সব পেজ ১, ২, ৩... বা মার্ক করা পেজ',
        'icon': Icons.collections,
        'gradient': AppColors.accentGradient,
        'onTap': () {
          _pickAndOpenTool(
            allowedExtensions: ['pdf'],
            onSelected: (path, name) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PdfToImageScreen(filePath: path, fileName: name)),
              ).then((_) => _loadDashboardData());
            },
          );
        },
      },
      {
        'title': 'ডকুমেন্ট স্ক্যানার (Scan to PDF)',
        'subtitle': 'ক্যামেরা দিয়ে স্ক্যান করে PDF তৈরি',
        'icon': Icons.document_scanner,
        'gradient': AppColors.emeraldGradient,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DocScannerScreen()),
          ).then((_) => _loadDashboardData());
        },
      },
      {
        'title': 'ওয়ার্ড (DOCX) এডিটর',
        'subtitle': 'প্যারাগ্রাফ ও টেক্সট মডিফিকেশন',
        'icon': Icons.description,
        'gradient': AppColors.purpleGradient,
        'onTap': () {
          _pickAndOpenTool(
            allowedExtensions: ['docx', 'doc'],
            onSelected: (path, name) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WordEditorScreen(filePath: path, fileName: name)),
              ).then((_) => _loadDashboardData());
            },
          );
        },
      },
      {
        'title': 'এক্সসেল (XLSX) এডিটর',
        'subtitle': 'সেল ডাটা, রো ও কলাম পরিবর্তন',
        'icon': Icons.table_chart,
        'gradient': AppColors.emeraldGradient,
        'onTap': () {
          _pickAndOpenTool(
            allowedExtensions: ['xlsx', 'xls'],
            onSelected: (path, name) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ExcelEditorScreen(filePath: path, fileName: name)),
              ).then((_) => _loadDashboardData());
            },
          );
        },
      },
      {
        'title': 'পাওয়ারপয়েন্ট (PPTX) এডিটর',
        'subtitle': 'স্লাইড টেক্সট এডিট ও সেভ',
        'icon': Icons.slideshow,
        'gradient': AppColors.amberGradient,
        'onTap': () {
          _pickAndOpenTool(
            allowedExtensions: ['pptx', 'ppt'],
            onSelected: (path, name) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PptxEditorScreen(filePath: path, fileName: name)),
              ).then((_) => _loadDashboardData());
            },
          );
        },
      },
      {
        'title': 'ইমেজ রিসাইজ, ক্রপ ও সাইজ কমান',
        'subtitle': 'ছবির কোয়ালিটি ও KB কমানো',
        'icon': Icons.photo_size_select_actual,
        'gradient': AppColors.purpleGradient,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ImageProcessorScreen()),
          ).then((_) => _loadDashboardData());
        },
      },
      {
        'title': 'ইংরেজি টেক্সট কপি ও DOCX',
        'subtitle': 'PDF থেকে টেক্সট কপি ও ওয়ার্ড ফাইল',
        'icon': Icons.text_snippet,
        'gradient': AppColors.primaryGradient,
        'onTap': () {
          _pickAndOpenTool(
            allowedExtensions: ['pdf'],
            onSelected: (path, name) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PdfToTextScreen(filePath: path, fileName: name)),
              ).then((_) => _loadDashboardData());
            },
          );
        },
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Responsive columns: 2 on mobile, 3 on small tablets/foldables, 4 on large tablets
        final crossAxisCount = width > 850 ? 4 : (width > 550 ? 3 : 2);
        // Adaptive aspect ratio to guarantee text fits with zero overflow
        final childAspectRatio = width < 360 ? 1.05 : (width > 550 ? 1.3 : 1.16);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final t = tools[index];
            return Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.2,
                ),
              ),
              child: InkWell(
                onTap: t['onTap'] as VoidCallback,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: t['gradient'] as LinearGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t['icon'] as IconData, color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: width < 360 ? 12 : 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t['subtitle'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: width < 360 ? 9.5 : 10.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
