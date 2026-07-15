import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/backup_service.dart';

/// إدارة النسخ الاحتياطية المحلية المخزَّنة على الجهاز — عرض/استعادة/حذف.
class BackupListPage extends StatefulWidget {
  const BackupListPage({super.key});

  @override
  State<BackupListPage> createState() => _BackupListPageState();
}

class _BackupListPageState extends State<BackupListPage> {
  bool _isLoading = true;
  List<BackupInfo> _backups = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final backups = await BackupService.listBackups();
    if (!mounted) return;
    setState(() {
      _backups = backups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إدارة النسخ الاحتياطية", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _backups.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: _backups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
                    itemBuilder: (context, index) => _buildBackupCard(_backups[index]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.md),
            const Text("لا توجد نسخ احتياطية محفوظة بعد", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.xs),
            const Text("قم بإنشاء نسخة احتياطية من الصفحة السابقة", style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCard(BackupInfo backup) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.xs),
        leading: CircleAvatar(
          backgroundColor: primary.withOpacity(0.1),
          child: Icon(Icons.description_outlined, color: primary),
        ),
        title: Text(
          DateFormat('yyyy/MM/dd — HH:mm', 'ar').format(backup.createdAt),
          style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
        ),
        subtitle: Text(backup.sizeLabel, style: AppTextStyles.caption),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'restore') _confirmRestore(backup);
            if (value == 'delete') _confirmDelete(backup);
            if (value == 'open') OpenFilex.open(backup.filePath);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'restore', child: Text("استعادة هذه النسخة")),
            PopupMenuItem(value: 'open', child: Text("مشاركة/فتح الملف")),
            PopupMenuItem(value: 'delete', child: Text("حذف", style: TextStyle(color: AppColors.danger))),
          ],
        ),
      ),
    );
  }

  void _confirmRestore(BackupInfo backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("استعادة نسخة احتياطية"),
        content: const Text(
          "سيتم استبدال جميع البيانات الحالية ببيانات هذه النسخة. سيُنشأ تلقائياً نسخة أمان من الحالة الحالية قبل الاستبدال. يُنصح بإغلاق التطبيق وإعادة فتحه بعد الانتهاء.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _runRestore(backup);
            },
            child: const Text("استعادة", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _runRestore(BackupInfo backup) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final error = await BackupService.restoreBackup(backup.filePath);
    if (!mounted) return;
    Navigator.pop(context);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تمت الاستعادة بنجاح"),
        content: const Text("يرجى إغلاق التطبيق بالكامل وإعادة فتحه الآن حتى تظهر البيانات المستعادة بشكل صحيح."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً")),
        ],
      ),
    );
  }

  void _confirmDelete(BackupInfo backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف النسخة الاحتياطية"),
        content: const Text("هل أنت متأكد من حذف هذه النسخة نهائياً؟ لا يمكن التراجع عن هذا الإجراء."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await BackupService.deleteBackup(backup.filePath);
              await _load();
            },
            child: const Text("حذف", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
