import 'package:get/get.dart';
import '../../controllers/journal_controller.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/journal_repository.dart';
import '../../services/accounting_service.dart';

class JournalBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<JournalRepository>(() => JournalRepository(), fenix: true);
    Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<AccountingService>(() => AccountingService(), fenix: true);
    Get.lazyPut<JournalController>(() => JournalController(
      journalRepo: Get.find<JournalRepository>(),
      accountRepo: Get.find<AccountRepository>(),
      accountingService: Get.find<AccountingService>(),
    ));
  }
}
