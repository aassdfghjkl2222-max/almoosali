import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';

class DashboardSection extends StatelessWidget {

  final String title;

  final IconData icon;

  final Widget child;

  const DashboardSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(top: 24),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(
                icon,
                color: AppColors.primary,
              ),

              const SizedBox(width: 8),

              Text(
                title,
                style: AppTextStyles.title,
              ),

            ],
          ),

          const SizedBox(height: 16),

          child,

        ],
      ),
    );
  }
}