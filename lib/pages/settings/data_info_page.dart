import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/database/database_service.dart';

/// "البيانات" — للعرض فقط، بلا أي حذف أو تنظيف في هذه المرحلة كما طُلب.
/// كل رقم هنا حقيقي: حجم ملف قاعدة البيانات الفعلي، وعدد السجلات الفعلي في
/// كل جدول عبر استعلام sqlite_master، وحجم مجلد مستندات التطبيق الفعلي.
class DataInfoPage extends StatefulWidget {
  const DataInfoPage({super.key});

  @override
  State<DataInfoPage> createState() => _DataInfoPageState();
}

class _DataInfoPageState extends State<DataInfoPage> {
  bool _isLoading = true;
  int _dbSizeBytes = 0;
  int _totalRecords = 0;
  int _tableCount = 0;
  int _appFilesSizeBytes = 0;
  List<MapEntry<String, int>> _tableCounts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dbPath = join(await getDatabasesPath(), 'manazel.db');
    final dbFile = File(dbPath);
    final dbSize = await dbFile.exists() ? await dbFile.length() : 0;

    final db = await DatabaseService().database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'");

    final counts = <MapEntry<String, int>>[];
    int total = 0;
    for (final t in tables) {
      final name = t['name'] as String;
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as c FROM "$name"');
        final c = (result.first['c'] as int?) ?? 0;
        counts.add(MapEntry(name, c));
        total += c;
      } catch (_) {}
    }
    counts.sort((a, b) => b.value.compareTo(a.value));

    int filesSize = 0;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      if (await docsDir.exists()) {
        await for (final entity in docsDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              filesSize += await entity.length();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _dbSizeBytes = dbSize;
      _tableCounts = counts;
      _totalRecords = total;
      _tableCount = tables.length;
      _appFilesSizeBytes = filesSize;
      _isLoading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes بايت";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} كيلوبايت";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} ميغابايت";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("البيانات"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildCard([
                  _infoRow(Icons.storage_outlined, "حجم قاعدة البيانات", _formatBytes(_dbSizeBytes)),
                  _infoRow(Icons.table_chart_outlined, "عدد الجداول", "$_tableCount"),
                  _infoRow(Icons.list_alt_outlined, "إجمالي عدد السجلات", "$_totalRecords"),
                  _infoRow(Icons.folder_outlined, "حجم ملفات التطبيق", _formatBytes(_appFilesSizeBytes)),
                  _infoRow(Icons.sd_storage_outlined, "المساحة المستخدمة إجمالاً", _formatBytes(_dbSizeBytes + _appFilesSizeBytes)),
                ]),
                const SizedBox(height: AppSizes.lg),
                Text("عدد السجلات حسب الجدول", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSizes.sm),
                _buildCard(
                  _tableCounts.map((e) => _infoRow(Icons.table_rows_outlined, e.key, "${e.value}")).toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
