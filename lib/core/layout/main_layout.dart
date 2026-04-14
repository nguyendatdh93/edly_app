import 'package:edly/core/navigation/app_route_tracker.dart';
import 'package:edly/core/navigation/app_routes.dart';
import 'package:edly/pages/home/home_view.dart';
import 'package:edly/pages/menu/menu_drawer_view.dart';
import 'package:edly/pages/teacher/teacher_view.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:edly/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({
    super.key,
    required this.navigatorKey,
    required this.routeTracker,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final AppRouteTracker routeTracker;
  final Widget child;

  static const double _bottomNavHeight = 72;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        routeTracker.currentRouteName,
        routeTracker.currentTabIndex,
      ]),
      builder: (context, _) {
        final String? routeName = routeTracker.currentRouteName.value;
        final bool hideBottomNav =
            !AuthRepository.instance.isSignedIn ||
            routeName == AppRoutes.signIn ||
            routeName == AppRoutes.signUp ||
            routeName == AppRoutes.examRoom ||
            routeName == AppRoutes.lectureRoom;

        if (hideBottomNav) {
          return child;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: _bottomNavHeight),
              child: child,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNav(
                currentIndex: routeTracker.currentTabIndex.value,
                onTap: _onTap,
              ),
            ),
          ],
        );
      },
    );
  }

  void _onTap(int index) {
    if (routeTracker.currentTabIndex.value == index) {
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    routeTracker.currentTabIndex.value = index;
    navigator.pushAndRemoveUntil<void>(
      _buildMainRoute(index),
      (route) => false,
    );
  }

  Route<void> _buildMainRoute(int index) {
    switch (index) {
      case 1:
        return MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.teacher),
          builder: (_) => const TeacherView(),
        );
      case 2:
        return MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.menu),
          builder: (_) => const MenuDrawerView(),
        );
      case 0:
      default:
        return MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.home),
          builder: (_) => const HomeView(),
        );
    }
  }
}
