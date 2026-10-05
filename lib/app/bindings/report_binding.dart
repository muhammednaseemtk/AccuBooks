import 'package:get/get.dart';
import '../../controllers/report_controller.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/journal_repository.dart';
import '../../repositories/report_repository.dart';
import '../../services/report_service.dart';

class ReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReportRepository>(() => ReportRepository(), fenix: true);
    Get.lazyPut<ReportService>(() => ReportService(reportRepo: Get.find<ReportRepository>()), fenix: true);
    Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<JournalRepository>(() => JournalRepository(), fenix: true);
    Get.lazyPut<ReportController>(() => ReportController(
      reportService: Get.find<ReportService>(),
      accountRepo: Get.find<AccountRepository>(),
      journalRepo: Get.find<JournalRepository>(),
    ));
  }
}
