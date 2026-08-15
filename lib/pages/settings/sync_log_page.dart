import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/sync_service.dart';

/// سجل عمليات المزامنة — عرض فقط، مصدره AppPreferences.keySyncLog (نص مسطَّح
/// سطر واحد لكل عملية، وليس سجلاً هيكلياً JSON كسجل النسخ الاحتياطي — كافٍ
/// لهذه المرحلة التجريبية الأولى للمزامنة).
class SyncLogPage extends StatefulWidget {
  const SyncLogPage({super.key});

  @override
  State<SyncLogPage> createState() => _SyncLogPageState();
}

class _SyncLogPageState extends State<SyncLogPage> {
  bool _isLoading = true;
  List<String> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await SyncService.getLastSyncLog();
    if (!mounted) return;
    setState(() {
      _entries = raw.isEmpty ? const [] : raw.split('\n');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("سجل عمليات المزامنة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      const SizedBox(height: AppSizes.md),
                      const Text("لا توجد عمليات مزامنة مسجَّلة بعد", style: AppTextStyles.bodyBold),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
                  itemBuilder: (context, index) => _buildEntry(_entries[index]),
                ),
    );
  }

  Widget _buildEntry(String line) {
    final failed = line.contains('فشل');
    final color = failed ? AppColors.danger : AppColors.success;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(failed ? Icons.error_outline : Icons.cloud_done_outlined, color: color),
        ),
        title: Text(line, style: AppTextStyles.caption),
      ),
    );
  }
}
