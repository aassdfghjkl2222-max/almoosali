class User {

  final String id;

  final String username;

  final String fullName;

  final String password;

  final String roleId;

  final bool isActive;

  const User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.password,
    required this.roleId,
    required this.isActive,
  });

}