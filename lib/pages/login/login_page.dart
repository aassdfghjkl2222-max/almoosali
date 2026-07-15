import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_text_styles.dart';
import '../../pages/dashboard/pages/hotels_page.dart';
import '../../repositories/user_repository.dart';
import '../../services/session_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final usernameController = TextEditingController();

  final passwordController = TextEditingController();

  final repository = UserRepository();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() async {

    final user = await repository.login(
      usernameController.text.trim(),
      passwordController.text,
    );

    if (user == null) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "اسم المستخدم أو كلمة المرور غير صحيحة",
          ),
        ),
      );

      return;

    }

    SessionService.instance.login(user);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HotelsPage(),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: SafeArea(

        child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.all(24),

            child: ConstrainedBox(

              constraints: const BoxConstraints(
                maxWidth: 420,
              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  const Icon(
                    Icons.apartment_rounded,
                    size: 90,
                    color: AppColors.primary,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    AppConfig.companyNameAr,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headline,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    AppConfig.companyNameEn,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),

                  const SizedBox(height: 40),

                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: "اسم المستخدم",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "كلمة المرور",
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(

                    height: 55,

                    child: ElevatedButton(

                      onPressed: login,

                      child: const Text(
                        "تسجيل الدخول",
                      ),

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

}