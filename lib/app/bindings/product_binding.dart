import 'package:get/get.dart';
import '../../controllers/product_controller.dart';
import '../../repositories/product_repository.dart';
import '../../services/inventory_service.dart';

class ProductBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductRepository>(() => ProductRepository(), fenix: true);
    Get.lazyPut<InventoryService>(() => InventoryService(productRepo: Get.find<ProductRepository>()), fenix: true);
    Get.lazyPut<ProductController>(() => ProductController(
      productRepo: Get.find<ProductRepository>(),
      inventoryService: Get.find<InventoryService>(),
    ));
  }
}
