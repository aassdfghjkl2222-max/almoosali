import 'package:flutter/material.dart';
import '../../../models/hotel.dart';
import '../../settlements/settlements_hub_page.dart';
import '../widgets/module_card.dart';

/// أقسام إضافية للفندق — تضم "التسويات المالية" و"الموردون" بعد إزالتهما من
/// لوحة التحكم الرئيسية (أصبحت 8 بطاقات ثابتة فقط)، بالإضافة لأقسام مستقبلية
/// (صيانة/غرف/مخزون/مشتريات) لا تزال بلا تنفيذ فعلي بعد.
class MoreModulesPage extends StatelessWidget {
  final Hotel hotel;
  const MoreModulesPage({super.key, required this.hotel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("المزيد من الأقسام"),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          ModuleCard(
            title: "التسويات المالية",
            icon: Icons.account_balance_wallet_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettlementsHubPage(hotel: hotel)),
              );
            },
          ),
          ModuleCard(
            title: "الموردون",
            icon: Icons.local_shipping,
            onTap: () {},
          ),
          ModuleCard(
            title: "الصيانة",
            icon: Icons.build,
            onTap: () {},
          ),
          ModuleCard(
            title: "الغرف",
            icon: Icons.bed,
            onTap: () {},
          ),
          ModuleCard(
            title: "المخزون",
            icon: Icons.inventory,
            onTap: () {},
          ),
          ModuleCard(
            title: "المشتريات",
            icon: Icons.shopping_cart,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
