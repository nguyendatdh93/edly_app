import 'package:edly/models/auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final AuthUser user;

  factory AuthSession.fromApiJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? '').toString().trim();
    final userData = json['user'];

    if (token.isEmpty || userData is! Map) {
      throw const FormatException('Invalid auth payload');
    }

    return AuthSession(
      token: token,
      user: AuthUser.fromJson(Map<String, dynamic>.from(userData)),
    );
  }

  factory AuthSession.fromStorageJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? '').toString().trim();
    final userData = json['user'];

    if (token.isEmpty || userData is! Map) {
      throw const FormatException('Invalid stored session');
    }

    return AuthSession(
      token: token,
      user: AuthUser.fromJson(Map<String, dynamic>.from(userData)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
    };
  }

  AuthSession copyWith({
    String? token,
    AuthUser? user,
  }) {
    return AuthSession(
      token: token ?? this.token,
      user: user ?? this.user,
    );
  }
}
