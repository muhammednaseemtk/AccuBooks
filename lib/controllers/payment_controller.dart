import 'dart:async';
import 'package:get/get.dart';
import '../models/account_model.dart';
import '../models/payment_model.dart';
import '../models/supplier_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/supplier_repository.dart';
import '../services/payment_service.dart';

class PaymentController extends GetxController {
  final PaymentService _paymentService;
  final SupplierRepository _supplierRepo;
  final AccountRepository _accountRepo;

  PaymentController({
    PaymentService? paymentService,
    SupplierRepository? supplierRepo,
    AccountRepository? accountRepo,
  })  : _paymentService = paymentService ?? PaymentService(),
        _supplierRepo = supplierRepo ?? SupplierRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  final payments = <PaymentModel>[].obs;
  final suppliers = <SupplierModel>[].obs;
  final bankCashAccounts = <AccountModel>[].obs;

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final searchQuery = ''.obs;
  final selectedSupplierId = 0.obs;

  // New Payment Form
  final formNextPaymentNumber = ''.obs;
  final formPaymentDate = DateTime.now().obs;
  final formSelectedSupplier = Rxn<SupplierModel>();
  final formSelectedAccount = Rxn<AccountModel>();
  final formAmount = 0.0.obs;
  final formPaymentMethod = 'Cash'.obs;
  final formReference = ''.obs;
  final formNotes = ''.obs;

  @override
  void onReady() {
    super.onReady();
    loadMetadata();
    loadPayments();
  }

  Future<void> loadMetadata() async {
    try {
      final sups = await _supplierRepo.getAllSuppliers(activeOnly: true);
      final accounts = await _accountRepo.getAllAccounts(activeOnly: true);
      final cashBank = accounts.where((a) => a.accountCode == '1000' || a.accountCode == '1010' || a.isAsset).toList();
      suppliers.assignAll(sups);
      bankCashAccounts.assignAll(cashBank);
    } catch (_) {}
  }

  Future<void> loadPayments() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _paymentService.getAllPayments(
        supplierId: selectedSupplierId.value > 0 ? selectedSupplierId.value : null,
        search: searchQuery.value,
      );
      payments.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load payments: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Timer? _searchDebounce;

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadPayments();
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  void setSupplierFilter(int supplierId) {
    selectedSupplierId.value = supplierId;
    loadPayments();
  }

  Future<void> prepareNewPaymentForm({SupplierModel? defaultSupplier}) async {
    await loadMetadata();
    formNextPaymentNumber.value = await _paymentService.getNextPaymentNumber();
    formPaymentDate.value = DateTime.now();
    formSelectedSupplier.value = defaultSupplier;
    formSelectedAccount.value = bankCashAccounts.isNotEmpty ? bankCashAccounts.first : null;
    formAmount.value = defaultSupplier != null && defaultSupplier.outstandingBalance > 0
        ? defaultSupplier.outstandingBalance
        : 0.0;
    formPaymentMethod.value = 'Cash';
    formReference.value = '';
    formNotes.value = '';
  }

  Future<bool> submitPayment() async {
    if (formSelectedSupplier.value == null) {
      Get.snackbar('Error', 'Please select a supplier', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (formSelectedAccount.value == null) {
      Get.snackbar('Error', 'Please select payment account (Cash/Bank)', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (formAmount.value <= 0) {
      Get.snackbar('Error', 'Amount must be greater than zero', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    try {
      isSubmitting.value = true;
      final payment = PaymentModel(
        paymentNumber: formNextPaymentNumber.value,
        paymentDate: formPaymentDate.value,
        supplierId: formSelectedSupplier.value!.id!,
        accountId: formSelectedAccount.value!.id!,
        amount: formAmount.value,
        paymentMethod: formPaymentMethod.value,
        reference: formReference.value,
        notes: formNotes.value,
      );

      await _paymentService.createPayment(payment);
      await loadPayments();
      Get.snackbar('Success', 'Payment #${payment.paymentNumber} recorded successfully',
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to save payment: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deletePayment(PaymentModel payment) async {
    try {
      await _paymentService.deletePayment(payment.id!);
      await loadPayments();
      Get.snackbar('Success', 'Payment #${payment.paymentNumber} deleted successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete payment: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }
}
