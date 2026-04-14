import 'package:edly/app_bootstrap_view.dart';
import 'package:edly/core/config/flavor_config.dart';
import 'package:edly/core/layout/main_layout.dart';
import 'package:edly/core/navigation/app_route_tracker.dart';
import 'package:edly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class EdlyApp extends StatelessWidget {
  const EdlyApp({super.key});

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  static final AppRouteTracker _routeTracker = AppRouteTracker();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: FlavorConfig.instance.appName,
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeTracker],
      builder: (context, child) {
        return MainLayout(
          navigatorKey: _navigatorKey,
          routeTracker: _routeTracker,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
          hintStyle: const TextStyle(color: AppColors.textHint),
        ),
      ),
      home: const AppBootstrapView(),
    );
  }
}
