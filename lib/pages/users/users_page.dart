import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/common/app_dialog.dart';
import 'add_edit_user_page.dart';
import 'permission_groups_page.dart';
import 'user_activity_page.dart';

/// إدارة المستخدمين — قائمة مقسّمة صفحات (lazy pagination) لا تُحمِّل كل
/// المستخدمين دفعة واحدة. تُفتَح فقط عند تفعيل نظام مستخدمين متعدد فعلياً
/// (راجع kAppHasMultipleUsers في app_drawer.dart).
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _pageSize = 20;

  final _repository = UserRepository();
  final _scrollController = ScrollController();

  final List<User> _users = [];
  Map<int, String> _groupNamesById = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() => _isLoading = true);
    final groups = await _repository.getPermissionGroups();
    final total = await _repository.countUsers();
    final users = await _repository.getUsers(limit: _pageSize, offset: 0);
    if (!mounted) return;
    setState(() {
      _groupNamesById = {for (final g in groups) if (g.id != null) g.id!: g.name};
      _totalCount = total;
      _users
        ..clear()
        ..addAll(users);
      _hasMore = _users.length < _totalCount;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final next = await _repository.getUsers(limit: _pageSize, offset: _users.length);
    if (!mounted) return;
    setState(() {
      _users.addAll(next);
      _hasMore = _users.length < _totalCount;
      _isLoadingMore = false;
    });
  }

  String _roleLabel(String? roleId) {
    if (roleId == null || roleId.isEmpty) return "بلا مجموعة صلاحيات";
    final asInt = int.tryParse(roleId);
    if (asInt != null && _groupNamesById.containsKey(asInt)) return _groupNamesById[asInt]!;
    switch (roleId) {
      case 'admin':
        return "مدير النظام";
      case 'manager':
        return "مدير";
      case 'employee':
        return "موظف";
      default:
        return roleId;
    }
  }

  Future<void> _openAddUser() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddEditUserPage()));
    if (result == true) _loadFirstPage();
  }

  Future<void> _openEditUser(User user) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AddEditUserPage(user: user)));
    if (result == true) _loadFirstPage();
  }

  Future<void> _toggleActive(User user) async {
    final activating = !user.isActive;
    await AppDialog.confirmAction(
      context: context,
      title: activating ? "تفعيل المستخدم" : "تعليق المستخدم",
      message: activating
          ? "هل تريد إعادة تفعيل \"${user.fullName}\"؟"
          : "سيتم منع \"${user.fullName}\" من تسجيل الدخول حتى يُعاد تفعيله. متابعة؟",
      isDangerous: !activating,
      onConfirm: () async {
        await _repository.setUserActive(user.id!, activating);
        if (mounted) _loadFirstPage();
      },
    );
  }

  Future<void> _deleteUser(User user) async {
    await AppDialog.confirmAction(
      context: context,
      title: "حذف المستخدم",
      message: "هل أنت متأكد من حذف \"${user.fullName}\" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.",
      isDangerous: true,
      confirmLabel: "حذف",
      onConfirm: () async {
        await _repository.deleteUser(user.id!);
        if (mounted) _loadFirstPage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إدارة المستخدمين والصلاحيات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: "مجموعات الصلاحيات",
            icon: const Icon(Icons.shield_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionGroupsPage())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddUser,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text("إضافة مستخدم"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadFirstPage,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.xxl),
                    itemCount: _users.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
                    itemBuilder: (context, index) {
                      if (index == _users.length) {
                        if (_isLoadingMore) return const Padding(padding: EdgeInsets.all(AppSizes.md), child: Center(child: CircularProgressIndicator()));
                        return const SizedBox.shrink();
                      }
                      return _buildUserCard(_users[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.md),
            const Text("لا يوجد مستخدمون بعد", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.xs),
            const Text("اضغط \"إضافة مستخدم\" لإنشاء أول حساب", style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final primary = Theme.of(context).colorScheme.primary;
    final isActive = user.isActive;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.xs),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserActivityPage(user: user))),
        leading: CircleAvatar(
          backgroundColor: primary.withOpacity(0.1),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName.substring(0, 1) : "?",
            style: TextStyle(color: primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user.fullName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
        subtitle: Text("${user.username} · ${_roleLabel(user.roleId)}", style: AppTextStyles.caption),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isActive ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isActive ? "نشط" : "معلَّق",
                style: TextStyle(color: isActive ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _openEditUser(user);
                if (value == 'toggle') _toggleActive(user);
                if (value == 'delete') _deleteUser(user);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text("تعديل")),
                PopupMenuItem(value: 'toggle', child: Text(isActive ? "تعليق" : "تفعيل")),
                const PopupMenuItem(value: 'delete', child: Text("حذف", style: TextStyle(color: AppColors.danger))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
