import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_permissions.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/permission_service.dart';
import '../../services/session_service.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/permission_gate.dart';
import 'add_edit_user_page.dart';
import 'permission_groups_page.dart';
import 'user_activity_page.dart';

/// إدارة المستخدمين والصلاحيات — قائمة مقسّمة صفحات (lazy pagination).
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _pageSize = 20;

  final _repository = UserRepository();
  final _hotelRepository = HotelRepository();
  final _scrollController = ScrollController();

  final List<User> _users = [];
  final Map<int, List<int>> _hotelIdsByUser = {};
  Map<int, String> _hotelNamesById = {};
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
    final hotels = await _hotelRepository.getAllHotelsIncludingArchived();
    final total = await _repository.countUsers();
    final users = await _repository.getUsers(limit: _pageSize, offset: 0);
    await _loadHotelAccessFor(users);
    if (!mounted) return;
    setState(() {
      _hotelNamesById = {for (final h in hotels) if (h.id != null) h.id!: h.arabicName};
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
    await _loadHotelAccessFor(next);
    if (!mounted) return;
    setState(() {
      _users.addAll(next);
      _hasMore = _users.length < _totalCount;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadHotelAccessFor(List<User> users) async {
    for (final u in users) {
      if (u.id == null) continue;
      _hotelIdsByUser[u.id!] = await _repository.getUserHotelIds(u.id!);
    }
  }

  String _roleLabel(User user) => user.isManager ? "مدير" : "موظف";

  String _hotelsLabel(User user) {
    final ids = _hotelIdsByUser[user.id] ?? const [];
    if (ids.isEmpty) return "بلا فنادق مصرَّح بها";
    return ids.map((id) => _hotelNamesById[id] ?? "فندق #$id").join('، ');
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
    if (!PermissionService.instance.hasPermission(AppPermissions.usersDisable)) {
      _showDeniedSnackbar();
      return;
    }
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
        final actor = SessionService.instance.currentUser;
        await _repository.logAudit(
          actorUserId: actor?.id,
          actorName: actor?.fullName ?? "مدير النظام",
          action: activating ? 'user_enabled' : 'user_disabled',
          targetUserId: user.id,
          targetName: user.fullName,
        );
        if (mounted) _loadFirstPage();
      },
    );
  }

  void _showDeniedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ليس لديك صلاحية تنفيذ هذا الإجراء"), backgroundColor: AppColors.danger),
    );
  }

  Future<void> _deleteUser(User user) async {
    if (!PermissionService.instance.hasPermission(AppPermissions.usersDisable)) {
      _showDeniedSnackbar();
      return;
    }
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
    final canCreate = PermissionService.instance.hasPermission(AppPermissions.usersCreate);
    return PermissionGate(
      permission: AppPermissions.usersView,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("المستخدمون والصلاحيات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              tooltip: "مجموعات الصلاحيات (قديم)",
              icon: const Icon(Icons.shield_outlined, color: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionGroupsPage())),
            ),
          ],
        ),
        floatingActionButton: !canCreate
            ? null
            : FloatingActionButton.extended(
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
                      separatorBuilder: (context, _) => const SizedBox(height: AppSizes.sm),
                      itemBuilder: (context, index) {
                        if (index == _users.length) {
                          if (_isLoadingMore) return const Padding(padding: EdgeInsets.all(AppSizes.md), child: Center(child: CircularProgressIndicator()));
                          return const SizedBox.shrink();
                        }
                        return _buildUserCard(_users[index]);
                      },
                    ),
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
            Icon(Icons.people_outline, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
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
          backgroundColor: primary.withValues(alpha: 0.1),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName.substring(0, 1) : "?",
            style: TextStyle(color: primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user.fullName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${user.username} · ${_roleLabel(user)}", style: AppTextStyles.caption),
              Text(_hotelsLabel(user), style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isActive ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isActive ? "فعال" : "غير فعال",
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
