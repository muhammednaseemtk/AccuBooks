import 'package:get/get.dart';
import '../../controllers/account_controller.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/journal_repository.dart';

class AccountBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<JournalRepository>(() => JournalRepository(), fenix: true);
    Get.lazyPut<AccountController>(() => AccountController(
      accountRepo: Get.find<AccountRepository>(),
      journalRepo: Get.find<JournalRepository>(),
    ));
  }
}
