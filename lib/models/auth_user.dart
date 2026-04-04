class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.balance,
    this.avatarUrl,
    this.role,
    this.roleName,
    this.lastLoginAt,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final int? balance;
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
      balance: _readNullableInt(json['balance']),
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
      'balance': balance,
      'avatar': avatarUrl,
      'role': role,
      'role_name': roleName,
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  AuthUser copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    int? balance,
    String? avatarUrl,
    String? role,
    String? roleName,
    DateTime? lastLoginAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      roleName: roleName ?? this.roleName,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
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

    return 'Tài khoản Edupen';
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

  static int? _readNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
