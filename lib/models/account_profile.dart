import 'package:edly/models/auth_user.dart';

class AccountProfileScreenData {
  const AccountProfileScreenData({
    required this.profile,
    required this.form,
    this.message,
  });

  final AccountProfile profile;
  final AccountProfileFormSchema form;
  final String? message;

  factory AccountProfileScreenData.fromJson(Map<String, dynamic> json) {
    return AccountProfileScreenData(
      profile: AccountProfile.fromJson(_asMap(json['profile'])),
      form: AccountProfileFormSchema.fromJson(_asMap(json['form'])),
      message: _readNullableString(json['message']),
    );
  }

  AccountProfileScreenData copyWith({
    AccountProfile? profile,
    AccountProfileFormSchema? form,
    String? message,
  }) {
    return AccountProfileScreenData(
      profile: profile ?? this.profile,
      form: form ?? this.form,
      message: message ?? this.message,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const {};
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.balance,
    this.avatarUrl,
    this.role,
    this.roleName,
    this.lastLoginAt,
    this.birthday,
    this.userType,
    this.userTypeLabel,
    this.provinceId,
    this.districtId,
    this.schoolId,
    this.provinceName,
    this.districtName,
    this.schoolName,
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
  final String? birthday;
  final String? userType;
  final String? userTypeLabel;
  final int? provinceId;
  final int? districtId;
  final int? schoolId;
  final String? provinceName;
  final String? districtName;
  final String? schoolName;

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    return AccountProfile(
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
      birthday: _readNullableString(json['birthday']),
      userType: _readNullableString(json['user_type']),
      userTypeLabel: _readNullableString(json['user_type_label']),
      provinceId: _readNullableInt(json['province_id']),
      districtId: _readNullableInt(json['district_id']),
      schoolId: _readNullableInt(json['school_id']),
      provinceName: _readNullableString(json['province_name']),
      districtName: _readNullableString(json['district_name']),
      schoolName: _readNullableString(json['school_name']),
    );
  }

  AuthUser toAuthUser({AuthUser? fallbackUser}) {
    return AuthUser(
      id: id,
      name: name,
      email: email,
      phone: phone,
      balance: balance ?? fallbackUser?.balance,
      avatarUrl: avatarUrl,
      role: role,
      roleName: roleName,
      lastLoginAt: lastLoginAt,
    );
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

class AccountProfileFormSchema {
  const AccountProfileFormSchema({
    required this.name,
    required this.email,
    required this.birthday,
    required this.userType,
    required this.province,
    required this.district,
    required this.school,
    required this.userTypeOptions,
    required this.birthYearOptions,
    required this.provinceOptions,
    required this.districtOptions,
    required this.schoolOptions,
  });

  final AccountProfileFieldState name;
  final AccountProfileFieldState email;
  final AccountProfileFieldState birthday;
  final AccountProfileFieldState userType;
  final AccountProfileFieldState province;
  final AccountProfileFieldState district;
  final AccountProfileFieldState school;
  final List<AccountProfileSelectOption> userTypeOptions;
  final List<AccountProfileSelectOption> birthYearOptions;
  final List<AccountProfileLocationOption> provinceOptions;
  final List<AccountProfileLocationOption> districtOptions;
  final List<AccountProfileLocationOption> schoolOptions;

  factory AccountProfileFormSchema.fromJson(Map<String, dynamic> json) {
    final fields = _asMap(json['fields']);
    final options = _asMap(json['options']);

    return AccountProfileFormSchema(
      name: AccountProfileFieldState.fromJson(_asMap(fields['name'])),
      email: AccountProfileFieldState.fromJson(_asMap(fields['email'])),
      birthday: AccountProfileFieldState.fromJson(_asMap(fields['birthday'])),
      userType: AccountProfileFieldState.fromJson(_asMap(fields['user_type'])),
      province: AccountProfileFieldState.fromJson(
        _asMap(fields['province_id']),
      ),
      district: AccountProfileFieldState.fromJson(
        _asMap(fields['district_id']),
      ),
      school: AccountProfileFieldState.fromJson(_asMap(fields['school_id'])),
      userTypeOptions: _readSelectOptions(options['user_types']),
      birthYearOptions: _readSelectOptions(options['birth_years']),
      provinceOptions: _readLocationOptions(options['provinces']),
      districtOptions: _readLocationOptions(options['districts']),
      schoolOptions: _readLocationOptions(options['schools']),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const {};
  }

  static List<AccountProfileSelectOption> _readSelectOptions(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => _asMap(item))
        .map(AccountProfileSelectOption.fromJson)
        .toList(growable: false);
  }

  static List<AccountProfileLocationOption> _readLocationOptions(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => _asMap(item))
        .map(AccountProfileLocationOption.fromJson)
        .toList(growable: false);
  }
}

class AccountProfileFieldState {
  const AccountProfileFieldState({
    required this.enabled,
    required this.required,
    required this.editable,
  });

  final bool enabled;
  final bool required;
  final bool editable;

  factory AccountProfileFieldState.fromJson(Map<String, dynamic> json) {
    return AccountProfileFieldState(
      enabled: _readBool(json['enabled']),
      required: _readBool(json['required']),
      editable: _readBool(json['editable']),
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }

    return false;
  }
}

class AccountProfileSelectOption {
  const AccountProfileSelectOption({required this.value, required this.label});

  final String value;
  final String label;

  factory AccountProfileSelectOption.fromJson(Map<String, dynamic> json) {
    return AccountProfileSelectOption(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

class AccountProfileLocationOption {
  const AccountProfileLocationOption({required this.id, required this.name});

  final int id;
  final String name;

  factory AccountProfileLocationOption.fromJson(Map<String, dynamic> json) {
    return AccountProfileLocationOption(
      id: _readInt(json['id']),
      name: (json['name'] ?? '').toString(),
    );
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
}
