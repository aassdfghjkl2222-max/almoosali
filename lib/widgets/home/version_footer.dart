import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/app_text_styles.dart';

class VersionFooter extends StatelessWidget {
  const VersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 25),
      child: Text(
        "Version ${AppConfig.version}",
        style: AppTextStyles.caption,
      ),
    );
  }
}