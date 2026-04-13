class AdminPaginationMeta {
  const AdminPaginationMeta({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.filters,
  });

  final int page;
  final int perPage;
  final int total;
  final int lastPage;
  final Map<String, dynamic> filters;

  factory AdminPaginationMeta.fromJson(Map<String, dynamic> json) {
    final page = _readInt(json['page']);
    final perPage = _readInt(json['per_page']);
    final total = _readInt(json['total']);
    final lastPage = _readInt(json['last_page']);

    return AdminPaginationMeta(
      page: page <= 0 ? 1 : page,
      perPage: perPage <= 0 ? 20 : perPage,
      total: total < 0 ? 0 : total,
      lastPage: lastPage <= 0 ? 1 : lastPage,
      filters: _asMap(json['filters']),
    );
  }
}

class AdminUsersData {
  const AdminUsersData({required this.items, required this.meta});

  final List<AdminUserListItem> items;
  final AdminPaginationMeta meta;

  factory AdminUsersData.fromJson(Map<String, dynamic> json) {
    return AdminUsersData(
      items: _asList(
        json['data'],
      ).map((item) => AdminUserListItem.fromJson(item)).toList(),
      meta: AdminPaginationMeta.fromJson(_asMap(json['meta'])),
    );
  }
}

class AdminUserListItem {
  const AdminUserListItem({
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

  factory AdminUserListItem.fromJson(Map<String, dynamic> json) {
    return AdminUserListItem(
      id: _readInt(json['id']),
      name: _readString(json['name']),
      email: _readNullableString(json['email']),
      phone: _readNullableString(json['phone']),
      role: _readNullableString(json['role']),
      roleName: _readNullableString(json['role_name']),
      createdAt: _readDateTime(json['created_at']),
      lastLoginAt: _readDateTime(json['last_login_at']),
    );
  }
}

class AdminCoursesData {
  const AdminCoursesData({required this.items, required this.meta});

  final List<AdminCourseListItem> items;
  final AdminPaginationMeta meta;

  factory AdminCoursesData.fromJson(Map<String, dynamic> json) {
    return AdminCoursesData(
      items: _asList(
        json['data'],
      ).map((item) => AdminCourseListItem.fromJson(item)).toList(),
      meta: AdminPaginationMeta.fromJson(_asMap(json['meta'])),
    );
  }
}

class AdminCourseListItem {
  const AdminCourseListItem({
    required this.id,
    required this.publicId,
    required this.slug,
    required this.title,
    required this.status,
    required this.originalPrice,
    required this.discountPrice,
    required this.collectionsCount,
    this.thumbnail,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String publicId;
  final String slug;
  final String title;
  final String status;
  final int originalPrice;
  final int discountPrice;
  final int collectionsCount;
  final String? thumbnail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminCourseListItem.fromJson(Map<String, dynamic> json) {
    return AdminCourseListItem(
      id: _readString(json['id']),
      publicId: _readString(json['public_id']),
      slug: _readString(json['slug']),
      title: _readString(json['title']),
      status: _readString(json['status']),
      originalPrice: _readInt(json['original_price']),
      discountPrice: _readInt(json['discount_price']),
      collectionsCount: _readInt(json['collections_count']),
      thumbnail: _readNullableString(json['thumbnail']),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  String get normalizedStatus => status.trim().toLowerCase();

  String get displayStatus {
    switch (normalizedStatus) {
      case 'published':
        return 'Published';
      case 'draft':
        return 'Draft';
      case 'hidden':
        return 'Hidden';
      default:
        if (status.trim().isEmpty) {
          return 'Unknown';
        }
        return status.trim();
    }
  }
}

class AdminTransactionsData {
  const AdminTransactionsData({required this.items, required this.meta});

  final List<AdminTransactionListItem> items;
  final AdminPaginationMeta meta;

  factory AdminTransactionsData.fromJson(Map<String, dynamic> json) {
    return AdminTransactionsData(
      items: _asList(
        json['data'],
      ).map((item) => AdminTransactionListItem.fromJson(item)).toList(),
      meta: AdminPaginationMeta.fromJson(_asMap(json['meta'])),
    );
  }
}

class AdminTransactionListItem {
  const AdminTransactionListItem({
    required this.id,
    required this.code,
    required this.amount,
    required this.refund,
    required this.netAmount,
    required this.status,
    required this.type,
    required this.typeLabel,
    this.courseId,
    this.objectId,
    this.objectType,
    this.createdAt,
    this.user,
  });

  final int id;
  final String code;
  final int amount;
  final int refund;
  final int netAmount;
  final String status;
  final String type;
  final String typeLabel;
  final String? courseId;
  final String? objectId;
  final String? objectType;
  final DateTime? createdAt;
  final AdminTransactionUser? user;

  factory AdminTransactionListItem.fromJson(Map<String, dynamic> json) {
    final userMap = _asMap(json['user']);

    return AdminTransactionListItem(
      id: _readInt(json['id']),
      code: _readString(json['code']),
      amount: _readInt(json['amount']),
      refund: _readInt(json['refund']),
      netAmount: _readInt(json['net_amount']),
      status: _readString(json['status']),
      type: _readString(json['type']),
      typeLabel: _readString(json['type_label']),
      courseId: _readNullableString(json['course_id']),
      objectId: _readNullableString(json['object_id']),
      objectType: _readNullableString(json['object_type']),
      createdAt: _readDateTime(json['created_at']),
      user: userMap.isEmpty ? null : AdminTransactionUser.fromJson(userMap),
    );
  }

  String get normalizedStatus => status.trim().toUpperCase();

  String get displayStatus {
    switch (normalizedStatus) {
      case 'COMPLETED':
        return 'Completed';
      case 'PENDING':
        return 'Pending';
      case 'FAILED':
        return 'Failed';
      case 'UNPROCESSED':
        return 'Unprocessed';
      default:
        if (status.trim().isEmpty) {
          return 'Unknown';
        }
        return status.trim();
    }
  }
}

class AdminTransactionUser {
  const AdminTransactionUser({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.role,
    this.roleName,
  });

  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? role;
  final String? roleName;

  factory AdminTransactionUser.fromJson(Map<String, dynamic> json) {
    return AdminTransactionUser(
      id: _readNullableInt(json['id']),
      name: _readNullableString(json['name']),
      email: _readNullableString(json['email']),
      phone: _readNullableString(json['phone']),
      role: _readNullableString(json['role']),
      roleName: _readNullableString(json['role_name']),
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

DateTime? _readDateTime(dynamic value) {
  final text = _readString(value);
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
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

int? _readNullableInt(dynamic value) {
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
