import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/controllers/auth_controller.dart';
import 'package:accubooks/models/country_model.dart';
import 'package:accubooks/repositories/auth_repository.dart';
import 'package:accubooks/screens/auth/login_screen.dart';
import 'package:accubooks/screens/auth/signup_screen.dart';
import 'package:accubooks/screens/auth/widgets/country_picker_dialog.dart';
import 'package:accubooks/services/auth_service.dart';

import 'package:accubooks/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('AccuBooks Phone Number & Country Selector Requirements', () {
    // -------------------------------------------------------------
    // Requirement 1, 2, 3: Numbers only, no letters, special chars, spaces
    // -------------------------------------------------------------
    testWidgets('Requirement 1, 2, 3: Phone field accepts digits only; rejects letters, special chars, and spaces', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.find<AuthController>();

      await tester.pumpWidget(wrapWithTheme(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Find the phone TextFormField
      final phoneFinder = find.byWidgetPredicate((widget) {
        return widget is TextField && widget.keyboardType == TextInputType.number;
      });
      expect(phoneFinder, findsOneWidget);

      // Attempt typing alphabetic letters
      await tester.enterText(phoneFinder, 'abcdef');
      await tester.pump();
      expect(controller.signupPhoneController.text, '');

      // Attempt typing special characters & symbols
      await tester.enterText(phoneFinder, '+-!@#\$%^&*()');
      await tester.pump();
      expect(controller.signupPhoneController.text, '');

      // Attempt typing spaces
      await tester.enterText(phoneFinder, '   ');
      await tester.pump();
      expect(controller.signupPhoneController.text, '');

      // Attempt mixed alphanumeric with symbols and spaces
      await tester.enterText(phoneFinder, '987 abc-654 32#10');
      await tester.pump();
      // Only digits 9876543210 should remain
      expect(controller.signupPhoneController.text, '9876543210');
    });

    // -------------------------------------------------------------
    // Requirement 4, 5: Country selector and calling code changes
    // -------------------------------------------------------------
    testWidgets('Requirement 4, 5: Country selector opens searchable dialog, changes country and calling code correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.find<AuthController>();

      await tester.pumpWidget(wrapWithTheme(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Default country should be India (+91)
      expect(controller.signupCountry.value.dialCode, '+91');
      expect(find.text('+91'), findsOneWidget);

      // Tap country selector button to open picker
      final countrySelectorButton = find.byWidgetPredicate((w) =>
          w is InkWell && find.descendant(of: find.byWidget(w), matching: find.text('+91')).evaluate().isNotEmpty);
      expect(countrySelectorButton, findsOneWidget);
      await tester.ensureVisible(countrySelectorButton);
      await tester.tap(countrySelectorButton);
      await tester.pumpAndSettle();

      // Country picker dialog should be open
      expect(find.byType(CountryPickerDialog), findsOneWidget);
      expect(find.text('Select Country'), findsOneWidget);

      // Search for United States
      final searchField = find.descendant(of: find.byType(CountryPickerDialog), matching: find.byType(TextField));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'United States');
      await tester.pumpAndSettle();

      // Select United States from list
      final usItem = find.descendant(of: find.byType(ListView), matching: find.text('United States'));
      expect(usItem, findsOneWidget);
      await tester.tap(usItem);
      await tester.pumpAndSettle();

      // Dialog closed and country updated to United States (+1)
      expect(find.byType(CountryPickerDialog), findsNothing);
      expect(controller.signupCountry.value.code, 'US');
      expect(controller.signupCountry.value.dialCode, '+1');
      expect(find.text('+1'), findsOneWidget);

      // Change again to UAE (+971)
      final usButton = find.byWidgetPredicate((w) =>
          w is InkWell && find.descendant(of: find.byWidget(w), matching: find.text('+1')).evaluate().isNotEmpty);
      await tester.tap(usButton);
      await tester.pumpAndSettle();

      final searchField2 = find.descendant(of: find.byType(CountryPickerDialog), matching: find.byType(TextField));
      await tester.enterText(searchField2, '971');
      await tester.pumpAndSettle();

      final uaeItem = find.descendant(of: find.byType(ListView), matching: find.text('United Arab Emirates'));
      expect(uaeItem, findsOneWidget);
      await tester.tap(uaeItem);
      await tester.pumpAndSettle();

      expect(controller.signupCountry.value.code, 'AE');
      expect(controller.signupCountry.value.dialCode, '+971');
      expect(find.text('+971'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Requirement 6: Country-specific validation
    // -------------------------------------------------------------
    test('Requirement 6: Country-specific validation rules', () {
      // 1. India: 10 digits starting with 6-9
      const india = Countries.india;
      expect(india.isValid('9876543210'), isTrue);
      expect(india.isValid('8123456789'), isTrue);
      expect(india.isValid('12345'), isFalse, reason: 'Too short');
      expect(india.isValid('987654321012'), isFalse, reason: 'Too long');
      expect(india.isValid('1234567890'), isFalse, reason: 'Invalid Indian mobile prefix');

      // 2. United States: 10 digits NANP
      const us = Countries.unitedStates;
      expect(us.isValid('2025550123'), isTrue);
      expect(us.isValid('9876543210'), isTrue);
      expect(us.isValid('12345'), isFalse);
      expect(us.isValid('20255501239'), isFalse);

      // 3. United Kingdom: 10 digits
      const uk = Countries.unitedKingdom;
      expect(uk.isValid('7911123456'), isTrue);
      expect(uk.isValid('12345'), isFalse);
      expect(uk.isValid('791112345678'), isFalse);

      // 4. UAE: 9 digits
      const uae = Countries.uae;
      expect(uae.isValid('501234567'), isTrue);
      expect(uae.isValid('551234567'), isTrue);
      expect(uae.isValid('9876543210'), isFalse, reason: 'UAE is 9 digits, not 10');

      // 5. Saudi Arabia: 9 digits
      const saudi = Countries.saudiArabia;
      expect(saudi.isValid('501234567'), isTrue);
      expect(saudi.isValid('12345'), isFalse);

      // 6. Qatar: 8 digits
      const qatar = Countries.qatar;
      expect(qatar.isValid('55123456'), isTrue);
      expect(qatar.isValid('551234567'), isFalse, reason: 'Qatar is 8 digits');

      // 7. Kuwait: 8 digits
      const kuwait = Countries.kuwait;
      expect(kuwait.isValid('51234567'), isTrue);
      expect(kuwait.isValid('512345678'), isFalse, reason: 'Kuwait is 8 digits');

      // 8. Oman: 8 digits
      const oman = Countries.oman;
      expect(oman.isValid('91234567'), isTrue);
      expect(oman.isValid('912345678'), isFalse, reason: 'Oman is 8 digits');
    });

    testWidgets('Requirement 6b: Shows "Enter a valid phone number" and blocks submission when invalid', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.find<AuthController>();

      await tester.pumpWidget(wrapWithTheme(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Fill in valid info except phone
      controller.signupFullNameController.text = 'Test User';
      controller.signupCompanyController.text = 'Acme Corp';
      controller.signupEmailController.text = 'test@acme.com';
      controller.signupPasswordController.text = 'Password123';
      controller.signupConfirmPasswordController.text = 'Password123';
      controller.signupPhoneController.text = '12345'; // Invalid length for India (+91)

      // Submit
      await controller.signup();
      await tester.pump();

      expect(controller.errorMessage.value, 'Enter a valid phone number');
      expect(find.text('Enter a valid phone number'), findsWidgets);

      // Let snackbar timer settle
      await tester.pump(const Duration(seconds: 5));
    });

    // -------------------------------------------------------------
    // Requirement 7: International format normalization & storage
    // -------------------------------------------------------------
    test('Requirement 7: Phone number normalization to international format safely prevents duplicates', () {
      // Normal India number
      expect(Countries.formatFullPhoneNumber('9876543210', '+91'), '+919876543210');

      // Normal US number
      expect(Countries.formatFullPhoneNumber('2025550123', '+1'), '+12025550123');

      // Normal UAE number
      expect(Countries.formatFullPhoneNumber('501234567', '+971'), '+971501234567');

      // Accidental prefix in pasted text
      expect(Countries.formatFullPhoneNumber('919876543210', '+91'), '+919876543210');

      // Leading trunk zero
      expect(Countries.formatFullPhoneNumber('07911123456', '+44'), '+447911123456');

      // Ensure never ++91
      final formatted = Countries.formatFullPhoneNumber('9876543210', '+91');
      expect(formatted.startsWith('++'), isFalse);
      expect(formatted.startsWith('+91'), isTrue);

      // Ensure never +91+91
      expect(formatted.contains('+91+91'), isFalse);

      // Ensure never trailing +91
      expect(formatted.endsWith('+91'), isFalse);
    });

    // -------------------------------------------------------------
    // Requirement 8: Signup still works and stores formatted phone
    // -------------------------------------------------------------
    test('Requirement 8: Signup creates account with international formatted phone', () async {
      final authRepo = Get.find<AuthRepository>();
      final authService = Get.find<AuthService>();
      final controller = Get.find<AuthController>();

      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'intl_user_$ts@example.com';

      controller.signupFullNameController.text = 'International User';
      controller.signupCompanyController.text = 'Global Trade $ts';
      controller.signupEmailController.text = email;
      controller.signupPasswordController.text = 'Password123';
      controller.signupConfirmPasswordController.text = 'Password123';
      controller.signupCountry.value = Countries.india;
      controller.signupPhoneController.text = '9876543210';

      // Verify full formatted phone number
      expect(controller.fullSignupPhoneNumber, '+919876543210');

      // Execute signup with full international phone number
      final user = await authService.signup(
        fullName: controller.signupFullNameController.text,
        email: controller.signupEmailController.text,
        phone: controller.fullSignupPhoneNumber,
        password: controller.signupPasswordController.text,
        companyName: controller.signupCompanyController.text,
      );

      expect(user.phone, '+919876543210');

      // Verify stored user in database
      final fetched = await authRepo.findUserByEmail(email);
      expect(fetched, isNotNull);
      expect(fetched!.phone, '+919876543210');
    });

    // -------------------------------------------------------------
    // Requirement 9: Login screen remains completely unchanged
    // -------------------------------------------------------------
    testWidgets('Requirement 9: Login screen remains unchanged with Email and Password', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Email')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().startsWith('Password')), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Sign In'), findsNothing); // Uses AppButton
      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Requirement 10: Responsive layout on all screen sizes (no overflow)
    // -------------------------------------------------------------
    testWidgets('Requirement 10: Country selector + phone field adapts without overflow on 320x568 (compact)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrapWithTheme(const SignUpScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Phone Number')), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
    });

    testWidgets('Requirement 10: Country selector + phone field renders without overflow on 1920x1080 (desktop)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrapWithTheme(const SignUpScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Phone Number')), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
    });
  });
}
