import 'package:flutter/material.dart';
import 'app_colors.dart';

/// مستوى حالة مستند واحد حسب تاريخ انتهائه — المصدر الوحيد لهذا الحساب في
/// التطبيق بالكامل (راجع [DocumentStatus.fromExpiryDate]). [priority] هو
/// أساس ترتيب قائمة مستندات الفندق (الأصغر يظهر أولاً: منتهي ثم عاجل ثم
/// تحذير ثم ساري ثم بلا تاريخ) — وليس ترتيباً أبجدياً.
enum DocumentStatusLevel { expired, urgent, warning, active, noDate }

class DocumentStatusInfo {
  final DocumentStatusLevel level;
  final int? daysRemaining;
  final Color color;
  final String label;
  final IconData icon;
  final int priority;

  const DocumentStatusInfo({
    required this.level,
    required this.daysRemaining,
    required this.color,
    required this.label,
    required this.icon,
    required this.priority,
  });

  bool get needsAttention => level == DocumentStatusLevel.expired || level == DocumentStatusLevel.urgent || level == DocumentStatusLevel.warning;
}

/// حساب موحّد لحالة/لون/أولوية أي مستند من تاريخ انتهائه — يحل محل خمس
/// دوال مستقلة كانت متضاربة العتبات (document_card.dart, alerts_page.dart,
/// hotels_page.dart, documents_analysis_page.dart, analysis_center_page.dart).
/// العتبات: 🟢 ساري، 🟡 خلال 30 يوماً أو أقل، 🔴 خلال 7 أيام أو أقل، 🔴 منتهٍ،
/// ⚪ بلا تاريخ انتهاء (نص فارغ أو غير صالح).
class DocumentStatus {
  DocumentStatus._();

  static const int warningThresholdDays = 30;
  static const int urgentThresholdDays = 7;

  static DocumentStatusInfo fromExpiryDate(String? expiryDate) {
    final expiry = expiryDate == null || expiryDate.trim().isEmpty ? null : DateTime.tryParse(expiryDate);
    if (expiry == null) {
      return const DocumentStatusInfo(
        level: DocumentStatusLevel.noDate,
        daysRemaining: null,
        color: Colors.grey,
        label: "لا يحتاج إلى تجديد",
        icon: Icons.remove_circle_outline,
        priority: 4,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(expiry.year, expiry.month, expiry.day).difference(today).inDays;

    if (days < 0) {
      return DocumentStatusInfo(
        level: DocumentStatusLevel.expired,
        daysRemaining: days,
        color: AppColors.danger,
        label: "منتهٍ منذ ${days.abs()} يوم",
        icon: Icons.error_outline,
        priority: 0,
      );
    }
    if (days <= urgentThresholdDays) {
      return DocumentStatusInfo(
        level: DocumentStatusLevel.urgent,
        daysRemaining: days,
        color: AppColors.danger,
        label: "ينتهي خلال $days يوم",
        icon: Icons.warning_amber_rounded,
        priority: 1,
      );
    }
    if (days <= warningThresholdDays) {
      return DocumentStatusInfo(
        level: DocumentStatusLevel.warning,
        daysRemaining: days,
        color: AppColors.warning,
        label: "ينتهي خلال $days يوم",
        icon: Icons.access_time_rounded,
        priority: 2,
      );
    }
    return DocumentStatusInfo(
      level: DocumentStatusLevel.active,
      daysRemaining: days,
      color: AppColors.success,
      label: "ساري (متبقي $days يوم)",
      icon: Icons.check_circle_outline,
      priority: 3,
    );
  }
}
