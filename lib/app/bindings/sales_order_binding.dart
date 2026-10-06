import 'package:get/get.dart';
import '../../controllers/sales_order_controller.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/sales_order_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../services/sales_order_service.dart';

class SalesOrderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SalesOrderRepository>(() => SalesOrderRepository(), fenix: true);
    Get.lazyPut<SalesOrderService>(() => SalesOrderService(
          orderRepo: Get.find<SalesOrderRepository>(),
          salesRepo: Get.isRegistered<SalesRepository>() ? Get.find<SalesRepository>() : SalesRepository(),
          productRepo: Get.find<ProductRepository>(),
          customerRepo: Get.find<CustomerRepository>(),
        ), fenix: true);
    Get.lazyPut<SalesOrderController>(() => SalesOrderController(
          service: Get.find<SalesOrderService>(),
          customerRepo: Get.find<CustomerRepository>(),
          productRepo: Get.find<ProductRepository>(),
          salesRepo: Get.isRegistered<SalesRepository>() ? Get.find<SalesRepository>() : SalesRepository(),
        ), fenix: true);
  }
}
