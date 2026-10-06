import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:accubooks/controllers/auth_controller.dart';
import 'package:accubooks/repositories/auth_repository.dart';
import 'package:accubooks/screens/auth/forgot_password_screen.dart';
import 'package:accubooks/screens/auth/login_screen.dart';
import 'package:accubooks/screens/auth/reset_password_screen.dart';
import 'package:accubooks/screens/auth/signup_screen.dart';
import 'package:accubooks/services/auth_service.dart';

void main() {
  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    Get.put<AuthRepository>(AuthRepository(), permanent: true);
    Get.put<AuthService>(AuthService(authRepo: Get.find<AuthRepository>()), permanent: true);
    Get.put<AuthController>(AuthController(authService: Get.find<AuthService>()), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  Widget wrapWithTheme(Widget child) {
    return GetMaterialApp(
      home: child,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Inter',
      ),
    );
  }

  final testSizes = [
    const Size(320, 568),   // Small mobile (iPhone SE 1st gen)
    const Size(375, 667),   // iPhone 8
    const Size(390, 844),   // iPhone 12/13/14
    const Size(430, 932),   // iPhone 14 Pro Max
    const Size(600, 900),   // Small tablet
    const Size(768, 1024),  // iPad / tablet
    const Size(1024, 768),  // Tablet landscape / small desktop
    const Size(1366, 768),  // Laptop
    const Size(1920, 1080), // Desktop Full HD
  ];

  group('Responsive Auth UI Tests - No Overflow at any screen size', () {
    for (final size in testSizes) {
      testWidgets('LoginScreen renders without overflow on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(wrapWithTheme(const LoginScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.text('Sign in to continue to your account'), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('SignUpScreen renders without overflow on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(wrapWithTheme(const SignUpScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Create your account'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.byType(SignUpScreen), findsOneWidget);
      });

      testWidgets('ForgotPasswordScreen renders without overflow on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(wrapWithTheme(const ForgotPasswordScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Forgot Password?'), findsOneWidget);
        expect(find.text('Send Reset Link'), findsOneWidget);
      });

      testWidgets('ResetPasswordScreen renders without overflow on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(wrapWithTheme(const ResetPasswordScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsWidgets);
        expect(find.byType(ResetPasswordScreen), findsOneWidget);
      });
    }

    testWidgets('LoginScreen remains scrollable and usable when soft keyboard is open', (tester) async {
      // Simulate mobile screen with keyboard taking bottom 300px
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(wrapWithTheme(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      // Can scroll without any RenderFlex overflow
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
