import 'package:get/get.dart';
import '../bindings/account_binding.dart';
import '../bindings/customer_binding.dart';
import '../bindings/dashboard_binding.dart';
import '../bindings/expense_binding.dart';
import '../bindings/journal_binding.dart';
import '../bindings/payment_binding.dart';
import '../bindings/product_binding.dart';
import '../bindings/purchase_binding.dart';
import '../bindings/receipt_binding.dart';
import '../bindings/report_binding.dart';
import '../bindings/sales_binding.dart';
import '../bindings/supplier_binding.dart';
import '../../screens/accounts/accounts_screen.dart';
import '../../screens/customers/customers_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/journals/journals_screen.dart';
import '../../screens/payments/payments_screen.dart';
import '../../screens/products/products_screen.dart';
import '../../screens/purchases/purchases_create_screen.dart';
import '../../screens/purchases/purchases_screen.dart';
import '../../screens/receipts/receipts_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/sales/sales_create_screen.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/suppliers/suppliers_screen.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = AppRoutes.splash;

  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardScreen(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.accounts,
      page: () => const AccountsScreen(),
      binding: AccountBinding(),
    ),
    GetPage(
      name: AppRoutes.customers,
      page: () => const CustomersScreen(),
      binding: CustomerBinding(),
    ),
    GetPage(
      name: AppRoutes.suppliers,
      page: () => const SuppliersScreen(),
      binding: SupplierBinding(),
    ),
    GetPage(
      name: AppRoutes.products,
      page: () => const ProductsScreen(),
      binding: ProductBinding(),
    ),
    GetPage(
      name: AppRoutes.sales,
      page: () => const SalesScreen(),
      binding: SalesBinding(),
    ),
    GetPage(
      name: AppRoutes.salesCreate,
      page: () => const SalesCreateScreen(),
      binding: SalesBinding(),
    ),
    GetPage(
      name: AppRoutes.purchases,
      page: () => const PurchasesScreen(),
      binding: PurchaseBinding(),
    ),
    GetPage(
      name: AppRoutes.purchasesCreate,
      page: () => const PurchasesCreateScreen(),
      binding: PurchaseBinding(),
    ),
    GetPage(
      name: AppRoutes.receipts,
      page: () => const ReceiptsScreen(),
      binding: ReceiptBinding(),
    ),
    GetPage(
      name: AppRoutes.payments,
      page: () => const PaymentsScreen(),
      binding: PaymentBinding(),
    ),
    GetPage(
      name: AppRoutes.expenses,
      page: () => const ExpensesScreen(),
      binding: ExpenseBinding(),
    ),
    GetPage(
      name: AppRoutes.journals,
      page: () => const JournalsScreen(),
      binding: JournalBinding(),
    ),
    GetPage(
      name: AppRoutes.reports,
      page: () => const ReportsScreen(),
      binding: ReportBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsScreen(),
    ),
  ];
}
