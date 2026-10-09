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

  // New/Edit Payment Form
  final editingPaymentId = Rxn<int>();
  bool get isEditing => editingPaymentId.value != null;
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
    editingPaymentId.value = null;
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

  Future<void> prepareEditPaymentForm(PaymentModel payment) async {
    await loadMetadata();
    final full = await _paymentService.getPaymentById(payment.id!) ?? payment;
    editingPaymentId.value = full.id;
    formNextPaymentNumber.value = full.paymentNumber;
    formPaymentDate.value = full.paymentDate;
    formSelectedSupplier.value = suppliers.firstWhereOrNull((s) => s.id == full.supplierId);
    formSelectedAccount.value = bankCashAccounts.firstWhereOrNull((a) => a.id == full.accountId);
    formAmount.value = full.amount;
    formPaymentMethod.value = full.paymentMethod;
    formReference.value = full.reference ?? '';
    formNotes.value = full.notes ?? '';
  }

  Future<bool> submitPayment() async {
    if (formSelectedSupplier.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a supplier', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
    if (formSelectedAccount.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select payment account (Cash/Bank)', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
    if (formAmount.value <= 0) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Amount must be greater than zero', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }

    try {
      isSubmitting.value = true;
      final payment = PaymentModel(
        id: editingPaymentId.value,
        paymentNumber: formNextPaymentNumber.value,
        paymentDate: formPaymentDate.value,
        supplierId: formSelectedSupplier.value!.id!,
        accountId: formSelectedAccount.value!.id!,
        amount: formAmount.value,
        paymentMethod: formPaymentMethod.value,
        reference: formReference.value,
        notes: formNotes.value,
      );

      if (editingPaymentId.value != null) {
        await _paymentService.updatePayment(payment);
        await loadPayments();
        editingPaymentId.value = null;
        if (Get.context != null) {
          Get.snackbar('Success', 'Payment updated successfully',
              snackPosition: SnackPosition.BOTTOM);
        }
        return true;
      } else {
        await _paymentService.createPayment(payment);
        await loadPayments();
        if (Get.context != null) {
          Get.snackbar('Success', 'Payment added successfully',
              snackPosition: SnackPosition.BOTTOM);
        }
        return true;
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save payment: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deletePayment(PaymentModel payment) async {
    try {
      await _paymentService.deletePayment(payment.id!);
      await loadPayments();
      if (Get.context != null) {
        Get.snackbar('Success', 'Payment deleted successfully', snackPosition: SnackPosition.BOTTOM);
      }
      return true;
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to delete payment: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
  }
}
