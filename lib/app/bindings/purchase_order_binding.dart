import 'package:get/get.dart';
import '../../controllers/purchase_order_controller.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_order_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/purchase_order_service.dart';

class PurchaseOrderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PurchaseOrderRepository>(() => PurchaseOrderRepository(), fenix: true);
    Get.lazyPut<PurchaseOrderService>(() => PurchaseOrderService(
          orderRepo: Get.find<PurchaseOrderRepository>(),
          purchaseRepo: Get.isRegistered<PurchaseRepository>() ? Get.find<PurchaseRepository>() : PurchaseRepository(),
          productRepo: Get.find<ProductRepository>(),
          supplierRepo: Get.find<SupplierRepository>(),
        ), fenix: true);
    Get.lazyPut<PurchaseOrderController>(() => PurchaseOrderController(
          service: Get.find<PurchaseOrderService>(),
          supplierRepo: Get.find<SupplierRepository>(),
          productRepo: Get.find<ProductRepository>(),
          purchaseRepo: Get.isRegistered<PurchaseRepository>() ? Get.find<PurchaseRepository>() : PurchaseRepository(),
        ), fenix: true);
  }
}
