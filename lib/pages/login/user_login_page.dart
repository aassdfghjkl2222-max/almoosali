import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../repositories/user_repository.dart';
import '../../services/permission_service.dart';
import '../../services/session_service.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/app_button.dart';
import '../dashboard/pages/hotels_page.dart';

/// دخول المستخدم (اسم مستخدم/كلمة مرور) — يظهر فقط بعد نجاح PIN الجهاز وفقط
/// إن فعَّل المدير AppPreferences.keyMultiUserLoginEnabled (راجع PinLoginPage).
/// منفصل تماماً عن PIN: PIN يثبت أن هذا جهاز موثوق، وهذه الشاشة تحدد أي
/// موظف يستخدمه الآن وبأي صلاحيات (راجع PermissionService).
class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final _repository = UserRepository();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorText = "يرجى إدخال اسم المستخدم وكلمة المرور");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final user = await _repository.login(username, password);
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorText = "اسم المستخدم أو كلمة المرور غير صحيحة، أو الحساب معطَّل";
      });
      return;
    }

    SessionService.instance.login(user);
    await PermissionService.instance.loadForCurrentUser();
    // نجاح الدخول = "تفعيل" الحساب فعلياً — لا حاجة لأي رمز يُستبدَل عبر
    // خادم (راجع القرار المعماري #3 في خطة التنفيذ).
    if (user.id != null) {
      final pending = await _repository.getPendingInvitationForUser(user.id!);
      if (pending != null) {
        await _repository.markInvitationUsedByToken(pending['token'] as String);
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HotelsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline_rounded, size: 72, color: AppColors.primary),
                const SizedBox(height: AppSizes.md),
                const Text("تسجيل دخول المستخدم", style: AppTextStyles.headline),
                const SizedBox(height: AppSizes.xs),
                const Text(
                  "أدخل بيانات حسابك لعرض ما يخصك من صلاحيات",
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.xl),
                AppTextField(controller: _usernameController, hint: "اسم المستخدم", icon: Icons.person_outline),
                const SizedBox(height: AppSizes.sm),
                AppTextField(
                  controller: _passwordController,
                  hint: "كلمة المرور",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  errorText: _errorText,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: AppSizes.lg),
                AppButton(text: "دخول", onPressed: _isLoading ? null : _login, isLoading: _isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
