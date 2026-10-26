import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/draft_item.dart';
import '../../services/office_service.dart';
import '../../services/draft_service.dart';
import '../common/save_export_dialog.dart';

class ExcelEditorScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final DraftItem? draftToResume;

  const ExcelEditorScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.draftToResume,
  });

  @override
  State<ExcelEditorScreen> createState() => _ExcelEditorScreenState();
}

class _ExcelEditorScreenState extends State<ExcelEditorScreen> {
  final OfficeService _officeService = OfficeService();
  final DraftService _draftService = DraftService();

  Map<String, List<List<String>>> _sheetsData = {};
  String _activeSheet = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  late String _draftId;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftToResume?.id ?? 'draft_xlsx_${DateTime.now().millisecondsSinceEpoch}';
    _loadExcel();
  }

  Future<void> _loadExcel() async {
    setState(() => _isLoading = true);
    final data = await _officeService.readExcelData(widget.filePath);

    if (data.isNotEmpty) {
      _sheetsData = data;
      _activeSheet = data.keys.first;
    } else {
      _sheetsData = {
        'Sheet1': [
          ['কলাম ১', 'কলাম ২', 'কলাম ৩'],
          ['ডাটা ১', 'ডাটা ২', 'ডাটা ৩'],
        ]
      };
      _activeSheet = 'Sheet1';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _autoSaveDraft() async {
    if (!_hasUnsavedChanges) return;

    final draft = DraftItem(
      id: _draftId,
      title: 'এক্সসেল এডিটিং: ${widget.fileName}',
      type: DraftType.officeDoc,
      originalFilePath: widget.filePath,
      stateData: {
        'format': 'xlsx',
        'activeSheet': _activeSheet,
      },
      updatedAt: DateTime.now(),
    );

    await _draftService.saveDraft(draft);
  }

  void _editCell(int rowIndex, int colIndex) async {
    final currentVal = _sheetsData[_activeSheet]![rowIndex][colIndex];
    final controller = TextEditingController(text: currentVal);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('সেল এডিট (Row: ${rowIndex + 1}, Col: ${colIndex + 1})'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'ভ্যালু লিখুন...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('আপডেট'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _sheetsData[_activeSheet]![rowIndex][colIndex] = result;
        _hasUnsavedChanges = true;
      });
      _autoSaveDraft();
    }
  }

  void _addRow() {
    setState(() {
      final rows = _sheetsData[_activeSheet]!;
      final colCount = rows.isNotEmpty ? rows.first.length : 3;
      rows.add(List.generate(colCount, (_) => ''));
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  void _addColumn() {
    setState(() {
      final rows = _sheetsData[_activeSheet]!;
      for (final r in rows) {
        r.add('');
      }
      _hasUnsavedChanges = true;
    });
    _autoSaveDraft();
  }

  Future<void> _saveExcel() async {
    final saveConfig = await SaveExportDialog.show(
      context,
      defaultFileName: widget.fileName,
      currentExtension: 'xlsx',
      availableExtensions: ['xlsx'],
      canReplace: true,
      originalFilePath: widget.filePath,
    );

    if (saveConfig == null) return;

    setState(() => _isSaving = true);
    try {
      final savedPath = await _officeService.saveExcelFile(
        originalPath: widget.filePath,
        sheetsData: _sheetsData,
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
          SnackBar(content: Text('সংরক্ষণ করতে ব্যর্থ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _sheetsData[_activeSheet] ?? [];

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
              const Text('এক্সসেল (XLSX) এডিটর', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(widget.fileName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              tooltip: 'নতুন সারি (Row) যোগ করুন',
              onPressed: _addRow,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveExcel,
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
            : Column(
                children: [
                  // Sheets tab bar
                  if (_sheetsData.keys.length > 1)
                    Container(
                      height: 44,
                      color: Colors.grey.shade100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _sheetsData.keys.map((sheetName) {
                          final isSelected = sheetName == _activeSheet;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: ChoiceChip(
                              label: Text(sheetName),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                              onSelected: (val) {
                                if (val) setState(() => _activeSheet = sheetName);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Action tools
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey.shade50,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.table_rows, size: 16),
                          label: const Text('+ সারি (Row)', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _addColumn,
                          icon: const Icon(Icons.view_column, size: 16),
                          label: const Text('+ কলাম (Col)', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                        const Spacer(),
                        const Text('যে কোনো সেলে চাপ দিয়ে এডিট করুন', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),

                  // Interactive Spreadsheet Grid
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('এই শিটে কোনো ডাটা নেই'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                                border: TableBorder.all(color: Colors.grey.shade300),
                                columns: List.generate(
                                  rows.first.length,
                                  (index) => DataColumn(
                                    label: Text(
                                      String.fromCharCode(65 + index), // A, B, C...
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                rows: List.generate(
                                  rows.length,
                                  (rIndex) {
                                    final row = rows[rIndex];
                                    return DataRow(
                                      cells: List.generate(
                                        row.length,
                                        (cIndex) {
                                          final val = row[cIndex];
                                          return DataCell(
                                            Text(val.isEmpty ? '-' : val),
                                            onTap: () => _editCell(rIndex, cIndex),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
