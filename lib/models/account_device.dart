class AccountDeviceListResponse {
  const AccountDeviceListResponse({
    required this.devices,
    required this.maxDevices,
  });

  final List<AccountDevice> devices;
  final int? maxDevices;

  factory AccountDeviceListResponse.fromJson(Map<String, dynamic> json) {
    final rawDevices = json['data'];
    final rawMeta = json['meta'];

    return AccountDeviceListResponse(
      devices: rawDevices is List
          ? rawDevices
                .map((item) => _asMap(item))
                .map(AccountDevice.fromJson)
                .toList(growable: false)
          : const <AccountDevice>[],
      maxDevices: _readNullableInt(_asMap(rawMeta)['max_devices']),
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
}

class AccountDevice {
  const AccountDevice({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.isCurrent,
    this.lastLoginAt,
    this.lastActiveAt,
  });

  final int id;
  final String deviceName;
  final String deviceType;
  final bool isCurrent;
  final DateTime? lastLoginAt;
  final DateTime? lastActiveAt;

  factory AccountDevice.fromJson(Map<String, dynamic> json) {
    return AccountDevice(
      id: _readInt(json['id']),
      deviceName: _readString(json['device_name'], fallback: 'Thiết bị di động'),
      deviceType: _readString(json['device_type'], fallback: 'mobile'),
      isCurrent: _readBool(json['is_current']),
      lastLoginAt: _readDateTime(json['last_login_at']),
      lastActiveAt: _readDateTime(json['last_active_at']),
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
      return int.tryParse(value.trim()) ?? 0;
    }

    return 0;
  }

  static String _readString(dynamic value, {required String fallback}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return fallback;
    }

    return text;
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

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString().trim());
  }
}
