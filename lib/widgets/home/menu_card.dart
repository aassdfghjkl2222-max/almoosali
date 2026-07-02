import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_text_styles.dart';

class MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          height: 95,
          decoration: BoxDecoration(
            color: color.withOpacity(.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
                color: color,
              ),

              const SizedBox(height: 8),

              FittedBox(
                child: Text(
                  title,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}