import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/sequence_utils.dart';
import '../models/company_model.dart';
import '../repositories/company_repository.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';

class SettingsController extends GetxController {
  final CompanyRepository _companyRepo;
  final BackupService _backupService;
  final AuthService? _authService;
  final DatabaseHelper _dbHelper;

  SettingsController({
    CompanyRepository? companyRepo,
    BackupService? backupService,
    AuthService? authService,
    DatabaseHelper? dbHelper,
  })  : _companyRepo = companyRepo ?? CompanyRepository(),
        _backupService = backupService ?? BackupService(),
        _authService = authService ?? (Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null),
        _dbHelper = dbHelper ?? DatabaseHelper();

  final company = Rxn<CompanyModel>();
  final isDarkMode = false.obs;
  final isSidebarCollapsed = false.obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final dbInfo = <String, dynamic>{}.obs;

  bool get canManageBackups {
    final auth = _authService ?? (Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null);
    return auth?.isAdmin ?? true;
  }

  void toggleSidebar() {
    isSidebarCollapsed.value = !isSidebarCollapsed.value;
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('isSidebarCollapsed', isSidebarCollapsed.value);
      }).catchError((_) {});
    } catch (_) {}
  }

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      isLoading.value = true;
      final comp = await _companyRepo.getCompany();
      company.value = comp;

      final prefs = await SharedPreferences.getInstance();
      isDarkMode.value = prefs.getBool(AppConstants.prefThemeMode) ?? false;
      isSidebarCollapsed.value = prefs.getBool('isSidebarCollapsed') ?? false;

      final info = await _backupService.getDatabaseInfo();
      dbInfo.assignAll(info);
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleTheme(bool dark) async {
    isDarkMode.value = dark;
    Get.changeThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefThemeMode, dark);
  }

  Future<bool> updateCompany(CompanyModel updated) async {
    try {
      isSubmitting.value = true;
      await _companyRepo.updateCompany(updated);
      company.value = updated;
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (Get.context != null) {
        Get.snackbar('Success', 'Company details updated successfully', snackPosition: SnackPosition.BOTTOM);
      }
      return true;
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to update company: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> createBackup() async {
    if (!canManageBackups) {
      if (Get.context != null) {
        Get.snackbar(
          'Access Denied',
          'Only administrators or owners can backup the database.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }

    try {
      isSubmitting.value = true;
      final path = await _backupService.createBackup();
      // If user cancelled the file picker, abort silently without creating a fallback or showing success
      if (path == null || path.isEmpty) {
        return;
      }

      await loadSettings();
      if (Get.context != null) {
        Get.snackbar(
          'Backup Created',
          'Database backup successfully saved at: $path',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Backup Error', 'Failed to create backup: $e', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> restoreBackup() async {
    if (!canManageBackups) {
      if (Get.context != null) {
        Get.snackbar(
          'Access Denied',
          'Only administrators or owners can restore the database.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }

    try {
      isSubmitting.value = true;
      final success = await _backupService.restoreFromBackup();
      if (success) {
        // Safely purge all in-memory user controllers, cached lists, and state
        AuthService.clearUserControllers();
        // Reconcile document sequence reservations against the restored database
        await SequenceUtils.reconcileAfterRestore(_dbHelper);
        // Reload settings and refreshed database info
        await loadSettings();
        if (Get.context != null) {
          Get.snackbar(
            'Restore Complete',
            'Database restored successfully. All records have been refreshed.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Restore Error', 'Failed to restore database: $e', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isSubmitting.value = false;
    }
  }
}
