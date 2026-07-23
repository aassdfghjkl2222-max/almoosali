import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_text_styles.dart';

/// بطاقة قسم أفقية بعرض الشاشة تقريباً — تحل محل بطاقات الشبكة القديمة
/// (عنصرين في الصف). أيقونة كبيرة داخل حاوية دائرية بلون مميّز للقسم، اسم
/// القسم فقط (بلا وصف فرعي — تصميم مبسَّط ومختصر)، شارة عددية اختيارية،
/// وسهم دخول — كلها بظل خفيف جداً وحواف دائرية كبيرة (راجع AppRadius.lg)
/// لمظهر حديث وفاخر. يُعاد استخدامها في لوحة تحكم الفندق وشاشة العمليات
/// المالية المعلقة لضمان تطابق الشكل بينهما.
class DashboardSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final int badgeCount;
  final VoidCallback onTap;

  const DashboardSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: radius,
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
