import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_text_styles.dart';

class CompanyHeader extends StatelessWidget {
  const CompanyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        Text(
          AppConfig.companyNameAr,
          style: AppTextStyles.headline,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          AppConfig.companyNameEn,
          style: AppTextStyles.subtitle,
        ),

      ],
    );
  }
}