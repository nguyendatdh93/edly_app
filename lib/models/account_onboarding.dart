class AccountOnboardingData {
  const AccountOnboardingData({
    required this.show,
    this.phone,
    required this.phoneLocked,
    required this.examInterestSat,
    required this.examInterestIelts,
    this.role,
    required this.roleOptions,
  });

  final bool show;
  final String? phone;
  final bool phoneLocked;
  final bool examInterestSat;
  final bool examInterestIelts;
  final String? role;
  final List<AccountOnboardingRoleOption> roleOptions;

  factory AccountOnboardingData.fromJson(Map<String, dynamic> json) {
    final onboarding = _asMap(json['onboarding']);

    return AccountOnboardingData(
      show: _readBool(onboarding['show']),
      phone: _readNullableString(onboarding['phone']),
      phoneLocked: _readBool(onboarding['phone_locked']),
      examInterestSat: _readBool(onboarding['exam_interest_sat']),
      examInterestIelts: _readBool(onboarding['exam_interest_ielts']),
      role: _readNullableString(onboarding['role']),
      roleOptions: _readRoleOptions(onboarding['role_options']),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }

    return const {};
  }

  static List<AccountOnboardingRoleOption> _readRoleOptions(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => _asMap(item))
        .map(AccountOnboardingRoleOption.fromJson)
        .toList(growable: false);
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

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class AccountOnboardingRoleOption {
  const AccountOnboardingRoleOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  factory AccountOnboardingRoleOption.fromJson(Map<String, dynamic> json) {
    return AccountOnboardingRoleOption(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}
