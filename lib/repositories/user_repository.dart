import '../models/user.dart';

class UserRepository {

  final List<User> users = [

    const User(
      id: '1',
      username: 'admin',
      fullName: 'مدير النظام',
      password: '123456',
      roleId: 'admin',
      isActive: true,
    ),

    const User(
      id: '2',
      username: 'manager',
      fullName: 'مدير الفندق',
      password: '123456',
      roleId: 'manager',
      isActive: true,
    ),

    const User(
      id: '3',
      username: 'employee',
      fullName: 'موظف',
      password: '123456',
      roleId: 'employee',
      isActive: true,
    ),

  ];

  User? login(
      String username,
      String password,
      ) {

    try {

      return users.firstWhere(

            (user) =>
        user.username == username &&
            user.password == password &&
            user.isActive,

      );

    } catch (_) {

      return null;

    }

  }

}