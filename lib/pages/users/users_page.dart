import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/app_text_field.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "المستخدمون",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserHeader(),
            const SizedBox(height: AppSizes.lg),
            Text("تغيير كلمة المرور", style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: AppSizes.md),
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _oldPasswordController,
                    hint: "كلمة المرور الحالية",
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: AppSizes.md),
                  AppTextField(
                    controller: _newPasswordController,
                    hint: "كلمة المرور الجديدة",
                    icon: Icons.lock_reset,
                    isPassword: true,
                  ),
                  const SizedBox(height: AppSizes.md),
                  AppTextField(
                    controller: _confirmPasswordController,
                    hint: "تأكيد كلمة المرور",
                    icon: Icons.lock_reset,
                    isPassword: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            AppButton(
              text: "تحديث كلمة المرور",
              onPressed: _updatePassword,
              icon: Icons.security,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    final identity = Theme.of(context).colorScheme;
    return AppCard(
      color: identity.primary.withOpacity(0.05),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: identity.secondary,
            child: Icon(Icons.person, color: identity.primary, size: 30),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("مدير النظام", style: AppTextStyles.title),
                Text("admin@manazel.com", style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text("نشط", style: TextStyle(color: AppColors.success, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("كلمات المرور غير متطابقة")),
      );
      return;
    }

    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد تحديث كلمة المرور",
      message: "هل تريد تحديث كلمة المرور؟",
      onConfirm: () async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم تحديث كلمة المرور بنجاح (تجريبي)")),
          );
        }
      },
    );
  }
}
