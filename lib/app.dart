import 'package:edupen/app_bootstrap_view.dart';
import 'package:edupen/core/config/flavor_config.dart';
import 'package:edupen/pages/home/home_constants.dart';
import 'package:edupen/pages/teacher/teacher_view.dart';
import 'package:flutter/material.dart';

class EdlyApp extends StatelessWidget {
  const EdlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: FlavorConfig.instance.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: HomePalette.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: HomePalette.background,
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: HomePalette.textPrimary,
              displayColor: HomePalette.textPrimary,
            ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: HomePalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: HomePalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: HomePalette.primary,
              width: 1.4,
            ),
          ),
          hintStyle: const TextStyle(color: HomePalette.textMuted),
        ),
      ),
      routes: {
        '/teacher': (_) => const TeacherView(),
      },
      home: const AppBootstrapView(),
    );
  }
}
