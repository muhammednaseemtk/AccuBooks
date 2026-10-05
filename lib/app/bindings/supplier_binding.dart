import 'package:get/get.dart';
import '../../controllers/supplier_controller.dart';
import '../../repositories/supplier_repository.dart';

class SupplierBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SupplierRepository>(() => SupplierRepository(), fenix: true);
    Get.lazyPut<SupplierController>(() => SupplierController(
      supplierRepo: Get.find<SupplierRepository>(),
    ), fenix: true);
  }
}
