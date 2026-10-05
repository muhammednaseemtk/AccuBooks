import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../repositories/auth_repository.dart';
import '../../services/auth_service.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }
    if (!Get.isRegistered<AuthService>()) {
      Get.lazyPut<AuthService>(() => AuthService(), fenix: true);
    }
    if (!Get.isRegistered<AuthController>()) {
      Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
    }
  }
}
