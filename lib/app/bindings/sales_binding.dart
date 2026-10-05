import 'package:get/get.dart';
import '../../controllers/sales_controller.dart';
import '../../repositories/company_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../services/sales_service.dart';

class SalesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SalesRepository>(() => SalesRepository(), fenix: true);
    Get.lazyPut<SalesService>(() => SalesService(salesRepo: Get.find<SalesRepository>()), fenix: true);
    Get.lazyPut<SalesController>(() => SalesController(
      salesService: Get.find<SalesService>(),
      customerRepo: Get.find<CustomerRepository>(),
      productRepo: Get.find<ProductRepository>(),
      companyRepo: Get.find<CompanyRepository>(),
    ));
  }
}
