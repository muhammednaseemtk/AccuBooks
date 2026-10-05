import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_pages.dart';
import 'theme/app_theme.dart';

class AccuBooksApp extends StatelessWidget {
  final ThemeMode initialThemeMode;
  final String? initialRoute;

  const AccuBooksApp({
    super.key,
    this.initialThemeMode = ThemeMode.light,
    this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'AccuBooks Accounting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: initialThemeMode,
      initialBinding: InitialBinding(),
      initialRoute: initialRoute ?? AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.fade,
      transitionDuration: const Duration(milliseconds: 100),
    );
  }
}
