import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/storage_service.dart';

class SaveExportConfig {
  final bool isNewCopy; // true = new copy, false = replace
  final String fileName;
  final String fileFormat;
  final String quality;
  final String targetDirectoryPath;

  SaveExportConfig({
    required this.isNewCopy,
    required this.fileName,
    required this.fileFormat,
    required this.quality,
    required this.targetDirectoryPath,
  });
}

class SaveExportDialog extends StatefulWidget {
  final String defaultFileName;
  final String currentExtension;
  final List<String> availableExtensions;
  final bool canReplace;
  final String? originalFilePath;

  const SaveExportDialog({
    super.key,
    required this.defaultFileName,
    required this.currentExtension,
    this.availableExtensions = const ['pdf', 'docx', 'txt', 'jpg', 'png'],
    this.canReplace = true,
    this.originalFilePath,
  });

  static Future<SaveExportConfig?> show(
    BuildContext context, {
    required String defaultFileName,
    required String currentExtension,
    List<String> availableExtensions = const ['pdf', 'docx', 'txt', 'jpg', 'png'],
    bool canReplace = true,
    String? originalFilePath,
  }) {
    return showDialog<SaveExportConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SaveExportDialog(
        defaultFileName: defaultFileName,
        currentExtension: currentExtension,
        availableExtensions: availableExtensions,
        canReplace: canReplace,
        originalFilePath: originalFilePath,
      ),
    );
  }

  @override
  State<SaveExportDialog> createState() => _SaveExportDialogState();
}

class _SaveExportDialogState extends State<SaveExportDialog> {
  final StorageService _storageService = StorageService();
  late TextEditingController _nameController;

  bool _isNewCopy = true;
  late String _selectedFormat;
  String _selectedQuality = AppConstants.qualityStandard;
  String _targetDirectory = '';
  bool _isLoadingDir = true;

  @override
  void initState() {
    super.initState();
    var cleanName = widget.defaultFileName;
    if (cleanName.contains('.')) {
      cleanName = cleanName.substring(0, cleanName.lastIndexOf('.'));
    }
    _nameController = TextEditingController(text: cleanName);
    _selectedFormat = widget.currentExtension.toLowerCase();

    _loadDefaultDirectory();
  }

  Future<void> _loadDefaultDirectory() async {
    final dir = await _storageService.getAppDirectory();
    if (mounted) {
      setState(() {
        _targetDirectory = dir.path;
        _isLoadingDir = false;
      });
    }
  }

  Future<void> _pickCustomDirectory() async {
    final result = await FilePicker.getDirectoryPath();
    if (result != null && mounted) {
      setState(() {
        _targetDirectory = result;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.save_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ফাইল সেভ ও এক্সপোর্ট',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 1. Save Mode (Replace vs New Copy)
              if (widget.canReplace && widget.originalFilePath != null) ...[
                const Text(
                  'সেভ অপশন নির্বাচন করুন:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'নতুন কপি (New)',
                        isSelected: _isNewCopy,
                        icon: Icons.copy,
                        onTap: () => setState(() => _isNewCopy = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'রিপ্লেস (Replace)',
                        isSelected: !_isNewCopy,
                        icon: Icons.sync,
                        onTap: () => setState(() => _isNewCopy = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 2. File Name (Editable)
              if (_isNewCopy) ...[
                const Text(
                  'ফাইলের নাম:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    suffixText: '.$_selectedFormat',
                    prefixIcon: const Icon(Icons.edit_note),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. File Format
              const Text(
                'ফাইলের টাইপ/ফরম্যাট:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableExtensions.map((ext) {
                  final isSelected = _selectedFormat == ext.toLowerCase();
                  return ChoiceChip(
                    label: Text(
                      ext.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFormat = ext.toLowerCase());
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 4. Quality Selector
              const Text(
                'কোয়ালিটি নির্বাচন:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedQuality,
                    items: [
                      AppConstants.qualityHigh,
                      AppConstants.qualityStandard,
                      AppConstants.qualityCompressed,
                    ].map((q) {
                      return DropdownMenuItem(
                        value: q,
                        child: Text(q, style: const TextStyle(fontSize: 13.5)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedQuality = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Save Location (Default KhubSojaDoc)
              const Text(
                'সংরক্ষণ লোকেশন (ডিফল্ট: KhubSojaDoc):',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_special, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _isLoadingDir
                          ? const Text('লোড হচ্ছে...')
                          : Text(
                              _targetDirectory,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                    ),
                    TextButton(
                      onPressed: _pickCustomDirectory,
                      child: const Text('পরিবর্তন', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('বাতিল'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final finalName = _nameController.text.trim().isEmpty
                            ? 'Document_${DateTime.now().millisecondsSinceEpoch}'
                            : _nameController.text.trim();

                        final config = SaveExportConfig(
                          isNewCopy: _isNewCopy,
                          fileName: '$finalName.$_selectedFormat',
                          fileFormat: _selectedFormat,
                          quality: _selectedQuality,
                          targetDirectoryPath: _targetDirectory,
                        );

                        Navigator.pop(context, config);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('সংরক্ষণ করুন'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
