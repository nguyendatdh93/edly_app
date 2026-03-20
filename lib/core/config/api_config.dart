import 'package:edly/core/config/flavor_config.dart';

/// Cấu hình API cho app mobile. Có thể override bằng `--dart-define`.
class ApiConfig {
  static String get baseUrl {
    final value = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    ).trim();

    final resolvedValue = value.isEmpty
        ? FlavorConfig.instance.defaultBaseUrl
        : value;

    if (resolvedValue.endsWith('/')) {
      return resolvedValue.substring(0, resolvedValue.length - 1);
    }

    return resolvedValue;
  }

  static String get deviceName =>
      'edly-mobile-app-${FlavorConfig.instance.flavor.name}';

  const ApiConfig._();
}
