import 'package:get/get.dart';
import '../../controllers/payment_controller.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/accounting_service.dart';
import '../../services/payment_service.dart';

class PaymentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentRepository>(() => PaymentRepository(), fenix: true);
    Get.lazyPut<SupplierRepository>(() => SupplierRepository(), fenix: true);
    Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<AccountingService>(() => AccountingService(), fenix: true);
    Get.lazyPut<PaymentService>(() => PaymentService(
      paymentRepo: Get.find<PaymentRepository>(),
      supplierRepo: Get.find<SupplierRepository>(),
      accountRepo: Get.find<AccountRepository>(),
      accountingService: Get.find<AccountingService>(),
    ), fenix: true);
    Get.lazyPut<PaymentController>(() => PaymentController(
      paymentService: Get.find<PaymentService>(),
      supplierRepo: Get.find<SupplierRepository>(),
      accountRepo: Get.find<AccountRepository>(),
    ));
  }
}
