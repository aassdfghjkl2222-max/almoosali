import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_colors.dart';
import '../../core/app_permissions.dart';
import '../../core/app_preferences.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/user.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/permission_service.dart';
import '../../services/session_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';

/// إضافة مستخدم جديد أو تعديل مستخدم موجود — بيانات أساسية + وصول الفنادق +
/// صلاحيات دقيقة لكل وحدة، ثم دعوة (نسخ/مشاركة) عند إنشاء مستخدم جديد.
class AddEditUserPage extends StatefulWidget {
  final User? user;

  const AddEditUserPage({super.key, this.user});

  @override
  State<AddEditUserPage> createState() => _AddEditUserPageState();
}

class _AddEditUserPageState extends State<AddEditUserPage> {
  final _repository = UserRepository();
  final _hotelRepository = HotelRepository();

  late final _fullNameController = TextEditingController(text: widget.user?.fullName ?? '');
  late final _usernameController = TextEditingController(text: widget.user?.username ?? '');
  late final _phoneController = TextEditingController(text: widget.user?.phone ?? '');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<Hotel> _hotels = [];
  final Set<int> _selectedHotelIds = {};
  final Set<String> _selectedPermissions = {};
  String _role = 'employee';
  bool _isActive = true;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _usernameError;
  String? _passwordError;

  bool get _isEditMode => widget.user != null;

  @override
  void initState() {
    super.initState();
    _role = widget.user?.role ?? 'employee';
    _isActive = widget.user?.isActive ?? true;
    _loadData();
  }

