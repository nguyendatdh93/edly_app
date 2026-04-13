class AdminDashboardData {
  const AdminDashboardData({
    required this.summary,
    required this.recentUsers,
    required this.quickActions,
    required this.generatedAt,
  });

  final AdminDashboardSummary summary;
  final List<AdminRecentUser> recentUsers;
  final List<AdminQuickAction> quickActions;
  final DateTime? generatedAt;

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final summaryMap = _asMap(json['summary']);
    final metaMap = _asMap(json['meta']);

    return AdminDashboardData(
      summary: AdminDashboardSummary.fromJson(summaryMap),
      recentUsers: _asList(
        json['recent_users'],
      ).map((item) => AdminRecentUser.fromJson(item)).toList(),
      quickActions: _asList(
        json['quick_actions'],
      ).map((item) => AdminQuickAction.fromJson(item)).toList(),
      generatedAt: DateTime.tryParse(_readString(metaMap['generated_at'])),
    );
  }
}

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.usersTotal,
    required this.usersNewToday,
    required this.activeToday,
    required this.adminsTotal,
    required this.staffTotal,
    required this.teachersTotal,
    required this.studentsTotal,
    required this.coursesPublished,
    required this.coursesDraft,
    required this.transactionsCompletedToday,
    required this.revenueCompletedToday,
  });

  final int usersTotal;
  final int usersNewToday;
  final int activeToday;
  final int adminsTotal;
  final int staffTotal;
  final int teachersTotal;
  final int studentsTotal;
  final int coursesPublished;
  final int coursesDraft;
  final int transactionsCompletedToday;
  final int revenueCompletedToday;

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    return AdminDashboardSummary(
      usersTotal: _readInt(json['users_total']),
      usersNewToday: _readInt(json['users_new_today']),
      activeToday: _readInt(json['active_today']),
      adminsTotal: _readInt(json['admins_total']),
      staffTotal: _readInt(json['staff_total']),
      teachersTotal: _readInt(json['teachers_total']),
      studentsTotal: _readInt(json['students_total']),
      coursesPublished: _readInt(json['courses_published']),
      coursesDraft: _readInt(json['courses_draft']),
      transactionsCompletedToday: _readInt(
        json['transactions_completed_today'],
      ),
      revenueCompletedToday: _readInt(json['revenue_completed_today']),
    );
  }
}

class AdminRecentUser {
  const AdminRecentUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.role,
    this.roleName,
    this.createdAt,
    this.lastLoginAt,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? role;
  final String? roleName;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  factory AdminRecentUser.fromJson(Map<String, dynamic> json) {
    return AdminRecentUser(
      id: _readInt(json['id']),
      name: _readString(json['name']),
      email: _readNullableString(json['email']),
      phone: _readNullableString(json['phone']),
      role: _readNullableString(json['role']),
      roleName: _readNullableString(json['role_name']),
      createdAt: DateTime.tryParse(_readString(json['created_at'])),
      lastLoginAt: DateTime.tryParse(_readString(json['last_login_at'])),
    );
  }
}

class AdminQuickAction {
  const AdminQuickAction({
    required this.key,
    required this.title,
    required this.description,
    required this.enabled,
  });

  final String key;
  final String title;
  final String description;
  final bool enabled;

  factory AdminQuickAction.fromJson(Map<String, dynamic> json) {
    return AdminQuickAction(
      key: _readString(json['key']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      enabled: _readBool(json['enabled']),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value.whereType<Map>().map((item) => _asMap(item)).toList();
}

String _readString(dynamic value) {
  return (value ?? '').toString().trim();
}

String? _readNullableString(dynamic value) {
  final text = _readString(value);
  return text.isEmpty ? null : text;
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
  return false;
}
