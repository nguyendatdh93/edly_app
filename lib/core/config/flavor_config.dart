enum AppFlavor {
  dev,
  prod,
}

class FlavorConfig {
  FlavorConfig._({
    required this.flavor,
    required this.appName,
    required this.defaultBaseUrl,
  });

  final AppFlavor flavor;
  final String appName;
  final String defaultBaseUrl;

  static late final FlavorConfig instance;

  static void initialize(AppFlavor flavor) {
    instance = switch (flavor) {
      AppFlavor.dev => FlavorConfig._(
          flavor: AppFlavor.dev,
          appName: 'Edly Dev',
          defaultBaseUrl: 'http://edly.local/api',
        ),
      AppFlavor.prod => FlavorConfig._(
          flavor: AppFlavor.prod,
          appName: 'Edly',
          defaultBaseUrl: 'https://edly.vn/api',
        ),
    };
  }

  bool get isDev => flavor == AppFlavor.dev;
  bool get isProd => flavor == AppFlavor.prod;
}
