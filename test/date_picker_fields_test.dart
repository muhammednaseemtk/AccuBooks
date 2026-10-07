import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/widgets/app_date_picker_field.dart';
import 'package:accubooks/controllers/receipt_controller.dart';
import 'package:accubooks/controllers/expense_controller.dart';
import 'package:accubooks/controllers/payment_controller.dart';
import 'package:accubooks/controllers/sales_controller.dart';
import 'package:accubooks/controllers/purchase_controller.dart';
import 'package:accubooks/controllers/sales_order_controller.dart';
import 'package:accubooks/controllers/purchase_order_controller.dart';
import 'package:accubooks/controllers/journal_controller.dart';
import 'package:accubooks/controllers/report_controller.dart';
import 'package:accubooks/models/customer_model.dart';
import 'package:accubooks/models/supplier_model.dart';
import 'package:accubooks/repositories/customer_repository.dart';
import 'package:accubooks/repositories/supplier_repository.dart';
import 'package:accubooks/repositories/account_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });

    DatabaseHelper.initializeFfi();
  });

  group('AppDatePickerField Unit & Widget Tests', () {
    testWidgets('Displays formatted date and responds to value changes', (tester) async {
      DateTime? selectedDate = DateTime(2026, 10, 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppDatePickerField(
                  label: 'Test Date',
                  value: selectedDate,
                  onDateSelected: (newDate) {
                    setState(() {
                      selectedDate = newDate;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify formatted date is rendered
      expect(find.text('05-10-2026'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);

      // Tap on the field to open date picker dialog
      await tester.tap(find.text('05-10-2026'));
      await tester.pumpAndSettle();

      // DatePicker should be open on screen
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Tap 'OK' button in the picker
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Picker is closed
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('Tapping suffix icon opens date picker', (tester) async {
      DateTime? selectedDate = DateTime(2026, 10, 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDatePickerField(
              label: 'Test Date',
              value: selectedDate,
              onDateSelected: (newDate) {
                selectedDate = newDate;
              },
            ),
          ),
        ),
      );

      // Tap the calendar icon
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      // DatePicker should be open on screen
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('Displays custom hint when value is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDatePickerField(
              label: 'Optional Date',
              hint: 'Select date (Optional)',
              value: null,
              onDateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Select date (Optional)'), findsOneWidget);
    });
  });

  group('Controller Date State & Persistence Tests', () {
    final customerRepo = CustomerRepository();
    final supplierRepo = SupplierRepository();
    final accountRepo = AccountRepository();

    test('ReceiptController: formReceiptDate selection and save persistence', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final custId = await customerRepo.insertCustomer(CustomerModel(
        customerCode: 'CUST-REC-$ts',
        name: 'Receipt Test Cust $ts',
        phone: '9988776655',
      ));
      final customer = (await customerRepo.getAllCustomers()).firstWhere((c) => c.id == custId);

      final accounts = await accountRepo.getAllAccounts();
      final cashAccount = accounts.firstWhere((a) => a.accountCode == '1000' || a.isAsset);

      final receiptCtrl = Get.put(ReceiptController());
      await receiptCtrl.prepareNewReceiptForm(defaultCustomer: customer);

      // Set custom chosen date
      final targetDate = DateTime(2026, 6, 18, 11, 30);
      final receiptNum = receiptCtrl.formNextReceiptNumber.value;
      receiptCtrl.formReceiptDate.value = targetDate;
      receiptCtrl.formSelectedCustomer.value = customer;
      receiptCtrl.formSelectedAccount.value = cashAccount;
      receiptCtrl.formAmount.value = 1500.0;
      receiptCtrl.formPaymentMethod.value = 'Cash';

      final saved = await receiptCtrl.submitReceipt();
      expect(saved, isTrue);

      final savedReceipt = receiptCtrl.receipts.firstWhere((r) => r.receiptNumber == receiptNum);
      expect(savedReceipt.receiptDate.year, equals(2026));
      expect(savedReceipt.receiptDate.month, equals(6));
      expect(savedReceipt.receiptDate.day, equals(18));
      Get.delete<ReceiptController>();
    });

    test('ExpenseController: formExpenseDate selection and save persistence', () async {
      final accounts = await accountRepo.getAllAccounts();
      final expenseAccount = accounts.firstWhere((a) => a.accountCode == '5001' || a.accountType == 'Expense');
      final paidFromAccount = accounts.firstWhere((a) => a.accountCode == '1000' || a.isAsset);

      final expenseCtrl = Get.put(ExpenseController());
      await expenseCtrl.prepareNewExpenseForm();

      final targetDate = DateTime(2026, 7, 22, 14, 15);
      final expenseNum = expenseCtrl.formNextExpenseNumber.value;
      expenseCtrl.formExpenseDate.value = targetDate;
      expenseCtrl.formSelectedExpenseAccount.value = expenseAccount;
      expenseCtrl.formSelectedPaymentAccount.value = paidFromAccount;
      expenseCtrl.formAmount.value = 450.0;
      expenseCtrl.formPaymentMethod.value = 'Cash';

      final saved = await expenseCtrl.submitExpense();
      expect(saved, isTrue);

      final savedExpense = expenseCtrl.expenses.firstWhere((e) => e.expenseNumber == expenseNum);
      expect(savedExpense.expenseDate.year, equals(2026));
      expect(savedExpense.expenseDate.month, equals(7));
      expect(savedExpense.expenseDate.day, equals(22));
      Get.delete<ExpenseController>();
    });

    test('PaymentController: formPaymentDate selection and save persistence', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final supId = await supplierRepo.insertSupplier(SupplierModel(
        supplierCode: 'SUP-PAY-$ts',
        name: 'Payment Test Sup $ts',
        phone: '8877665544',
      ));
      final supplier = (await supplierRepo.getAllSuppliers()).firstWhere((s) => s.id == supId);

      final accounts = await accountRepo.getAllAccounts();
      final paidFromAccount = accounts.firstWhere((a) => a.accountCode == '1000' || a.isAsset);

      final paymentCtrl = Get.put(PaymentController());
      await paymentCtrl.prepareNewPaymentForm(defaultSupplier: supplier);

      final targetDate = DateTime(2026, 8, 12, 9, 45);
      final paymentNum = paymentCtrl.formNextPaymentNumber.value;
      paymentCtrl.formPaymentDate.value = targetDate;
      paymentCtrl.formSelectedSupplier.value = supplier;
      paymentCtrl.formSelectedAccount.value = paidFromAccount;
      paymentCtrl.formAmount.value = 800.0;
      paymentCtrl.formPaymentMethod.value = 'Cash';

      final saved = await paymentCtrl.submitPayment();
      expect(saved, isTrue);

      final savedPayment = paymentCtrl.payments.firstWhere((p) => p.paymentNumber == paymentNum);
      expect(savedPayment.paymentDate.year, equals(2026));
      expect(savedPayment.paymentDate.month, equals(8));
      expect(savedPayment.paymentDate.day, equals(12));
      Get.delete<PaymentController>();
    });

    test('JournalController: formDate state updating', () {
      final journalCtrl = Get.put(JournalController());
      final newDate = DateTime(2026, 11, 25);
      journalCtrl.formDate.value = newDate;
      expect(journalCtrl.formDate.value, equals(newDate));
      Get.delete<JournalController>();
    });

    test('SalesController & PurchaseController: invoice and purchase dates', () {
      final salesCtrl = Get.put(SalesController());
      final salesDate = DateTime(2026, 5, 10);
      salesCtrl.formInvoiceDate.value = salesDate;
      expect(salesCtrl.formInvoiceDate.value, equals(salesDate));
      Get.delete<SalesController>();

      final purCtrl = Get.put(PurchaseController());
      final purDate = DateTime(2026, 5, 12);
      purCtrl.formPurchaseDate.value = purDate;
      expect(purCtrl.formPurchaseDate.value, equals(purDate));
      Get.delete<PurchaseController>();
    });

    test('SalesOrderController & PurchaseOrderController: order, delivery, return dates', () {
      final soCtrl = Get.put(SalesOrderController());
      final d1 = DateTime(2026, 9, 1);
      final d2 = DateTime(2026, 9, 8);
      final d3 = DateTime(2026, 9, 15);
      soCtrl.formOrderDate.value = d1;
      soCtrl.formExpectedDeliveryDate.value = d2;
      soCtrl.formReturnDate.value = d3;
      expect(soCtrl.formOrderDate.value, equals(d1));
      expect(soCtrl.formExpectedDeliveryDate.value, equals(d2));
      expect(soCtrl.formReturnDate.value, equals(d3));
      Get.delete<SalesOrderController>();

      final poCtrl = Get.put(PurchaseOrderController());
      poCtrl.formOrderDate.value = d1;
      poCtrl.formExpectedDeliveryDate.value = d2;
      poCtrl.formReturnDate.value = d3;
      expect(poCtrl.formOrderDate.value, equals(d1));
      expect(poCtrl.formExpectedDeliveryDate.value, equals(d2));
      expect(poCtrl.formReturnDate.value, equals(d3));
      Get.delete<PurchaseOrderController>();
    });

    test('ReportController: selectedDate state updating', () {
      final reportCtrl = Get.put(ReportController());
      final repDate = DateTime(2026, 12, 31);
      reportCtrl.selectedDate.value = repDate;
      expect(reportCtrl.selectedDate.value, equals(repDate));
      Get.delete<ReportController>();
    });
  });
}
