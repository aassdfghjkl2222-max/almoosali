import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import 'dashboard_section.dart';

class StatisticsSection extends StatelessWidget {
  const StatisticsSection({super.key});

  Widget card(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 85,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: "إحصائيات اليوم",
      icon: Icons.bar_chart_rounded,
      child: Row(
        children: [
          card("الفنادق", "2", AppColors.primary),
          card("التنبيهات", "4", AppColors.warning),
          card("الملاحظات", "7", AppColors.info),
        ],
      ),
    );
  }
}