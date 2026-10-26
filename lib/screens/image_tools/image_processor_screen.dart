import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../constants/app_colors.dart';
import '../../services/image_tool_service.dart';
import '../common/save_export_dialog.dart';

class ImageProcessorScreen extends StatefulWidget {
  final String? filePath;

  const ImageProcessorScreen({super.key, this.filePath});

  @override
  State<ImageProcessorScreen> createState() => _ImageProcessorScreenState();
}

class _ImageProcessorScreenState extends State<ImageProcessorScreen> with SingleTickerProviderStateMixin {
  final ImageToolService _imageToolService = ImageToolService();
  late TabController _tabController;

  Uint8List? _originalBytes;
  Uint8List? _processedBytes;

  int _origWidth = 0;
  int _origHeight = 0;
  int _currentWidth = 0;
  int _currentHeight = 0;

  bool _keepAspectRatio = true;
  double _aspectRatio = 1.0;

  // Controllers for Resize
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  // Compress
  int _quality = 80;
  final TextEditingController _targetKbController = TextEditingController(text: '300');

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.filePath != null) {
      _loadFromFile(widget.filePath!);
    } else {
      _pickFromGallery();
    }
  }

  Future<void> _loadFromFile(String path) async {
    setState(() => _isLoading = true);
    final bytes = await File(path).readAsBytes();
    _setOriginalImage(bytes);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      _setOriginalImage(bytes);
    } else if (_originalBytes == null && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      _setOriginalImage(bytes);
    }
  }

  void _setOriginalImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      setState(() {
        _originalBytes = bytes;
        _processedBytes = bytes;
        _origWidth = decoded.width;
        _origHeight = decoded.height;
        _currentWidth = decoded.width;
        _currentHeight = decoded.height;
        _aspectRatio = decoded.width / decoded.height;
        _widthController.text = _currentWidth.toString();
        _heightController.text = _currentHeight.toString();
        _isLoading = false;
      });
    }
  }

  void _onWidthChanged(String val) {
    final w = int.tryParse(val);
    if (w != null && w > 0) {
      _currentWidth = w;
      if (_keepAspectRatio) {
        _currentHeight = (_currentWidth / _aspectRatio).round();
        _heightController.text = _currentHeight.toString();
      }
    }
  }

  void _onHeightChanged(String val) {
    final h = int.tryParse(val);
    if (h != null && h > 0) {
      _currentHeight = h;
      if (_keepAspectRatio) {
        _currentWidth = (_currentHeight * _aspectRatio).round();
        _widthController.text = _currentWidth.toString();
      }
    }
  }

  void _applyScalePreset(double scale) {
    setState(() {
      _currentWidth = (_origWidth * scale).round();
      _currentHeight = (_origHeight * scale).round();
      _widthController.text = _currentWidth.toString();
      _heightController.text = _currentHeight.toString();
    });
    _applyResize();
  }

  void _applyResize() {
    if (_originalBytes == null) return;
    try {
      final resized = _imageToolService.resizeImage(
        inputBytes: _originalBytes!,
        targetWidth: _currentWidth,
        targetHeight: _currentHeight,
      );
      setState(() {
        _processedBytes = resized;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('রিসাইজ প্রয়োগ করা হয়েছে')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('রিসাইজ ত্রুটি: $e')),
      );
    }
  }

  void _applyCropRatio(double ratio) {
    if (_originalBytes == null) return;
    final decoded = img.decodeImage(_processedBytes ?? _originalBytes!);
    if (decoded == null) return;

    int cropW = decoded.width;
    int cropH = decoded.height;

    if (decoded.width / decoded.height > ratio) {
      cropW = (decoded.height * ratio).round();
    } else {
      cropH = (decoded.width / ratio).round();
    }

    final cropX = (decoded.width - cropW) ~/ 2;
    final cropY = (decoded.height - cropH) ~/ 2;

    try {
      final cropped = _imageToolService.cropImage(
        inputBytes: _processedBytes ?? _originalBytes!,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );
      setState(() {
        _processedBytes = cropped;
        final d = img.decodeImage(cropped);
        if (d != null) {
          _currentWidth = d.width;
          _currentHeight = d.height;
          _widthController.text = _currentWidth.toString();
          _heightController.text = _currentHeight.toString();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ক্রপ সফলভাবে সম্পন্ন হয়েছে')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ক্রপ ত্রুটি: $e')),
      );
    }
  }

  void _applyQualityCompression() {
    if (_originalBytes == null) return;
    try {
      final compressed = _imageToolService.compressImage(
        inputBytes: _processedBytes ?? _originalBytes!,
        quality: _quality,
      );
      setState(() {
        _processedBytes = compressed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('কোয়ালিটি $_quality% এ কম্প্রেস করা হয়েছে')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('কম্প্রেশন ত্রুটি: $e')),
      );
    }
  }

  void _applyTargetKbCompression() {
    final target = int.tryParse(_targetKbController.text.trim());
    if (target == null || target <= 0) return;

    try {
      final compressed = _imageToolService.compressToTargetKb(
        inputBytes: _processedBytes ?? _originalBytes!,
        targetKb: target,
      );
      setState(() {
        _processedBytes = compressed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('টার্গেট ${target}KB এর মধ্যে কম্প্রেস করা হয়েছে')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('টার্গেট কম্প্রেশন ত্রুটি: $e')),
      );
    }
  }

  void _resetToOriginal() {
    setState(() {
      _processedBytes = _originalBytes;
      _currentWidth = _origWidth;
      _currentHeight = _origHeight;
      _widthController.text = _origWidth.toString();
      _heightController.text = _origHeight.toString();
    });
  }

  Future<void> _saveImage() async {
    if (_processedBytes == null) return;

    final saveConfig = await SaveExportDialog.show(
      context,
      defaultFileName: 'Image_${DateTime.now().millisecondsSinceEpoch}',
      currentExtension: 'jpg',
      availableExtensions: ['jpg', 'png'],
      canReplace: false,
    );

    if (saveConfig == null) return;

    try {
      final path = await _imageToolService.saveImage(
        imageBytes: _processedBytes!,
        fileName: saveConfig.fileName,
        customDirPath: saveConfig.targetDirectoryPath,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ছবি সংরক্ষণ সফল!'),
            content: Text('KhubSojaDoc ফোল্ডারে সংরক্ষিত হয়েছে:\n$path'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সংরক্ষণ ব্যর্থ: $e')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _targetKbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final originalSizeStr = _originalBytes != null ? _formatBytes(_originalBytes!.lengthInBytes) : '0 KB';
    final processedSizeStr = _processedBytes != null ? _formatBytes(_processedBytes!.lengthInBytes) : '0 KB';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ইমেজ রিসাইজ, ক্রোপ ও সাইজ কমানো', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'রিসেট',
            onPressed: _resetToOriginal,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'ক্যামেরা',
            onPressed: _pickFromCamera,
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            tooltip: 'নতুন ছবি',
            onPressed: _pickFromGallery,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _processedBytes != null ? _saveImage : null,
              icon: const Icon(Icons.save, size: 16),
              label: const Text('সেভ'),
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
                // Image Preview Canvas
                Expanded(
                  flex: 5,
                  child: Container(
                    color: const Color(0xFF0F172A),
                    width: double.infinity,
                    child: Center(
                      child: _processedBytes != null
                          ? InteractiveViewer(
                              child: Image.memory(
                                _processedBytes!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Text('কোনো ছবি নির্বাচন করা হয়নি', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),

                // Dimension & File Size Status Bar (Responsive)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'রেজোলিউশন: $_currentWidth × $_currentHeight px',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'সাইজ: $processedSizeStr ${processedSizeStr != originalSizeStr ? '(আগে $originalSizeStr)' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _processedBytes != null && _processedBytes!.lengthInBytes < (_originalBytes?.lengthInBytes ?? 0)
                              ? AppColors.secondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tool Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(icon: Icon(Icons.aspect_ratio), text: 'রিসাইজ'),
                    Tab(icon: Icon(Icons.crop), text: 'ক্রোপ'),
                    Tab(icon: Icon(Icons.compress), text: 'সাইজ কমান'),
                  ],
                ),

                // Tab Views
                Expanded(
                  flex: 5,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 1. Resize Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _widthController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'প্রস্থ (Width px)'),
                                    onChanged: _onWidthChanged,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _heightController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'উচ্চতা (Height px)'),
                                    onChanged: _onHeightChanged,
                                  ),
                                ),
                              ],
                            ),
                            CheckboxListTile(
                              value: _keepAspectRatio,
                              title: const Text('অনুপাত ঠিক রাখুন (Keep Aspect Ratio)', style: TextStyle(fontSize: 13)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _keepAspectRatio = val ?? true),
                            ),
                            const SizedBox(height: 8),
                            const Text('স্কেল প্রিসেট:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton(onPressed: () => _applyScalePreset(0.25), child: const Text('25%')),
                                OutlinedButton(onPressed: () => _applyScalePreset(0.50), child: const Text('50%')),
                                OutlinedButton(onPressed: () => _applyScalePreset(0.75), child: const Text('75%')),
                                OutlinedButton(onPressed: () => _applyScalePreset(1.00), child: const Text('100%')),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _applyResize,
                                icon: const Icon(Icons.check),
                                label: const Text('রিসাইজ প্রয়োগ করুন'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Crop Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('অনুপাত নির্বাচন করে সেন্টারে ক্রপ করুন:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _applyCropRatio(1.0),
                                  icon: const Icon(Icons.crop_square, size: 16),
                                  label: const Text('স্কয়ার (1:1)'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _applyCropRatio(4 / 3),
                                  icon: const Icon(Icons.crop_3_2, size: 16),
                                  label: const Text('স্ট্যান্ডার্ড (4:3)'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _applyCropRatio(16 / 9),
                                  icon: const Icon(Icons.crop_16_9, size: 16),
                                  label: const Text('ওয়াইডস্ক্রিন (16:9)'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _applyCropRatio(9 / 16),
                                  icon: const Icon(Icons.stay_current_portrait, size: 16),
                                  label: const Text('মোবাইল স্টোরি (9:16)'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 3. Compress Size Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('কোয়ালিটি কম্প্রেশন: $_quality%', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Slider(
                              value: _quality.toDouble(),
                              min: 10,
                              max: 95,
                              divisions: 17,
                              activeColor: AppColors.primary,
                              label: '$_quality%',
                              onChanged: (val) => setState(() => _quality = val.toInt()),
                            ),
                            ElevatedButton.icon(
                              onPressed: _applyQualityCompression,
                              icon: const Icon(Icons.tune),
                              label: const Text('কোয়ালিটি অনুযায়ী সাইজ কমান'),
                            ),
                            const Divider(height: 24),
                            const Text('টার্গেট কিলোবাইট (KB) নির্ধারণ করে সাইজ কমান:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _targetKbController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      suffixText: 'KB',
                                      hintText: 'যেমন: 200',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _applyTargetKbCompression,
                                  icon: const Icon(Icons.compress),
                                  label: const Text('টার্গেটে কমান'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
