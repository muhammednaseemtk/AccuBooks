import 'package:get/get.dart';
import '../../controllers/purchase_controller.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/purchase_service.dart';

class PurchaseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PurchaseRepository>(() => PurchaseRepository(), fenix: true);
    Get.lazyPut<PurchaseService>(() => PurchaseService(purchaseRepo: Get.find<PurchaseRepository>()), fenix: true);
    Get.lazyPut<PurchaseController>(() => PurchaseController(
      purchaseService: Get.find<PurchaseService>(),
      supplierRepo: Get.find<SupplierRepository>(),
      productRepo: Get.find<ProductRepository>(),
    ), fenix: true);
  }
}
