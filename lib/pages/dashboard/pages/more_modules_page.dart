import 'package:flutter/material.dart';
import '../widgets/module_card.dart';

class MoreModulesPage extends StatelessWidget {
  const MoreModulesPage({super.key});

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
