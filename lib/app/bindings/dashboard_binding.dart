import 'package:get/get.dart';
import '../../controllers/dashboard_controller.dart';
import '../../repositories/report_repository.dart';
import '../../services/report_service.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReportRepository>(() => ReportRepository(), fenix: true);
    Get.lazyPut<ReportService>(() => ReportService(reportRepo: Get.find<ReportRepository>()), fenix: true);
    Get.lazyPut<DashboardController>(() => DashboardController(reportService: Get.find<ReportService>()), fenix: true);
  }
}
