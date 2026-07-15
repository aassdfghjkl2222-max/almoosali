import '../core/database/database_service.dart';
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

  Future<int> addUser(User user) async {
    return await _dbService.insertUser(user.toMap());
  }

  Future<int> updateUser(User user) async {
    if (user.id == null) return 0;
    return await _dbService.updateById('users', user.toMap(), user.id!);
  }

  Future<int> setUserActive(int id, bool isActive) async {
    return await _dbService.updateById('users', {'is_active': isActive ? 1 : 0}, id);
  }

  Future<int> deleteUser(int id) async {
    return await _dbService.deleteById('users', id);
  }

  Future<User?> login(String username, String password) async {
    final users = await getUsers(limit: 1000);
    try {
      return users.firstWhere((u) => u.username == username && u.password == password && u.isActive);
    } catch (_) {
      return null;
    }
  }

  // --- مجموعات الصلاحيات ---
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
