import 'package:get/get.dart';
import '../../controllers/settings_controller.dart';
import '../../core/database/database_helper.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/company_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/journal_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/receipt_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/accounting_service.dart';
import '../../services/backup_service.dart';
import '../../services/inventory_service.dart';
import '../../services/payment_service.dart';
import '../../services/purchase_service.dart';
import '../../services/receipt_service.dart';
import '../../services/report_service.dart';
import '../../services/sales_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<DatabaseHelper>(DatabaseHelper(), permanent: true);

    // Repositories
    Get.lazyPut<CompanyRepository>(() => CompanyRepository(), fenix: true);
    Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<CustomerRepository>(() => CustomerRepository(), fenix: true);
    Get.lazyPut<SupplierRepository>(() => SupplierRepository(), fenix: true);
    Get.lazyPut<ProductRepository>(() => ProductRepository(), fenix: true);
    Get.lazyPut<SalesRepository>(() => SalesRepository(), fenix: true);
    Get.lazyPut<PurchaseRepository>(() => PurchaseRepository(), fenix: true);
    Get.lazyPut<ReceiptRepository>(() => ReceiptRepository(), fenix: true);
    Get.lazyPut<PaymentRepository>(() => PaymentRepository(), fenix: true);
    Get.lazyPut<ExpenseRepository>(() => ExpenseRepository(), fenix: true);
    Get.lazyPut<JournalRepository>(() => JournalRepository(), fenix: true);
    Get.lazyPut<ReportRepository>(() => ReportRepository(), fenix: true);

    // Services
    Get.lazyPut<AccountingService>(() => AccountingService(), fenix: true);
    Get.lazyPut<BackupService>(() => BackupService(), fenix: true);
    Get.lazyPut<InventoryService>(() => InventoryService(productRepo: Get.find<ProductRepository>()), fenix: true);
    Get.lazyPut<SalesService>(() => SalesService(salesRepo: Get.find<SalesRepository>()), fenix: true);
    Get.lazyPut<PurchaseService>(() => PurchaseService(purchaseRepo: Get.find<PurchaseRepository>()), fenix: true);
    Get.lazyPut<ReceiptService>(() => ReceiptService(
      receiptRepo: Get.find<ReceiptRepository>(),
      customerRepo: Get.find<CustomerRepository>(),
      accountRepo: Get.find<AccountRepository>(),
      accountingService: Get.find<AccountingService>(),
    ), fenix: true);
    Get.lazyPut<PaymentService>(() => PaymentService(
      paymentRepo: Get.find<PaymentRepository>(),
      supplierRepo: Get.find<SupplierRepository>(),
      accountRepo: Get.find<AccountRepository>(),
      accountingService: Get.find<AccountingService>(),
    ), fenix: true);
    Get.lazyPut<ReportService>(() => ReportService(reportRepo: Get.find<ReportRepository>()), fenix: true);

    // Persistent global settings controller
    Get.put<SettingsController>(SettingsController(), permanent: true);
  }
}
