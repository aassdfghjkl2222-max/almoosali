import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'dashboard_section.dart';
import 'menu_card.dart';

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: "الوصول السريع",
      icon: Icons.grid_view_rounded,
      child: Row(
        children: [
          MenuCard(
            title: "التنبيهات",
            icon: Icons.notifications_active_outlined,
            color: AppColors.warning,
            onTap: () {},
          ),

          const SizedBox(width: 12),

          MenuCard(
            title: "المديونية",
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.success,
            onTap: () {},
          ),

          const SizedBox(width: 12),

          MenuCard(
            title: "الملاحظات",
            icon: Icons.edit_note_rounded,
            color: AppColors.info,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}