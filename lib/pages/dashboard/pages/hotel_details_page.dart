import 'package:flutter/material.dart';

import '../../../models/hotel.dart';
import 'documents_page.dart';

class HotelDetailsPage extends StatelessWidget {
  final Hotel hotel;

  const HotelDetailsPage({
    super.key,
    required this.hotel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(hotel.arabicName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          Text(
            hotel.arabicName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            hotel.englishName,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 30),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [

              menuCard(
                context,
                Icons.description,
                "المستندات",
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DocumentsPage(),
                    ),
                  );
                },
              ),

              menuCard(
                context,
                Icons.account_balance_wallet,
                "المديونية",
                    () {},
              ),

              menuCard(
                context,
                Icons.note_alt,
                "الملاحظات",
                    () {},
              ),

              menuCard(
                context,
                Icons.bar_chart,
                "التقارير",
                    () {},
              ),

              menuCard(
                context,
                Icons.people,
                "الموظفون",
                    () {},
              ),

              menuCard(
                context,
                Icons.settings,
                "الإعدادات",
                    () {},
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget menuCard(
      BuildContext context,
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return Card(
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              icon,
              size: 42,
            ),

            const SizedBox(height: 12),

            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),

          ],
        ),
      ),
    );
  }
}