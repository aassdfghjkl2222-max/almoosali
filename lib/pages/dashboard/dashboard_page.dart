import 'package:flutter/material.dart';

import '../home/home_page.dart';
import 'pages/hotels_page.dart';
import 'pages/documents_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;

  final List<String> titles = const [
    "الرئيسية",
    "الفنادق",
    "المستندات",
    "المديونية",
    "الملاحظات",
    "التقارير",
    "المستخدمون",
    "الإعدادات",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "مدير النظام",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    "admin",
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            _drawerItem(0, Icons.home, "الرئيسية"),
            _drawerItem(1, Icons.hotel, "الفنادق"),
            _drawerItem(2, Icons.description, "المستندات"),
            _drawerItem(3, Icons.account_balance_wallet, "المديونية"),
            _drawerItem(4, Icons.note_alt, "الملاحظات"),
            _drawerItem(5, Icons.bar_chart, "التقارير"),
            _drawerItem(6, Icons.people, "المستخدمون"),
            _drawerItem(7, Icons.settings, "الإعدادات"),
          ],
        ),
      ),
      body: _buildPage(),
    );
  }

  Widget _drawerItem(
      int index,
      IconData icon,
      String title,
      ) {
    return ListTile(
      selected: selectedIndex == index,
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);

        setState(() {
          selectedIndex = index;
        });
      },
    );
  }

  Widget _buildPage() {
    switch (selectedIndex) {
      case 0:
        return const HomePage();

      case 1:
        return const HotelsPage();

      case 2:
        return const DocumentsPage();

      case 3:
        return const Center(
          child: Text("المديونية"),
        );

      case 4:
        return const Center(
          child: Text("الملاحظات"),
        );

      case 5:
        return const Center(
          child: Text("التقارير"),
        );

      case 6:
        return const Center(
          child: Text("المستخدمون"),
        );

      case 7:
        return const Center(
          child: Text("الإعدادات"),
        );

      default:
        return const HomePage();
    }
  }
}