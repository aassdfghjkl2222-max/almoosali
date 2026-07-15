import 'package:flutter/material.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_drawer.dart';
import 'pages/inter_entity_debts_page.dart';
import 'pages/person_debts_page.dart';
import 'pages/supplier_debts_page.dart';

import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../widgets/common/hotel_identity_title.dart';

class SettlementsHubPage extends StatelessWidget {
  final Hotel hotel;
  const SettlementsHubPage({super.key, required this.hotel});

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "التسويات المالية", hotel: hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: AppDrawer(hotel: hotel),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          _buildHubItem(
            context: context,
            title: "الديون بين المنشآت",
            subtitle: "إدارة المديونيات بين الفنادق والمنشآت",
            icon: Icons.business_rounded,
            color: identityColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InterEntityDebtsPage(hotel: hotel)),
              );
            },
          ),
          const SizedBox(height: AppSizes.md),
          _buildHubItem(
            context: context,
            title: "ديون الأشخاص",
            subtitle: "متابعة الحسابات والديون الشخصية",
            icon: Icons.person_outline_rounded,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PersonDebtsPage(hotel: hotel)),
              );
            },
          ),
          const SizedBox(height: AppSizes.md),
          _buildHubItem(
            context: context,
            title: "ديون الموردين",
            subtitle: "إدارة مستحقات ومديونيات الموردين",
            icon: Icons.local_shipping_outlined,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SupplierDebtsPage(hotel: hotel)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHubItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.md),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.title.copyWith(fontSize: 18),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 16,
          ),
        ],
      ),
    );
  }
}
