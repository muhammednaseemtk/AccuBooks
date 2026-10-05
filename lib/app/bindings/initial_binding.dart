import 'package:get/get.dart';
import '../../controllers/settings_controller.dart';
import '../../core/database/database_helper.dart';
import '../../repositories/company_repository.dart';
import '../../repositories/account_repository.dart';
import '../../services/accounting_service.dart';
import '../../services/backup_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<DatabaseHelper>(DatabaseHelper(), permanent: true);
    Get.lazyPut<CompanyRepository>(() => CompanyRepository(), fenix: true);
    Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<AccountingService>(() => AccountingService(), fenix: true);
    Get.lazyPut<BackupService>(() => BackupService(), fenix: true);
    Get.put<SettingsController>(SettingsController(), permanent: true);
  }
}
