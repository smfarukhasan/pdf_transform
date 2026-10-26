import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../models/recent_item.dart';
import '../../../services/recent_service.dart';
import '../../reader/document_reader_screen.dart';

class RecentListWidget extends StatelessWidget {
  final List<RecentItem> items;
  final VoidCallback onRefresh;

  const RecentListWidget({
    super.key,
    required this.items,
    required this.onRefresh,
  });

  void _openItem(BuildContext context, RecentItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentReaderScreen(
          filePath: item.filePath,
          fileName: item.fileName,
        ),
      ),
    ).then((_) => onRefresh());
  }

  void _removeItem(BuildContext context, RecentItem item) async {
    final recentService = RecentService();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('হিস্ট্রি থেকে সরাবেন?'),
        content: Text(
          'আপনি কি "${item.fileName}" ফাইলটি শুধু রিসেন্ট তালিকা থেকে সরাতে চান?\n\n(নোট: আপনার ফোনের আসল ফাইলের কোনো ক্ষতি হবে না, অক্ষত থাকবে)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('তালিকা থেকে সরান', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await recentService.removeFromRecent(item.filePath);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('রিসেন্ট তালিকা থেকে সরানো হয়েছে (আসল ফাইল অক্ষত আছে)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.menu_book_outlined, color: Colors.grey, size: 36),
              SizedBox(height: 8),
              Text(
                'এখনও কোনো ফাইল পড়া হয়নি',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                'উপরের "ওপেন করুন" বাটন দিয়ে যেকোনো ফাইল ওপেন করলে এখানে তালিকা আকারে জমা হতে থাকবে।',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final exists = File(item.filePath).existsSync();

        return Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            onTap: () => _openItem(context, item),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getFileColor(item.fileName).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getFileIcon(item.fileName), color: _getFileColor(item.fileName), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'পড়ার অগ্রগতি: পেজ ${item.lastPage} / ${item.totalPages > 0 ? item.totalPages : 1} (${item.formattedProgress})',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        tooltip: 'তালিকা থেকে রিমুভ',
                        onPressed: () => _removeItem(context, item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress indicator bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade200,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          DateFormat('dd MMM, hh:mm a').format(item.lastReadTime),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!exists)
                        const Text(
                          'ফাইলটি সরানো হয়েছে',
                          style: TextStyle(fontSize: 11, color: AppColors.error),
                        )
                      else
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('পড়া চালিয়ে যান', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return Icons.description;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return Icons.table_chart;
    if (lower.endsWith('.pptx') || lower.endsWith('.ppt')) return Icons.slideshow;
    if (['.jpg', '.jpeg', '.png', '.webp'].any((e) => lower.endsWith(e))) return Icons.image;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Colors.red.shade700;
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return Colors.blue.shade700;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return Colors.green.shade700;
    if (lower.endsWith('.pptx') || lower.endsWith('.ppt')) return Colors.orange.shade800;
    return AppColors.primary;
  }
}
