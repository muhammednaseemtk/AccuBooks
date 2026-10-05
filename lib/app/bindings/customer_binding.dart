import 'package:get/get.dart';
import '../../controllers/customer_controller.dart';
import '../../repositories/customer_repository.dart';

class CustomerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerRepository>(() => CustomerRepository(), fenix: true);
    Get.lazyPut<CustomerController>(() => CustomerController(
      customerRepo: Get.find<CustomerRepository>(),
    ), fenix: true);
  }
}
