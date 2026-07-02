import '../models/user.dart';

class AuthService {

  User? _currentUser;

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  Future<bool> login({
    required User user,
  }) async {

    _currentUser = user;

    return true;
  }

  Future<void> logout() async {

    _currentUser = null;

  }

}