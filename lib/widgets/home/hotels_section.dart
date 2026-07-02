import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'dashboard_section.dart';
import 'hotel_card.dart';
import 'notification_card.dart';

class HotelsSection extends StatelessWidget {
  const HotelsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: "الفنادق",
      icon: Icons.hotel_rounded,
      child: Column(
        children: [
          HotelCard(
            arabicName: "فندق ذاخر بلازا",
            englishName: "Dhakher Plaza Hotel",
            color: AppColors.primary,
            onTap: () {},
          ),

          const NotificationCard(
            title: "٣ مستندات تحتاج إلى تجديد",
            color: Colors.orange,
          ),

          HotelCard(
            arabicName: "فندق جوهرة ذاخر",
            englishName: "Jawharat Dhakher Hotel",
            color: AppColors.info,
            onTap: () {},
          ),

          const NotificationCard(
            title: "انتهى عقد واحد",
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}