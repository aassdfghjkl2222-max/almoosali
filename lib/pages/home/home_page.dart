import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/responsive.dart';
import '../../widgets/home/company_header.dart';
import '../../widgets/home/hotels_section.dart';
import '../../widgets/home/quick_actions_section.dart';
import '../../widgets/home/statistics_section.dart';
import '../../widgets/home/version_footer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.menu_rounded,
              color: AppColors.primary,
              size: responsive.wp(8),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.wp(5),
            ),
            child: Column(
              children: [
                SizedBox(height: responsive.hp(2)),

                const CompanyHeader(),

                SizedBox(height: responsive.hp(3)),

                const HotelsSection(),

                SizedBox(height: responsive.hp(2)),

                const QuickActionsSection(),

                SizedBox(height: responsive.hp(2)),

                StatisticsSection(),

                const VersionFooter(),

                SizedBox(height: responsive.hp(2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}