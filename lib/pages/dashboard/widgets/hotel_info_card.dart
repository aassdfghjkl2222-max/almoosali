import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';

/// بطاقة معلومات سريعة أسفل رأس لوحة التحكم مباشرة — اسم الفندق ثم صف
/// إحصائيات (التنبيهات، المستندات القريبة من الانتهاء/المنتهية، تاريخ آخر
/// تحديث). كل قيمة تُمرَّر من الخارج كـ Nullable/قيمة جاهزة بدل استعلام
/// داخلي، حتى يسهل ربط أي مصدر بيانات جديد لاحقاً (مثلاً نظام تنبيهات موحّد)
/// بتمرير رقم حقيقي بدل placeholder فقط، دون أي تعديل على تصميم هذه البطاقة.
class HotelInfoCard extends StatelessWidget {
  final Hotel hotel;
  final Color accentColor;
  final int alertsCount;
  final int expiringDocumentsCount;
  final DateTime? lastUpdate;

  const HotelInfoCard({
    super.key,
    required this.hotel,
    required this.accentColor,
    required this.alertsCount,
    required this.expiringDocumentsCount,
    required this.lastUpdate,
  });

  String get _lastUpdateLabel {
    if (lastUpdate == null) return "—";
    final now = DateTime.now();
    final diff = now.difference(lastUpdate!);
    if (diff.inDays == 0) return "اليوم";
    if (diff.inDays == 1) return "أمس";
    return DateFormat('yyyy-MM-dd').format(lastUpdate!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(Icons.apartment_rounded, color: accentColor, size: 22),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  hotel.arabicName,
                  style: AppTextStyles.title.copyWith(fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(child: _Stat(icon: Icons.notifications_outlined, value: '$alertsCount', label: "التنبيهات", color: accentColor)),
              const _StatDivider(),
              Expanded(
                child: _Stat(
                  icon: Icons.event_busy_outlined,
                  value: '$expiringDocumentsCount',
                  label: "مستندات تحتاج متابعة",
                  color: expiringDocumentsCount > 0 ? AppColors.warning : accentColor,
                ),
              ),
              const _StatDivider(),
              Expanded(child: _Stat(icon: Icons.update_outlined, value: _lastUpdateLabel, label: "آخر تحديث", color: accentColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: Theme.of(context).dividerColor);
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
