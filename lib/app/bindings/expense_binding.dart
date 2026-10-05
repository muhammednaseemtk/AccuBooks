import 'package:get/get.dart';
import '../../controllers/expense_controller.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../services/accounting_service.dart';

class ExpenseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExpenseRepository>(() => ExpenseRepository(), fenix: true);
    Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<AccountingService>(() => AccountingService(), fenix: true);
    Get.lazyPut<ExpenseController>(() => ExpenseController(
      expenseRepo: Get.find<ExpenseRepository>(),
      accountRepo: Get.find<AccountRepository>(),
      accountingService: Get.find<AccountingService>(),
    ));
  }
}
