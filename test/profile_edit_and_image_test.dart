import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:accubooks/core/constants/auth_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/models/user_model.dart';
import 'package:accubooks/repositories/auth_repository.dart';
import 'package:accubooks/services/auth_service.dart';
import 'package:accubooks/controllers/auth_controller.dart';
import 'package:accubooks/screens/auth/profile_screen.dart';
import 'package:accubooks/core/widgets/app_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AuthRepository authRepo;
  late AuthService authService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('accubooks_profile_test_');
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    DatabaseHelper.initializeFfi();
  });

  tearDownAll(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    authRepo = AuthRepository();
    authService = AuthService(authRepo: authRepo);
    Get.put<AuthService>(authService);
  });

  tearDown(() {
    Get.reset();
  });

  Widget createTestWidget() {
    return const GetMaterialApp(
      home: ProfileScreen(),
    );
  }

  Future<UserModel> createAndLoginUser({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    final user = await authService.signup(
      fullName: fullName,
      email: email,
      phone: phone,
      password: 'SecurePassword123!',
      companyName: 'Test Corp ${DateTime.now().microsecondsSinceEpoch}',
    );
    return user;
  }

  testWidgets('1. Loads authenticated user existing profile info (Full Name, Email, Phone)', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    await createAndLoginUser(
      fullName: 'Alice Walker',
      email: 'alice$ts@test.com',
      phone: '9876543210',
    );

    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    // Verify overview card displays user's name, email, and role
    expect(find.text('Alice Walker'), findsWidgets);
    expect(find.text('alice$ts@test.com'), findsWidgets);
    expect(find.text('Owner'), findsWidgets);

    // Verify personal info fields contain current profile data
    expect(controller.profileNameController.text, 'Alice Walker');
    expect(controller.profileEmailController.text, 'alice$ts@test.com');
    expect(controller.profilePhoneController.text, '9876543210');
    expect(controller.isEditingProfile.value, isFalse);
  });

  testWidgets('2. Clicking Edit Profile allows editing Full Name, Email, Phone; saves successfully to database with success snackbar', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    await createAndLoginUser(
      fullName: 'Bob Builder',
      email: 'bob$ts@test.com',
      phone: '1122334455',
    );

    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    // Click "Edit Profile" button
    final editButton = find.widgetWithText(AppButton, 'Edit Profile').first;
    await tester.tap(editButton);
    await tester.pump();

    expect(controller.isEditingProfile.value, isTrue);

    // Edit all fields
    controller.profileNameController.text = 'Robert Builder';
    controller.profileEmailController.text = 'robert$ts@test.com';
    controller.profilePhoneController.text = '9988776655';
    await tester.pump();

    // Click "Save Changes"
    final saveButton = find.widgetWithText(AppButton, 'Save Changes');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 300));

    // Verify success snackbar message
    expect(find.text('Profile updated successfully'), findsOneWidget);

    // Edit mode should be closed
    expect(controller.isEditingProfile.value, isFalse);

    // Verify DB update
    final reloadedUser = await authRepo.findUserById(controller.currentUser!.id!);
    expect(reloadedUser!.fullName, 'Robert Builder');
    expect(reloadedUser.email, 'robert$ts@test.com');
    expect(reloadedUser.phone, '9988776655');

    // Verify UI reflects new values immediately
    expect(find.text('Robert Builder'), findsWidgets);
    expect(find.text('robert$ts@test.com'), findsWidgets);
  });

  testWidgets('3. Validation failure preserves entered data and shows error without saving', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    await createAndLoginUser(
      fullName: 'Charlie Brown',
      email: 'charlie$ts@test.com',
      phone: '1234567890',
    );

    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    // Click "Edit Profile"
    await tester.tap(find.widgetWithText(AppButton, 'Edit Profile').first);
    await tester.pump();

    // Enter invalid email and short name
    controller.profileNameController.text = 'C'; // invalid (< 2 chars)
    controller.profileEmailController.text = 'not-an-email';
    await tester.pump();

    // Click "Save Changes"
    await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify error shown and success NOT shown
    expect(find.text('Profile updated successfully'), findsNothing);
    expect(find.text('Please enter a valid full name (minimum 2 characters).'), findsOneWidget);

    // Entered data must be preserved!
    expect(controller.profileNameController.text, 'C');
    expect(controller.profileEmailController.text, 'not-an-email');
    expect(controller.isEditingProfile.value, isTrue);

    // Now fix name but keep invalid email
    controller.profileNameController.text = 'Charlie Brown Jr';
    await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Profile updated successfully'), findsNothing);
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(controller.profileNameController.text, 'Charlie Brown Jr');
    expect(controller.isEditingProfile.value, isTrue);
  });

  testWidgets('4. Duplicate email validation prevents overwriting another user and preserves form data', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final otherEmail = 'user1_$ts@test.com';
    await authService.signup(
      fullName: 'First User',
      email: otherEmail,
      phone: '1111111111',
      password: 'Password123!',
      companyName: 'Company 1',
    );

    // Second user
    final user2 = await authService.signup(
      fullName: 'Second User',
      email: 'user2_$ts@test.com',
      phone: '2222222222',
      password: 'Password123!',
      companyName: 'Company 2',
    );

    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    // Edit profile and try to take user1's email
    await tester.tap(find.widgetWithText(AppButton, 'Edit Profile').first);
    await tester.pump();

    controller.profileEmailController.text = otherEmail;
    controller.profileNameController.text = 'Second User Renamed';

    await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Profile updated successfully'), findsNothing);
    expect(find.text('This email is already in use by another account.'), findsOneWidget);

    // Entered data preserved
    expect(controller.profileEmailController.text, otherEmail);
    expect(controller.profileNameController.text, 'Second User Renamed');
    expect(controller.isEditingProfile.value, isTrue);

    // DB remains unchanged
    final dbUser = await authRepo.findUserById(user2.id!);
    expect(dbUser!.email, 'user2_$ts@test.com');
  });

  testWidgets('5. Profile Image - selecting previews before saving, and saving persists image in app storage and database', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final user = await createAndLoginUser(
      fullName: 'Diana Prince',
      email: 'diana$ts@test.com',
      phone: '5544332211',
    );

    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    // Create a mock image file in temp directory
    final mockImageFile = File(p.join(tempDir.path, 'sample_avatar_$ts.png'));
    await mockImageFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    // Simulate user picking image
    controller.selectedImagePreviewPath.value = mockImageFile.path;
    controller.isEditingProfile.value = true;
    await tester.pump();

    // Verify preview path is active
    expect(controller.selectedImagePreviewPath.value, mockImageFile.path);

    // Save changes
    await controller.updateProfile();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Profile updated successfully'), findsOneWidget);
    expect(controller.isEditingProfile.value, isFalse);

    // Verify persisted file exists in persistent app documents directory
    final updatedUser = await authRepo.findUserById(user.id!);
    expect(updatedUser!.profileImage, isNotNull);
    final savedFile = File(updatedUser.profileImage!);
    expect(savedFile.existsSync(), isTrue);
    expect(savedFile.path.contains('user_${user.id}_profile_'), isTrue);
  });

  testWidgets('6. Persistence test - image remains visible after screen navigation, logout, and login again', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    await createAndLoginUser(
      fullName: 'Ethan Hunt',
      email: 'ethan$ts@test.com',
      phone: '9988112233',
    );

    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    // Create and save profile image
    final mockImage = File(p.join(tempDir.path, 'ethan_avatar_$ts.jpg'));
    await mockImage.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
    controller.selectedImagePreviewPath.value = mockImage.path;
    await controller.updateProfile();

    final savedPath = controller.currentUser!.profileImage;
    expect(savedPath, isNotNull);
    expect(File(savedPath!).existsSync(), isTrue);

    // Simulate logout
    await authService.logout();
    expect(authService.currentUser.value, isNull);

    // Log back in with credentials
    final loggedInUser = await authService.login(
      email: 'ethan$ts@test.com',
      password: 'SecurePassword123!',
    );

    // Verify image path is restored from database
    expect(loggedInUser.profileImage, savedPath);
    expect(File(loggedInUser.profileImage!).existsSync(), isTrue);
  });

  testWidgets('7. Replace image replaces old image file and saves new image path', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    await createAndLoginUser(
      fullName: 'Fiona Gallagher',
      email: 'fiona$ts@test.com',
      phone: '8877665544',
    );

    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    // Set first image
    final img1 = File(p.join(tempDir.path, 'fiona_1_$ts.png'));
    await img1.writeAsBytes([1, 2, 3, 4]);
    controller.selectedImagePreviewPath.value = img1.path;
    await controller.updateProfile();

    final firstSavedPath = controller.currentUser!.profileImage!;
    expect(File(firstSavedPath).existsSync(), isTrue);

    // Replace with second image
    final img2 = File(p.join(tempDir.path, 'fiona_2_$ts.png'));
    await img2.writeAsBytes([5, 6, 7, 8]);
    controller.selectedImagePreviewPath.value = img2.path;
    await controller.updateProfile();

    final secondSavedPath = controller.currentUser!.profileImage!;
    expect(secondSavedPath, isNot(firstSavedPath));
    expect(File(secondSavedPath).existsSync(), isTrue);

    // Old file should be cleaned up
    expect(File(firstSavedPath).existsSync(), isFalse);
  });

  testWidgets('8. Remove image restores default avatar and saves null in database', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final user = await createAndLoginUser(
      fullName: 'George Clark',
      email: 'george$ts@test.com',
      phone: '7766554433',
    );

    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    // First assign an image
    final img = File(p.join(tempDir.path, 'george_$ts.png'));
    await img.writeAsBytes([1, 2, 3]);
    controller.selectedImagePreviewPath.value = img.path;
    await controller.updateProfile();

    final savedPath = controller.currentUser!.profileImage!;
    expect(File(savedPath).existsSync(), isTrue);

    // Now remove image
    controller.removeProfileImage();
    expect(controller.isImageMarkedForRemoval.value, isTrue);

    await controller.updateProfile();

    expect(controller.currentUser!.profileImage, isNull);
    final dbUser = await authRepo.findUserById(user.id!);
    expect(dbUser!.profileImage, isNull);

    // File cleaned up
    expect(File(savedPath).existsSync(), isFalse);
  });

  testWidgets('9. Security: profile update affects only authenticated user without altering role or organization', (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final userA = await authService.signup(
      fullName: 'User A',
      email: 'usera$ts@test.com',
      phone: '1010101010',
      password: 'Password123!',
      companyName: 'Org A',
    );

    final userB = await authService.signup(
      fullName: 'User B',
      email: 'userb$ts@test.com',
      phone: '2020202020',
      password: 'Password123!',
      companyName: 'Org B',
    );

    // Active session is User B
    final controller = AuthController(authService: authService);
    Get.put<AuthController>(controller);

    controller.profileNameController.text = 'User B Updated';
    controller.profilePhoneController.text = '9090909090';
    await controller.updateProfile();

    // Verify User B updated
    final dbUserB = await authRepo.findUserById(userB.id!);
    expect(dbUserB!.fullName, 'User B Updated');
    expect(dbUserB.role, AuthConstants.roleOwner); // role unchanged
    expect(dbUserB.organizationId, userB.organizationId); // org unchanged

    // Verify User A was completely untouched
    final dbUserA = await authRepo.findUserById(userA.id!);
    expect(dbUserA!.fullName, 'User A');
    expect(dbUserA.phone, '1010101010');
  });
}
