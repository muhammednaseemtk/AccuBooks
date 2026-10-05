import 'package:get/get.dart';
import '../../controllers/receipt_controller.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/receipt_repository.dart';
import '../../services/accounting_service.dart';
import '../../services/receipt_service.dart';

class ReceiptBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReceiptRepository>(() => ReceiptRepository(), fenix: true);
    Get.lazyPut<CustomerRepository>(() => CustomerRepository(), fenix: true);
    Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<AccountingService>(() => AccountingService(), fenix: true);
    Get.lazyPut<ReceiptService>(() => ReceiptService(
      receiptRepo: Get.find<ReceiptRepository>(),
      customerRepo: Get.find<CustomerRepository>(),
      accountRepo: Get.find<AccountRepository>(),
      accountingService: Get.find<AccountingService>(),
    ), fenix: true);
    Get.lazyPut<ReceiptController>(() => ReceiptController(
      receiptService: Get.find<ReceiptService>(),
      customerRepo: Get.find<CustomerRepository>(),
      accountRepo: Get.find<AccountRepository>(),
    ), fenix: true);
  }
}
