import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_preferences.dart';
import '../core/database/database_service.dart';

/// معلومات نسخة احتياطية واحدة مخزَّنة محلياً على الجهاز.
class BackupInfo {
  final String fileName;
  final String filePath;
  final int sizeBytes;
  final DateTime createdAt;

  const BackupInfo({
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
    required this.createdAt,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes بايت';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} كيلوبايت';
    return '${(kb / 1024).toStringAsFixed(1)} ميجابايت';
  }
}

/// سجل عملية نسخ احتياطي أو استعادة واحدة، لأغراض العرض في "سجل عمليات النسخ".
class BackupLogEntry {
  final String type; // 'backup' | 'restore'
  final String fileName;
  final DateTime timestamp;
  final bool success;
  final String? note;

  const BackupLogEntry({
    required this.type,
    required this.fileName,
    required this.timestamp,
    required this.success,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'file_name': fileName,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        'note': note,
      };

  factory BackupLogEntry.fromMap(Map<String, dynamic> map) => BackupLogEntry(
        type: map['type'] as String? ?? 'backup',
        fileName: map['file_name'] as String? ?? '',
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
        success: map['success'] as bool? ?? true,
        note: map['note'] as String?,
      );
}

/// خدمة النسخ الاحتياطي الحقيقية — تعمل مباشرة على ملف قاعدة البيانات
/// (manazel.db) عبر نسخه إلى/من مجلد نسخ احتياطية داخل مساحة تخزين التطبيق.
///
/// المزامنة السحابية غير مضمَّنة هنا عمداً (هيكلية فقط حالياً) — راجع
/// BackupPage لتفاصيل الإفصاح المعروض للمستخدم حول ذلك.
class BackupService {
  BackupService._();

  static const int maxLogEntries = 100;

  static Future<Directory> _backupsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<bool> _looksLikeSqlite(File file) async {
    try {
      final raf = await file.open();
      final header = await raf.read(16);
      await raf.close();
      return String.fromCharCodes(header.take(15)) == 'SQLite format 3';
    } catch (_) {
      return false;
    }
  }

  /// ينشئ نسخة احتياطية جديدة من قاعدة البيانات الحالية ويعيد معلوماتها.
  static Future<BackupInfo> createBackup() async {
    final dbPath = await DatabaseService().getDatabaseFilePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('تعذّر العثور على ملف قاعدة البيانات');
    }
    final dir = await _backupsDir();
    final now = DateTime.now();
    final fileName = 'manazel_backup_${DateFormat('yyyyMMdd_HHmmss').format(now)}.db';
    final destFile = File('${dir.path}${Platform.pathSeparator}$fileName');
    await dbFile.copy(destFile.path);
    final size = await destFile.length();

    await AppPreferences.setString(AppPreferences.keyLastBackupAt, now.toIso8601String());
    await _appendLog(BackupLogEntry(type: 'backup', fileName: fileName, timestamp: now, success: true));

    return BackupInfo(fileName: fileName, filePath: destFile.path, sizeBytes: size, createdAt: now);
  }

  /// يعيد قائمة النسخ الاحتياطية المحلية المُدارة، مرتّبة من الأحدث للأقدم.
  static Future<List<BackupInfo>> listBackups() async {
    final dir = await _backupsDir();
    final entries = await dir.list().toList();
    final infos = <BackupInfo>[];
    for (final entry in entries) {
      if (entry is! File || !entry.path.endsWith('.db')) continue;
      final stat = await entry.stat();
      infos.add(BackupInfo(
        fileName: entry.path.split(Platform.pathSeparator).last,
        filePath: entry.path,
        sizeBytes: stat.size,
        createdAt: stat.modified,
      ));
    }
    infos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return infos;
  }

  static Future<void> deleteBackup(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  /// يستعيد قاعدة البيانات من ملف نسخة احتياطية. يعيد رسالة خطأ نصية عند
  /// الفشل، أو null عند النجاح. يأخذ نسخة أمان من الحالة الحالية تلقائياً
  /// قبل الاستبدال، ويغلق اتصال قاعدة البيانات المفتوح قبل الكتابة فوق ملفها.
  static Future<String?> restoreBackup(String sourcePath) async {
    final srcFile = File(sourcePath);
    if (!await srcFile.exists()) return 'الملف المحدَّد غير موجود';
    if (!await _looksLikeSqlite(srcFile)) {
      return 'الملف المحدَّد ليس ملف قاعدة بيانات صالحاً';
    }

    try {
      await createBackup();
    } catch (_) {
      // نتابع الاستعادة حتى لو فشلت نسخة الأمان التلقائية.
    }

    try {
      await DatabaseService().closeForRestore();
      final dbPath = await DatabaseService().getDatabaseFilePath();
      await srcFile.copy(dbPath);
      await _appendLog(BackupLogEntry(
        type: 'restore',
        fileName: srcFile.path.split(Platform.pathSeparator).last,
        timestamp: DateTime.now(),
        success: true,
      ));
      return null;
    } catch (e) {
      await _appendLog(BackupLogEntry(
        type: 'restore',
        fileName: srcFile.path.split(Platform.pathSeparator).last,
        timestamp: DateTime.now(),
        success: false,
        note: e.toString(),
      ));
      return 'تعذّرت عملية الاستعادة: $e';
    }
  }

  static Future<List<BackupLogEntry>> getLog() async {
    final raw = await AppPreferences.getString(AppPreferences.keyBackupLog, defaultValue: '[]');
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => BackupLogEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _appendLog(BackupLogEntry entry) async {
    final log = await getLog();
    log.insert(0, entry);
    final trimmed = log.length > maxLogEntries ? log.sublist(0, maxLogEntries) : log;
    await AppPreferences.setString(AppPreferences.keyBackupLog, jsonEncode(trimmed.map((e) => e.toMap()).toList()));
  }

  // ---------------- النسخ التلقائي (جدولة داخل التطبيق) ----------------

  static Duration _intervalFor(String frequency) {
    switch (frequency) {
      case 'daily':
        return const Duration(days: 1);
      case 'monthly':
        return const Duration(days: 30);
      case 'weekly':
      default:
        return const Duration(days: 7);
    }
  }

  /// يُستدعى عند فتح صفحة النسخ الاحتياطي فقط (لا توجد مهمة نظام خلفية
  /// حقيقية) — إن كان النسخ التلقائي مفعّلاً وحان موعده وفق التكرار
  /// المختار، يُنشئ نسخة احتياطية جديدة تلقائياً.
  static Future<bool> maybeRunScheduledBackup() async {
    final enabled = await AppPreferences.getBool(AppPreferences.keyAutoBackupEnabled);
    if (!enabled) return false;
    final frequency = await AppPreferences.getString(AppPreferences.keyAutoBackupFrequency, defaultValue: 'weekly');
    final lastStr = await AppPreferences.getString(AppPreferences.keyLastBackupAt);
    final last = lastStr.isEmpty ? null : DateTime.tryParse(lastStr);
    final due = last == null || DateTime.now().difference(last) >= _intervalFor(frequency);
    if (!due) return false;
    await createBackup();
    return true;
  }
}
