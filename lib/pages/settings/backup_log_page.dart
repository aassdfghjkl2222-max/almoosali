import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/backup_service.dart';

/// سجل عمليات النسخ الاحتياطي والاستعادة — عرض فقط، محمَّل تدريجياً.
class BackupLogPage extends StatefulWidget {
  const BackupLogPage({super.key});

  @override
  State<BackupLogPage> createState() => _BackupLogPageState();
}

class _BackupLogPageState extends State<BackupLogPage> {
  static const _pageSize = 20;
  bool _isLoading = true;
  List<BackupLogEntry> _all = const [];
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await BackupService.getLog();
    if (!mounted) return;
    setState(() {
      _all = log;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _all.take(_visibleCount).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("سجل عمليات النسخ الاحتياطي", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _all.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_toggle_off, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      const SizedBox(height: AppSizes.md),
                      const Text("لا توجد عمليات مسجَّلة بعد", style: AppTextStyles.bodyBold),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: visible.length + (visible.length < _all.length ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
                  itemBuilder: (context, index) {
                    if (index == visible.length) {
                      return Center(
                        child: TextButton(
                          onPressed: () => setState(() => _visibleCount += _pageSize),
                          child: const Text("عرض المزيد"),
                        ),
                      );
                    }
                    return _buildEntry(visible[index]);
                  },
                ),
    );
  }

  Widget _buildEntry(BackupLogEntry entry) {
    final isBackup = entry.type == 'backup';
    final color = !entry.success ? AppColors.danger : (isBackup ? AppColors.success : AppColors.info);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            !entry.success
                ? Icons.error_outline
                : (isBackup ? Icons.upload_rounded : Icons.download_rounded),
            color: color,
          ),
        ),
        title: Text(
          isBackup ? "إنشاء نسخة احتياطية" : "استعادة من نسخة احتياطية",
          style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
        ),
        subtitle: Text(
          "${entry.fileName}\n${DateFormat('yyyy/MM/dd — HH:mm', 'ar').format(entry.timestamp)}",
          style: AppTextStyles.caption,
        ),
        isThreeLine: true,
        trailing: Text(
          entry.success ? "نجحت" : "فشلت",
          style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