  Future<void> _loadData() async {
    final hotels = await _hotelRepository.getAllHotels();
    List<int> hotelIds = const [];
    List<Map<String, dynamic>> permissions = const [];
    if (widget.user?.id != null) {
      hotelIds = await _repository.getUserHotelIds(widget.user!.id!);
      permissions = await _repository.getUserPermissions(widget.user!.id!);
    }
    if (!mounted) return;
    setState(() {
      _hotels = hotels;
      _selectedHotelIds.addAll(hotelIds);
      _selectedPermissions.addAll(permissions.map((p) => p['permission_code'] as String));
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<bool> _validate() async {
    setState(() {
      _usernameError = null;
      _passwordError = null;
    });
    if (_fullNameController.text.trim().isEmpty || _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى تعبئة الاسم الكامل واسم المستخدم")));
      return false;
    }
    final username = _usernameController.text.trim();
    final existing = await _repository.getUserByUsername(username);
    if (existing != null && existing.id != widget.user?.id) {
      setState(() => _usernameError = "اسم المستخدم مستخدَم بالفعل");
      return false;
    }
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (!_isEditMode || password.isNotEmpty) {
      if (!_isEditMode && password.isEmpty) {
        setState(() => _passwordError = "كلمة المرور مطلوبة");
        return false;
      }
      if (password.length < 6) {
        setState(() => _passwordError = "يجب أن تتكون كلمة المرور من 6 خانات على الأقل");
        return false;
      }
      if (password != confirm) {
        setState(() => _passwordError = "كلمتا المرور غير متطابقتين");
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    final requiredPermission = _isEditMode ? AppPermissions.usersEdit : AppPermissions.usersCreate;
    if (!PermissionService.instance.hasPermission(requiredPermission)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ليس لديك صلاحية تنفيذ هذا الإجراء"), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (!await _validate()) return;
    if (!mounted) return;

    await AppDialog.confirmAction(
      context: context,
      title: _isEditMode ? "تأكيد تعديل المستخدم" : "تأكيد إضافة المستخدم",
      message: _isEditMode ? "هل تريد حفظ التعديلات على هذا المستخدم؟" : "هل تريد إضافة هذا المستخدم؟",
      onConfirm: () async {
        setState(() => _isSaving = true);
        final actor = SessionService.instance.currentUser;
        final actorName = actor?.fullName ?? "مدير النظام";
        final fullName = _fullNameController.text.trim();
        final username = _usernameController.text.trim();
        final phone = _phoneController.text.trim();
        final password = _passwordController.text;

        try {
          int userId;
          if (_isEditMode) {
            userId = widget.user!.id!;
            final updated = widget.user!.copyWith(
              fullName: fullName,
              username: username,
              phone: phone.isEmpty ? null : phone,
              role: _role,
              isActive: _isActive,
            );
            await _repository.updateUser(updated);
            if (password.isNotEmpty) {
              await _repository.changePassword(userId, password);
            }
            await _repository.logAudit(actorUserId: actor?.id, actorName: actorName, action: 'user_updated', targetUserId: userId, targetName: fullName);
            // المستخدم الحالي عدَّل بيانات نفسه (نادر لكن ممكن لمدير) — حدِّث
            // الصلاحيات المحمَّلة فوراً بلا حاجة لإعادة تسجيل الدخول.
            if (actor?.id == userId) await PermissionService.instance.loadForCurrentUser();
          } else {
            userId = await _repository.createUser(
              username: username,
              fullName: fullName,
              password: password,
              phone: phone.isEmpty ? null : phone,
              role: _role,
            );
            await AppPreferences.setBool(AppPreferences.keyMultiUserLoginEnabled, true);
            await _repository.logAudit(actorUserId: actor?.id, actorName: actorName, action: 'user_created', targetUserId: userId, targetName: fullName);
          }

          await _repository.setUserHotelAccess(userId, _selectedHotelIds.toList());
          // المدير يتجاوز كل الصلاحيات الدقيقة تلقائياً (راجع PermissionService)
          // فلا داعي لتخزين منح فردية له.
          await _repository.setUserPermissions(userId, _role == 'manager' ? [] : _selectedPermissions.map((code) => {'code': code, 'hotelId': null}).toList());

          if (!mounted) return;
          if (!_isEditMode) {
            final token = await _repository.createInvitation(userId);
            await _showInvitationSheet(username: username, password: password, fullName: fullName, token: token);
          }
          if (!mounted) return;
          Navigator.pop(context, true);
        } catch (e) {
          if (!mounted) return;
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("تعذّر الحفظ: $e"), backgroundColor: AppColors.danger),
          );
        }
      },
    );
  }

  Future<void> _showInvitationSheet({
    required String username,
    required String password,
    required String fullName,
    required String token,
  }) async {
    final message =
        "تمت إضافتك على تطبيق منازل.\n"
        "الاسم: $fullName\n"
        "اسم المستخدم: $username\n"
        "كلمة المرور المؤقتة: $password\n\n"
        "افتح التطبيق على هذا الجهاز وسجّل الدخول بهذه البيانات بعد رمز الدخول.";

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.lg,
          right: AppSizes.lg,
          top: AppSizes.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("دعوة المستخدم", style: AppTextStyles.headline),
            const SizedBox(height: AppSizes.xs),
            const Text(
              "شارك بيانات الدخول مع الموظف — كلمة المرور تظهر كنص عادي في الرسالة فقط، لن تُخزَّن ولن تُعرَض مرة أخرى بعد إغلاق هذه النافذة.",
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSizes.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(message, style: AppTextStyles.body),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text("نسخ"),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: message));
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text("تم النسخ")));
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: AppButton(
                    text: "مشاركة",
                    icon: Icons.share_outlined,
                    onPressed: () => Share.share(message),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text("تم")),
          ],
        ),
      ),
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
                        AppTextField(controller: _fullNameController, hint: "الاسم الكامل", icon: Icons.person_outline),
                        const SizedBox(height: AppSizes.md),
                        AppTextField(controller: _usernameController, hint: "اسم المستخدم", icon: Icons.alternate_email, errorText: _usernameError),
                        const SizedBox(height: AppSizes.md),
                        AppTextField(controller: _phoneController, hint: "رقم الجوال (اختياري)", icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: AppSizes.md),
                        AppTextField(
                          controller: _passwordController,
                          hint: _isEditMode ? "كلمة مرور جديدة (اتركها فارغة لعدم التغيير)" : "كلمة المرور",
                          icon: Icons.lock_outline,
                          isPassword: true,
                          errorText: _passwordError,
                        ),
                        const SizedBox(height: AppSizes.md),
                        AppTextField(controller: _confirmPasswordController, hint: "تأكيد كلمة المرور", icon: Icons.lock_outline, isPassword: true),
                        const SizedBox(height: AppSizes.md),
                        Row(
                          children: [
                            Expanded(
                              child: Text("الحالة", style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                            ),
                            Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                            Text(_isActive ? "فعال" : "غير فعال", style: AppTextStyles.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  Text("الدور", style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary, fontSize: 15)),
                  const SizedBox(height: AppSizes.sm),
                  AppCard(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'employee', label: Text('موظف'), icon: Icon(Icons.badge_outlined)),
                        ButtonSegment(value: 'manager', label: Text('مدير'), icon: Icon(Icons.admin_panel_settings_outlined)),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  Text("الفنادق المصرَّح بها", style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary, fontSize: 15)),
                  const SizedBox(height: AppSizes.sm),
                  AppCard(
                    child: _hotels.isEmpty
                        ? const Text("لا توجد فنادق بعد", style: AppTextStyles.caption)
                        : Column(
                            children: _hotels
                                .map((h) => CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text(h.arabicName),
                                      value: _selectedHotelIds.contains(h.id),
                                      onChanged: (checked) => setState(() {
                                        if (checked == true) {
                                          _selectedHotelIds.add(h.id!);
                                        } else {
                                          _selectedHotelIds.remove(h.id);
                                        }
                                      }),
                                    ))
                                .toList(),
                          ),
                  ),
                  if (_role == 'employee') ...[
                    const SizedBox(height: AppSizes.lg),
                    Text("الصلاحيات", style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary, fontSize: 15)),
                    const SizedBox(height: AppSizes.xs),
                    const Text("تُطبَّق هذه الصلاحيات على كل الفنادق المحدَّدة أعلاه لهذا المستخدم", style: AppTextStyles.caption),
                    const SizedBox(height: AppSizes.sm),
                    ..._buildPermissionSections(),
                  ] else ...[
                    const SizedBox(height: AppSizes.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: const Text("المدير يملك كل الصلاحيات تلقائياً في الفنادق المحدَّدة له — لا حاجة لتحديدها يدوياً.", style: TextStyle(fontSize: 12, color: AppColors.info)),
                    ),
                  ],
                  const SizedBox(height: AppSizes.xl),
                  AppButton(
                    text: _isEditMode ? "حفظ التعديلات" : "إضافة المستخدم",
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: AppSizes.lg),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildPermissionSections() {
    return AppPermissions.catalog.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.sm),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
              Wrap(
                spacing: AppSizes.xs,
                children: entry.value.map((perm) {
                  final selected = _selectedPermissions.contains(perm.code);
                  return FilterChip(
                    label: Text(perm.label, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedPermissions.add(perm.code);
                      } else {
                        _selectedPermissions.remove(perm.code);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
