import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../../services/auth_service.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    // If AuthService is not registered yet, allow splash to initialize it
    if (!Get.isRegistered<AuthService>()) {
      return null;
    }

    final authService = Get.find<AuthService>();
    final isLoggedIn = authService.isAuthenticated.value;

    final publicRoutes = [
      AppRoutes.login,
      AppRoutes.signup,
      AppRoutes.forgotPassword,
      AppRoutes.resetPassword,
      AppRoutes.splash,
    ];

    final isPublic = publicRoutes.contains(route);

    // If unauthenticated user tries to open a protected route
    if (!isLoggedIn && !isPublic) {
      return const RouteSettings(name: AppRoutes.login);
    }

    // If authenticated user tries to open an auth screen
    if (isLoggedIn && isPublic && route != AppRoutes.splash) {
      return const RouteSettings(name: AppRoutes.dashboard);
    }

    return null;
  }
}
