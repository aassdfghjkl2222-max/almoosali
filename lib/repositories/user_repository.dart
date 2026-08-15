import 'dart:math';

import '../core/database/database_service.dart';
import '../core/password_hasher.dart';
import '../models/permission_group.dart';
import '../models/user.dart';

class UserRepository {
  final _dbService = DatabaseService();

  Future<List<User>> getUsers({int limit = 50, int offset = 0}) async {
    final data = await _dbService.getUsers(limit: limit, offset: offset);
    return data.map((map) => User.fromMap(map)).toList();
  }

  Future<int> countUsers() async => _dbService.countUsers();

  Future<User?> getUserById(int id) async {
    final map = await _dbService.getUserById(id);
    return map != null ? User.fromMap(map) : null;
  }

  Future<User?> getUserByUsername(String username) async {
    final map = await _dbService.getUserByUsername(username);
    return map != null ? User.fromMap(map) : null;
  }

  /// إنشاء مستخدم جديد بكلمة مرور صريحة تُجزَّأ فوراً هنا — لا يُخزَّن نصها
  /// الصريح في أي مكان (عمود password القديم يبقى فارغاً لهذا المستخدم).
  Future<int> createUser({
    required String username,
    required String fullName,
    required String password,
    String? phone,
    String role = 'employee',
    String? roleId,
    bool isActive = true,
  }) async {
    final hashed = PasswordHasher.hash(password);
    final user = User(
      username: username,
      fullName: fullName,
      phone: phone,
      passwordHash: hashed.hash,
      passwordSalt: hashed.salt,
      role: role,
      roleId: roleId,
      isActive: isActive,
    );
    return await _dbService.insertUser(user.toMap());
  }

  /// تحديث بيانات مستخدم قائم بلا لمس كلمة المرور — مرّر [user] كما هو محمَّل
  /// (أو copyWith عليه) حتى يبقى password_hash/password_salt الحاليان كما هما.
  Future<int> updateUser(User user) async {
    if (user.id == null) return 0;
    return await _dbService.updateById('users', user.toMap(), user.id!);
  }

  Future<int> changePassword(int userId, String newPassword) async {
    final hashed = PasswordHasher.hash(newPassword);
    return await _dbService.updateById('users', {'password_hash': hashed.hash, 'password_salt': hashed.salt}, userId);
  }

  Future<int> setUserActive(int id, bool isActive) async {
    return await _dbService.updateById('users', {'is_active': isActive ? 1 : 0}, id);
  }

  Future<int> deleteUser(int id) async {
    return await _dbService.deleteById('users', id);
  }

  /// تسجيل دخول حقيقي بالتحقق من كلمة المرور المُجزَّأة — لا مقارنة نص صريح
  /// بعد الآن. يفشل بأمان (null) إن كان password_hash/password_salt غير
  /// موجودين (مستخدم لم تُهاجَر كلمة مروره بعد لسبب ما).
  Future<User?> login(String username, String password) async {
    final map = await _dbService.getUserByUsername(username);
    if (map == null) return null;
    final user = User.fromMap(map);
    if (!user.isActive) return null;
    if (user.passwordHash == null || user.passwordSalt == null) return null;
    if (!PasswordHasher.verify(password, user.passwordHash!, user.passwordSalt!)) return null;
    return user;
  }

  // --- وصول الفنادق ---
  Future<List<int>> getUserHotelIds(int userId) => _dbService.getUserHotelIds(userId);
  Future<void> setUserHotelAccess(int userId, List<int> hotelIds) => _dbService.setUserHotelAccess(userId, hotelIds);

  // --- الصلاحيات الدقيقة ---
  /// كل عنصر: {'code': رمز الصلاحية, 'hotelId': int?}.
  Future<List<Map<String, dynamic>>> getUserPermissions(int userId) => _dbService.getUserPermissions(userId);
  Future<void> setUserPermissions(int userId, List<Map<String, dynamic>> permissions) =>
      _dbService.setUserPermissions(userId, permissions);

  // --- الدعوات ---
  /// يولّد رمزاً عشوائياً غير قابل للتخمين (32 بايت، Base64Url) ويسجّله كدعوة
  /// معلَّقة لهذا المستخدم — راجع القرار المعماري #3 في خطة التنفيذ: نفس
  /// الجهاز، بلا خادم لاستبدال الرمز عن بُعد؛ يُستخدَم فقط لتمييز "أول دخول
  /// بانتظار الحدوث" (راجع markInvitationUsed).
  Future<String> createInvitation(int userId) async {
    final token = _generateToken();
    await _dbService.insertInvitation({
      'user_id': userId,
      'token': token,
      'created_at': DateTime.now().toIso8601String(),
      'expires_at': null,
      'used_at': null,
      'revoked_at': null,
    });
    return token;
  }

  Future<Map<String, dynamic>?> getPendingInvitationForUser(int userId) => _dbService.getPendingInvitationForUser(userId);

  Future<void> markInvitationUsedByToken(String token) async {
    final invitation = await _dbService.getInvitationByToken(token);
    if (invitation != null) await _dbService.markInvitationUsed(invitation['id'] as int);
  }

  String _generateToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // --- سجل تدقيق المستخدمين ---
  Future<void> logAudit({
    int? actorUserId,
    required String actorName,
    required String action,
    int? targetUserId,
    String? targetName,
    String? details,
    int? hotelId,
  }) async {
    await _dbService.insertUserAuditLog({
      'actor_user_id': actorUserId,
      'actor_name': actorName,
      'action': action,
      'target_user_id': targetUserId,
      'target_name': targetName,
      'details': details,
      'hotel_id': hotelId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLog({int? targetUserId}) => _dbService.getUserAuditLog(targetUserId: targetUserId);

  // --- مجموعات الصلاحيات (النظام القديم — يبقى للتوافق مع الشاشات الحالية) ---
  Future<List<PermissionGroup>> getPermissionGroups() async {
    final data = await _dbService.getPermissionGroups();
    return data.map((map) => PermissionGroup.fromMap(map)).toList();
  }

  Future<int> addPermissionGroup(PermissionGroup group) async {
    return await _dbService.insertPermissionGroup(group.toMap());
  }

  Future<int> updatePermissionGroup(PermissionGroup group) async {
    if (group.id == null) return 0;
    return await _dbService.updateById('permission_groups', group.toMap(), group.id!);
  }

  Future<int> deletePermissionGroup(int id) async {
    return await _dbService.deleteById('permission_groups', id);
  }
}
