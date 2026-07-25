import 'package:flutter/material.dart';

/// أيقونات المجلدات الجاهزة لمستندات العقود — مفتاح نصي ثابت [key] يُخزَّن في
/// contract_folders.icon_key بدل IconData.codePoint (أكثر ثباتاً عبر تحديثات
/// حزمة الأيقونات). القائمة قابلة للتوسعة بإضافة عناصر جديدة فقط.
class FolderIconOption {
  final String key;
  final String label;
  final IconData icon;
  const FolderIconOption(this.key, this.label, this.icon);
}

class ContractFolderIcons {
  ContractFolderIcons._();

  static const List<FolderIconOption> all = [
    FolderIconOption('folder', 'مجلد', Icons.folder_rounded),
    FolderIconOption('gavel', 'حكومي / قانوني', Icons.gavel_rounded),
    FolderIconOption('description', 'عقد', Icons.description_rounded),
    FolderIconOption('business', 'جهة / شركة', Icons.business_rounded),
    FolderIconOption('apartment', 'فندق / عقار', Icons.apartment_rounded),
    FolderIconOption('account_balance', 'جهة رسمية', Icons.account_balance_rounded),
    FolderIconOption('receipt_long', 'مالي', Icons.receipt_long_rounded),
    FolderIconOption('assignment', 'مستندات', Icons.assignment_rounded),
    FolderIconOption('security', 'أمان / تأمين', Icons.security_rounded),
    FolderIconOption('handshake', 'اتفاقية', Icons.handshake_rounded),
    FolderIconOption('event_note', 'سنوي / موسمي', Icons.event_note_rounded),
    FolderIconOption('verified', 'معتمد', Icons.verified_rounded),
    FolderIconOption('archive', 'أرشيف', Icons.inventory_2_rounded),
  ];

  static const String defaultKey = 'folder';

  static IconData iconFor(String key) {
    for (final o in all) {
      if (o.key == key) return o.icon;
    }
    return Icons.folder_rounded;
  }

  static String labelFor(String key) {
    for (final o in all) {
      if (o.key == key) return o.label;
    }
    return 'مجلد';
  }
}

/// أنواع الملفات المدعومة اليوم — الهيكلة (تصنيف عبر امتداد الملف إلى فئة
/// عرض) تسمح بإضافة أنواع مستقبلية بلا أي تغيير في شكل الاستخدام.
class ContractFileTypes {
  ContractFileTypes._();

  static const String pdf = 'pdf';
  static const String word = 'word';
  static const String excel = 'excel';
  static const String image = 'image';
  static const String other = 'other';

  static String fromExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return pdf;
      case 'doc':
      case 'docx':
        return word;
      case 'xls':
      case 'xlsx':
        return excel;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return image;
      default:
        return other;
    }
  }

  static IconData iconFor(String fileType) {
    switch (fileType) {
      case pdf:
        return Icons.picture_as_pdf_rounded;
      case word:
        return Icons.description_rounded;
      case excel:
        return Icons.grid_on_rounded;
      case image:
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color colorFor(String fileType) {
    switch (fileType) {
      case pdf:
        return const Color(0xFFD32F2F);
      case word:
        return const Color(0xFF1565C0);
      case excel:
        return const Color(0xFF0B7A47);
      case image:
        return const Color(0xFF7B1FA2);
      default:
        return const Color(0xFF616161);
    }
  }

  static String labelFor(String fileType) {
    switch (fileType) {
      case pdf:
        return 'PDF';
      case word:
        return 'Word';
      case excel:
        return 'Excel';
      case image:
        return 'صورة';
      default:
        return 'ملف';
    }
  }
}

/// فئات مستندات مقترحة (نص حر عملياً — هذه للاقتراح السريع فقط، لا تُفرض).
class ContractDocumentCategories {
  ContractDocumentCategories._();

  static const List<String> suggestions = [
    'عقد حكومي',
    'عقد تجاري',
    'ترخيص',
    'تأمين',
    'اتفاقية',
    'مالية',
    'مراسلات',
    'أخرى',
  ];
}

enum ContractDocSortOption { newest, oldest, recentlyModified, alphabetical }

extension ContractDocSortOptionX on ContractDocSortOption {
  String get label {
    switch (this) {
      case ContractDocSortOption.newest:
        return 'الأحدث';
      case ContractDocSortOption.oldest:
        return 'الأقدم';
      case ContractDocSortOption.recentlyModified:
        return 'آخر تعديل';
      case ContractDocSortOption.alphabetical:
        return 'أبجدياً';
    }
  }
}

enum ContractDocViewMode { grid, list }
