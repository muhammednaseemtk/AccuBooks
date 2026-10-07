import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/controllers/auth_controller.dart';
import 'package:accubooks/repositories/auth_repository.dart';
import 'package:accubooks/screens/auth/login_screen.dart';
import 'package:accubooks/screens/auth/signup_screen.dart';
import 'package:accubooks/services/auth_service.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/widgets/app_button.dart';
import 'package:accubooks/core/widgets/app_text_field.dart';

void main() {
  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });

    DatabaseHelper.initializeFfi();
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

  Finder appTextFieldWithLabel(String label) {
    return find.byWidgetPredicate((w) => w is AppTextField && w.label == label);
  }

  Finder textFieldInside(Finder parent) {
    return find.descendant(of: parent, matching: find.byType(TextField));
  }

  group('Create Account Screen Tests', () {
    testWidgets('1 & 2: Hint texts and removed password strength / confirm password', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Full Name hint text -> "Full Name"
      final fullNameField = tester.widget<TextField>(
        textFieldInside(appTextFieldWithLabel('Full Name')),
      );
      expect(fullNameField.decoration?.hintText, 'Full Name');

      // Email hint text -> "Email"
      final emailField = tester.widget<TextField>(
        textFieldInside(appTextFieldWithLabel('Email')),
      );
      expect(emailField.decoration?.hintText, 'Email');

      // Password field exists
      expect(appTextFieldWithLabel('Password'), findsOneWidget);

      // Password strength indicator is completely removed
      expect(find.text('Password Strength:'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Confirm Password field is completely removed
      expect(find.text('Confirm Password'), findsNothing);
      expect(appTextFieldWithLabel('Confirm Password'), findsNothing);
    });

    testWidgets('3: Keyboard focus order: Full Name -> Company Name -> Email -> Password -> Create Account button', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const SignUpScreen()));
      await tester.pumpAndSettle();

      final fullNameTextFieldFinder = textFieldInside(appTextFieldWithLabel('Full Name'));
      final companyTextFieldFinder = textFieldInside(appTextFieldWithLabel('Company Name'));
      final emailTextFieldFinder = textFieldInside(appTextFieldWithLabel('Email'));
      final passwordTextFieldFinder = textFieldInside(appTextFieldWithLabel('Password'));
      final createButtonFinder = find.widgetWithText(AppButton, 'Create Account');

      // 1. User focuses Full Name and types
      await tester.showKeyboard(fullNameTextFieldFinder);
      await tester.enterText(fullNameTextFieldFinder, 'John Doe');
      await tester.pumpAndSettle();

      // 2. Presses Next/Enter from Full Name
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // 3. Focus moves to Company Name
      final companyTextField = tester.widget<TextField>(companyTextFieldFinder);
      expect(companyTextField.focusNode?.hasFocus, isTrue);

      // 4. Presses Next/Enter from Company Name
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // 5. Focus moves to Email
      final emailTextField = tester.widget<TextField>(emailTextFieldFinder);
      expect(emailTextField.focusNode?.hasFocus, isTrue);

      // 6. Presses Next/Enter from Email
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // 7. Focus moves to Password
      final passwordTextField = tester.widget<TextField>(passwordTextFieldFinder);
      expect(passwordTextField.focusNode?.hasFocus, isTrue);

      // 8. Presses Enter/Done from Password
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 9. Focus moves to Create Account button
      final elevatedButton = tester.widget<ElevatedButton>(
        find.descendant(of: createButtonFinder, matching: find.byType(ElevatedButton)),
      );
      expect(elevatedButton.focusNode?.hasFocus, isTrue);
    });
  });

  group('Login Screen Tests', () {
    testWidgets('5: Email hint text -> "Email"', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const LoginScreen()));
      await tester.pumpAndSettle();

      final emailField = tester.widget<TextField>(
        textFieldInside(appTextFieldWithLabel('Email')),
      );
      expect(emailField.decoration?.hintText, 'Email');
    });

    testWidgets('4: Keyboard focus order: Email -> Password -> Login button', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const LoginScreen()));
      await tester.pumpAndSettle();

      final emailTextFieldFinder = textFieldInside(appTextFieldWithLabel('Email'));
      final passwordTextFieldFinder = textFieldInside(appTextFieldWithLabel('Password'));
      final loginButtonFinder = find.widgetWithText(AppButton, 'Login');

      // 1. User focuses Email
      await tester.showKeyboard(emailTextFieldFinder);
      await tester.enterText(emailTextFieldFinder, 'user@example.com');
      await tester.pumpAndSettle();

      // 2. Presses Next/Enter from Email
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // 3. Focus moves to Password
      final passwordTextField = tester.widget<TextField>(passwordTextFieldFinder);
      expect(passwordTextField.focusNode?.hasFocus, isTrue);

      // 4. Presses Enter/Done from Password
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 5. Focus moves to Login button
      final elevatedButton = tester.widget<ElevatedButton>(
        find.descendant(of: loginButtonFinder, matching: find.byType(ElevatedButton)),
      );
      expect(elevatedButton.focusNode?.hasFocus, isTrue);
    });
  });
}
