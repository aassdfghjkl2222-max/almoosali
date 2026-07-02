import '../models/user.dart';

class SessionService {

  static final SessionService instance = SessionService._();

  SessionService._();

  User? _currentUser;

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  void login(User user) {
    _currentUser = user;
  }

  void logout() {
    _currentUser = null;
  }

}