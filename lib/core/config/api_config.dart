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

  static String get webBaseUrl {
    final apiUrl = Uri.parse(baseUrl);
    final pathSegments = List<String>.from(apiUrl.pathSegments);

    if (pathSegments.isNotEmpty && pathSegments.last == 'api') {
      pathSegments.removeLast();
    }

    final normalizedPath = pathSegments.isEmpty
        ? ''
        : '/${pathSegments.join('/')}';

    final resolved = apiUrl.replace(path: normalizedPath).toString();
    return resolved.endsWith('/')
        ? resolved.substring(0, resolved.length - 1)
        : resolved;
  }

  const ApiConfig._();
}
