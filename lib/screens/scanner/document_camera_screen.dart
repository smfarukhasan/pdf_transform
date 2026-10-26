import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';

class DocumentCameraScreen extends StatefulWidget {
  const DocumentCameraScreen({super.key});

  @override
  State<DocumentCameraScreen> createState() => _DocumentCameraScreenState();
}

class _DocumentCameraScreenState extends State<DocumentCameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  // Document Guide Settings
  bool _showGuideBox = true;
  bool _showGridLines = true;
  FlashMode _flashMode = FlashMode.auto;

  final List<Uint8List> _capturedPages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCameraController(_availableCameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        await _setupCameraController(_availableCameras[0]);
      }
    } catch (_) {
      // Fallback handled in UI
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    FlashMode next;
    switch (_flashMode) {
      case FlashMode.auto:
        next = FlashMode.always;
        break;
      case FlashMode.always:
        next = FlashMode.off;
        break;
      case FlashMode.off:
        next = FlashMode.torch;
        break;
      case FlashMode.torch:
        next = FlashMode.auto;
        break;
    }
    await _cameraController!.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() => _isCameraInitialized = false);
    await _cameraController?.dispose();
    await _setupCameraController(_availableCameras[_selectedCameraIndex]);
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();

      if (mounted) {
        setState(() {
          _capturedPages.add(bytes);
          _isCapturing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('পেজ ${_capturedPages.length} ক্যাপচার সম্পন্ন! আরও পেজ তুলতে শাটার চাপুন।'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      setState(() {
        _capturedPages.add(bytes);
      });
    }
  }

  void _finishCapture() {
    Navigator.pop(context, _capturedPages);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('ডকুমেন্ট ক্যামেরা', style: TextStyle(color: Colors.white, fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.secondary),
              const SizedBox(height: 16),
              const Text('ক্যামেরা চালু হচ্ছে...', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('সিস্টেম ক্যামেরা ব্যবহার করুন'),
                onPressed: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    final bytes = await File(picked.path).readAsBytes();
                    if (context.mounted) {
                      Navigator.pop(context, [bytes]);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview
          Center(
            child: CameraPreview(_cameraController!),
          ),

          // 2. Visible Document Guide Box Overlay (বক্স গাইড)
          if (_showGuideBox) _buildDocumentGuideOverlay(),

          // 3. Grid Lines Overlay (Optional Alignment Assistance)
          if (_showGridLines) _buildGridLines(),

          // 4. Top Control Strip
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                  onPressed: () {
                    if (_capturedPages.isNotEmpty) {
                      _finishCapture();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                // Guide box toggle button
                InkWell(
                  onTap: () => setState(() => _showGuideBox = !_showGuideBox),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showGuideBox ? AppColors.secondary : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showGuideBox ? Icons.crop_free : Icons.crop_square_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showGuideBox ? 'গাইড বক্স: অন' : 'গাইড বক্স: অফ',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Grid toggle button
                IconButton(
                  icon: Icon(
                    _showGridLines ? Icons.grid_on : Icons.grid_off,
                    color: _showGridLines ? AppColors.secondary : Colors.white70,
                  ),
                  tooltip: 'গ্রিড লাইন অন/অফ',
                  onPressed: () => setState(() => _showGridLines = !_showGridLines),
                ),
                // Flash toggle
                IconButton(
                  icon: Icon(
                    _flashMode == FlashMode.always
                        ? Icons.flash_on
                        : _flashMode == FlashMode.torch
                            ? Icons.highlight
                            : _flashMode == FlashMode.off
                                ? Icons.flash_off
                                : Icons.flash_auto,
                    color: _flashMode != FlashMode.off ? Colors.amber : Colors.white,
                  ),
                  tooltip: 'ফ্ল্যাশ মোড',
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // 5. Instruction Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'ডকুমেন্টটি সোজাভাবে বক্সের ভেতরে রাখুন',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // 6. Bottom Controls Bar
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Captured Pages Counter & Preview Strip
                if (_capturedPages.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.secondary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${_capturedPages.length} টি পেজ ক্যাপচার্ড',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],

                // Main Capture Strip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery button
                    IconButton(
                      icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                      tooltip: 'গ্যালারি',
                      onPressed: _pickFromGallery,
                    ),

                    // Shutter button (Large & prominent)
                    GestureDetector(
                      onTap: _capturePhoto,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isCapturing ? AppColors.secondary : Colors.white24,
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: _isCapturing
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                                : const Icon(Icons.camera_alt, color: AppColors.primary, size: 30),
                          ),
                        ),
                      ),
                    ),

                    // Switch camera or Done button
                    if (_capturedPages.isEmpty)
                      IconButton(
                        icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 28),
                        tooltip: 'ক্যামেরা পরিবর্তন',
                        onPressed: _switchCamera,
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text('শেষ (${_capturedPages.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _finishCapture,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// High-visibility Document Frame Guide (বক্স গাইড)
  Widget _buildDocumentGuideOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        // Standard Document A4 Aspect Ratio (1 : 1.414)
        final boxW = screenW * 0.86;
        final boxH = boxW * 1.38;

        final left = (screenW - boxW) / 2;
        final top = (screenH - boxH) / 2 - 20;

        return Stack(
          children: [
            // Semi-transparent darkened mask outside the box
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.45),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    width: boxW,
                    height: boxH,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Crisp L-Bracket Corners and Outer Border
            Positioned(
              left: left,
              top: top,
              width: boxW,
              height: boxH,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: CustomPaint(
                  painter: _DocumentCornerBracketPainter(
                    cornerColor: AppColors.secondary,
                    cornerLength: 26,
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 3x3 Grid Lines overlay to help straight alignment
  Widget _buildGridLines() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        return IgnorePointer(
          child: CustomPaint(
            size: Size(screenW, screenH),
            painter: _GridLinesPainter(),
          ),
        );
      },
    );
  }
}

/// Custom painter for prominent L-brackets at document corners
class _DocumentCornerBracketPainter extends CustomPainter {
  final Color cornerColor;
  final double cornerLength;
  final double strokeWidth;

  _DocumentCornerBracketPainter({
    required this.cornerColor,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Top-Left Corner
    canvas.drawLine(const Offset(0, 0), Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerLength), paint);

    // Top-Right Corner
    canvas.drawLine(Offset(w, 0), Offset(w - cornerLength, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cornerLength), paint);

    // Bottom-Left Corner
    canvas.drawLine(Offset(0, h), Offset(cornerLength, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - cornerLength), paint);

    // Bottom-Right Corner
    canvas.drawLine(Offset(w, h), Offset(w - cornerLength, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3x3 Rule-of-thirds grid lines painter
class _GridLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    // Vertical lines
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);

    // Horizontal lines
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
