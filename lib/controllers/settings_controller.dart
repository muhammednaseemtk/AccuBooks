import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/company_model.dart';
import '../repositories/company_repository.dart';
import '../services/backup_service.dart';

class SettingsController extends GetxController {
  final CompanyRepository _companyRepo;
  final BackupService _backupService;

  SettingsController({
    CompanyRepository? companyRepo,
    BackupService? backupService,
  })  : _companyRepo = companyRepo ?? CompanyRepository(),
        _backupService = backupService ?? BackupService();

  final company = Rxn<CompanyModel>();
  final isDarkMode = false.obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final dbInfo = <String, dynamic>{}.obs;

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
      Get.snackbar('Success', 'Company details updated successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to update company: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> createBackup() async {
    try {
      isSubmitting.value = true;
      final path = await _backupService.createBackup();
      await loadSettings();
      Get.snackbar(
        'Backup Created',
        'Database backup successfully saved at: $path',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar('Backup Error', 'Failed to create backup: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> restoreBackup() async {
    try {
      isSubmitting.value = true;
      final success = await _backupService.restoreFromBackup();
      if (success) {
        await loadSettings();
        Get.snackbar(
          'Restore Complete',
          'Database restored successfully. Please restart or refresh application.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar('Restore Error', 'Failed to restore database: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSubmitting.value = false;
    }
  }
}
