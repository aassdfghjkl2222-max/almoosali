import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/permission_group.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';

/// إضافة مستخدم جديد أو تعديل مستخدم موجود — نفس الصفحة لكلا الحالتين
/// (وضع التعديل عند تمرير [user]).
class AddEditUserPage extends StatefulWidget {
  final User? user;

  const AddEditUserPage({super.key, this.user});

  @override
  State<AddEditUserPage> createState() => _AddEditUserPageState();
}

class _AddEditUserPageState extends State<AddEditUserPage> {
  final _repository = UserRepository();

  late final _usernameController = TextEditingController(text: widget.user?.username ?? '');
  late final _fullNameController = TextEditingController(text: widget.user?.fullName ?? '');
  final _passwordController = TextEditingController();

  List<PermissionGroup> _groups = [];
  int? _selectedGroupId;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditMode => widget.user != null;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await _repository.getPermissionGroups();
    if (!mounted) return;
    final currentRoleId = int.tryParse(widget.user?.roleId ?? '');
    setState(() {
      _groups = groups;
      _selectedGroupId = currentRoleId != null && groups.any((g) => g.id == currentRoleId) ? currentRoleId : null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppDialog.confirmAction(
      context: context,
      title: _isEditMode ? "تأكيد تعديل المستخدم" : "تأكيد إضافة المستخدم",
      message: _isEditMode ? "هل تريد حفظ التعديلات على هذا المستخدم؟" : "هل تريد إضافة هذا المستخدم؟",
      onConfirm: () async {
        setState(() => _isSaving = true);
        try {
          final password = _passwordController.text.trim();
          if (_isEditMode) {
            final updated = widget.user!.copyWith(
              username: _usernameController.text.trim(),
              fullName: _fullNameController.text.trim(),
              password: password.isEmpty ? widget.user!.password : password,
              roleId: _selectedGroupId?.toString(),
            );
            await _repository.updateUser(updated);
          } else {
            final newUser = User(
              username: _usernameController.text.trim(),
              fullName: _fullNameController.text.trim(),
              password: password,
              roleId: _selectedGroupId?.toString(),
            );
            await _repository.addUser(newUser);
          }
          if (!mounted) return;
          Navigator.pop(context, true);
        } catch (e) {
          if (!mounted) return;
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("تعذّر الحفظ: اسم المستخدم مستخدَم مسبقاً أو حدث خطأ ($e)"), backgroundColor: AppColors.danger),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? "تعديل مستخدم" : "إضافة مستخدم", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _fullNameController,
                          hint: "الاسم الكامل",
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: AppSizes.md),
                        AppTextField(
                          controller: _usernameController,
                          hint: "اسم المستخدم",
                          icon: Icons.alternate_email,
                        ),
                        const SizedBox(height: AppSizes.md),
                        AppTextField(
                          controller: _passwordController,
                          hint: _isEditMode ? "كلمة مرور جديدة (اتركها فارغة لعدم التغيير)" : "كلمة المرور",
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  Text("مجموعة الصلاحيات", style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary, fontSize: 15)),
                  const SizedBox(height: AppSizes.sm),
                  AppCard(
                    child: _groups.isEmpty
                        ? const Text("لا توجد مجموعات صلاحيات بعد — يمكن إنشاؤها من صفحة \"مجموعات الصلاحيات\"", style: AppTextStyles.caption)
                        : DropdownButtonFormField<int?>(
                            initialValue: _selectedGroupId,
                            decoration: const InputDecoration(border: InputBorder.none),
                            hint: const Text("بلا مجموعة"),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text("بلا مجموعة")),
                              ..._groups.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name))),
                            ],
                            onChanged: (value) => setState(() => _selectedGroupId = value),
                          ),
                  ),
                  const SizedBox(height: AppSizes.xl),
                  AppButton(
                    text: _isEditMode ? "حفظ التعديلات" : "إضافة المستخدم",
                    onPressed: _validateRequired,
                    isLoading: _isSaving,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: AppSizes.lg),
                ],
              ),
            ),
    );
  }

  void _validateRequired() {
    if (_fullNameController.text.trim().isEmpty || _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى تعبئة الاسم الكامل واسم المستخدم")),
      );
      return;
    }
    if (!_isEditMode && _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال كلمة مرور للمستخدم الجديد")),
      );
      return;
    }
    _save();
  }
}
