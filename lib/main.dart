import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Windows desktop and other desktop environments
  DatabaseHelper.initializeFfi();

  // Load user saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool(AppConstants.prefThemeMode) ?? false;

  runApp(AccuBooksApp(
    initialThemeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
  ));
}
