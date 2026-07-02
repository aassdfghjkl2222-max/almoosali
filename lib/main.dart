import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'pages/login/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ManazelApp());
}

class ManazelApp extends StatelessWidget {
  const ManazelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Manazel',
      theme: AppTheme.light,
      home: const LoginPage(),
    );
  }
}