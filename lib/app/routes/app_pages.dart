import 'package:get/get.dart';
import '../bindings/account_binding.dart';
import '../bindings/auth_binding.dart';
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
import '../bindings/sales_order_binding.dart';
import '../bindings/supplier_binding.dart';
import '../bindings/purchase_order_binding.dart';
import '../middleware/auth_middleware.dart';
import '../../screens/accounts/accounts_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/profile_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/customers/customers_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/journals/journals_screen.dart';
import '../../screens/payments/payments_screen.dart';
import '../../screens/products/products_screen.dart';
import '../../screens/purchases/purchases_create_screen.dart';
import '../../screens/purchases/purchases_screen.dart';
import '../../screens/purchases/purchase_orders_screen.dart';
import '../../screens/receipts/receipts_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/sales/sales_create_screen.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/sales/sales_orders_screen.dart';
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
    // Auth Routes
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      binding: AuthBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.signup,
      page: () => const SignUpScreen(),
      binding: AuthBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordScreen(),
      binding: AuthBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.resetPassword,
      page: () => const ResetPasswordScreen(),
      binding: AuthBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileScreen(),
      binding: AuthBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Protected Accounting Routes
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardScreen(),
      binding: DashboardBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.accounts,
      page: () => const AccountsScreen(),
      binding: AccountBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.customers,
      page: () => const CustomersScreen(),
      binding: CustomerBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.suppliers,
      page: () => const SuppliersScreen(),
      binding: SupplierBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.products,
      page: () => const ProductsScreen(),
      binding: ProductBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.sales,
      page: () => const SalesScreen(),
      binding: SalesBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.salesCreate,
      page: () => const SalesCreateScreen(),
      binding: SalesBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.salesOrders,
      page: () => const SalesOrdersScreen(),
      binding: SalesOrderBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.purchases,
      page: () => const PurchasesScreen(),
      binding: PurchaseBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.purchasesCreate,
      page: () => const PurchasesCreateScreen(),
      binding: PurchaseBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.purchaseOrders,
      page: () => const PurchaseOrdersScreen(),
      binding: PurchaseOrderBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.receipts,
      page: () => const ReceiptsScreen(),
      binding: ReceiptBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.payments,
      page: () => const PaymentsScreen(),
      binding: PaymentBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.expenses,
      page: () => const ExpensesScreen(),
      binding: ExpenseBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.journals,
      page: () => const JournalsScreen(),
      binding: JournalBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.reports,
      page: () => const ReportsScreen(),
      binding: ReportBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsScreen(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
