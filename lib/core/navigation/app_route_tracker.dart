import 'package:edly/core/navigation/app_routes.dart';
import 'package:flutter/widgets.dart';

class AppRouteTracker extends NavigatorObserver {
  AppRouteTracker({
    int initialTabIndex = 0,
  }) : currentTabIndex = ValueNotifier<int>(initialTabIndex);

  final ValueNotifier<String?> currentRouteName = ValueNotifier<String?>(null);
  final ValueNotifier<int> currentTabIndex;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sync(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _sync(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _sync(newRoute);
  }

  void _sync(Route<dynamic>? route) {
    final String? routeName = route?.settings.name;
    currentRouteName.value = routeName;

    switch (routeName) {
      case AppRoutes.home:
        currentTabIndex.value = 0;
        break;
      case AppRoutes.teacher:
        currentTabIndex.value = 1;
        break;
      case AppRoutes.menu:
        currentTabIndex.value = 2;
        break;
    }
  }
}
