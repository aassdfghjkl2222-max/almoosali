import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/permission_group.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';

/// إدارة مجموعات الصلاحيات — إنشاء/تعديل/حذف مجموعة، وتحديد قائمة صلاحيات
/// نصية بسيطة داخلها (تصميم بسيط وسهل الفهم بدل نظام صلاحيات معقّد).
class PermissionGroupsPage extends StatefulWidget {
  const PermissionGroupsPage({super.key});

  @override
  State<PermissionGroupsPage> createState() => _PermissionGroupsPageState();
}

/// أشهر الصلاحيات الشائعة داخل التطبيق — تُعرض كاختيارات سريعة عند إنشاء
/// مجموعة، مع إمكانية إضافة صلاحية نصية حرة أيضاً.
const List<String> _commonPermissions = [
  "عرض التقارير المالية",
  "تعديل التقارير المالية",
  "إدارة الفنادق",
  "إدارة الموظفين",
  "إدارة المستندات",
  "إدارة العقود والفواتير",
  "الوصول إلى الخزنة والتسويات",
  "إدارة المستخدمين والصلاحيات",
  "إدارة النسخ الاحتياطي",
];

class _PermissionGroupsPageState extends State<PermissionGroupsPage> {
  final _repository = UserRepository();
  bool _isLoading = true;
  List<PermissionGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final groups = await _repository.getPermissionGroups();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  Future<void> _openEditor({PermissionGroup? group}) async {
    final nameController = TextEditingController(text: group?.name ?? '');
    final selected = <String>{...(group?.permissions ?? [])};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSizes.md,
                right: AppSizes.md,
                top: AppSizes.md,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSizes.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group == null ? "إنشاء مجموعة صلاحيات" : "تعديل مجموعة الصلاحيات", style: AppTextStyles.title.copyWith(fontSize: 18)),
                  const SizedBox(height: AppSizes.md),
                  AppTextField(controller: nameController, hint: "اسم المجموعة", icon: Icons.badge_outlined),
                  const SizedBox(height: AppSizes.md),
                  const Text("الصلاحيات", style: AppTextStyles.bodyBold),
                  const SizedBox(height: AppSizes.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _commonPermissions.map((perm) {
                      final isSelected = selected.contains(perm);
                      return FilterChip(
                        label: Text(perm, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (value) => setSheetState(() {
                          if (value) {
                            selected.add(perm);
                          } else {
                            selected.remove(perm);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.buttonHeight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text("حفظ"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    if (group == null) {
      await _repository.addPermissionGroup(PermissionGroup(name: name, permissions: selected.toList()));
    } else {
      await _repository.updatePermissionGroup(group.copyWith(name: name, permissions: selected.toList()));
    }
    _load();
  }

  Future<void> _delete(PermissionGroup group) async {
    await AppDialog.confirmAction(
      context: context,
      title: "حذف مجموعة الصلاحيات",
      message: "هل أنت متأكد من حذف مجموعة \"${group.name}\"؟ سيبقى أي مستخدم مرتبط بها بلا مجموعة.",
      isDangerous: true,
      confirmLabel: "حذف",
      onConfirm: () async {
        await _repository.deletePermissionGroup(group.id!);
        if (mounted) _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("مجموعات الصلاحيات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text("مجموعة جديدة"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
                        const SizedBox(height: AppSizes.md),
                        const Text("لا توجد مجموعات صلاحيات بعد", style: AppTextStyles.bodyBold),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.xxl),
                  itemCount: _groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.xs),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(group.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                        subtitle: Text(
                          group.permissions.isEmpty ? "بلا صلاحيات محدَّدة" : "${group.permissions.length} صلاحية: ${group.permissions.join('، ')}",
                          style: AppTextStyles.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _openEditor(group: group);
                            if (value == 'delete') _delete(group);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text("تعديل")),
                            PopupMenuItem(value: 'delete', child: Text("حذف", style: TextStyle(color: AppColors.danger))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
