import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/database/database_helper.dart';

import '../../controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Initializing database...';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _statusMessage = 'Connecting to workspace...');

      final db = await DatabaseHelper().database;
      await db.rawQuery('SELECT 1;');

      setState(() => _statusMessage = 'Checking user session...');
      await Future.delayed(const Duration(milliseconds: 200));

      final authController = Get.find<AuthController>();
      final hasSession = await authController.checkSession();

      if (hasSession) {
        Get.offNamed(AppRoutes.dashboard);
      } else {
        Get.offNamed(AppRoutes.login);
      }
    } catch (e) {
      Get.offNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_logo.png',
              width: 72,
              height: 72,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              'AccuBooks',
              style: AppTextStyles.h1.copyWith(color: Colors.white, letterSpacing: -0.5),
            ),
            const SizedBox(height: 6),
            Text(
              'Professional Local-First Accounting',
              style: AppTextStyles.body2.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: AppTextStyles.caption.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
