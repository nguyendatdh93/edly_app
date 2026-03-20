class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    this.roleName,
    this.lastLoginAt,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final String? roleName;
  final DateTime? lastLoginAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: _readInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: _readNullableString(json['email']),
      phone: _readNullableString(json['phone']),
      avatarUrl: _readNullableString(json['avatar']),
      role: _readNullableString(json['role']),
      roleName: _readNullableString(json['role_name']),
      lastLoginAt: DateTime.tryParse(
        _readNullableString(json['last_login_at']) ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatarUrl,
      'role': role,
      'role_name': roleName,
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return 'E';
    }

    return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
  }

  String get subtitle {
    final identifier = phone ?? email;
    if (identifier != null && identifier.isNotEmpty) {
      return identifier;
    }

    return 'Tài khoản Edly';
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
