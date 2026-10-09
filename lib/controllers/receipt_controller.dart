import 'dart:async';
import 'package:get/get.dart';
import '../models/account_model.dart';
import '../models/customer_model.dart';
import '../models/receipt_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/customer_repository.dart';
import '../services/receipt_service.dart';

class ReceiptController extends GetxController {
  final ReceiptService _receiptService;
  final CustomerRepository _customerRepo;
  final AccountRepository _accountRepo;

  ReceiptController({
    ReceiptService? receiptService,
    CustomerRepository? customerRepo,
    AccountRepository? accountRepo,
  })  : _receiptService = receiptService ?? ReceiptService(),
        _customerRepo = customerRepo ?? CustomerRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  final receipts = <ReceiptModel>[].obs;
  final customers = <CustomerModel>[].obs;
  final bankCashAccounts = <AccountModel>[].obs;

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final searchQuery = ''.obs;
  final selectedCustomerId = 0.obs;

  // New/Edit Receipt Form
  final editingReceiptId = Rxn<int>();
  bool get isEditing => editingReceiptId.value != null;
  final formNextReceiptNumber = ''.obs;
  final formReceiptDate = DateTime.now().obs;
  final formSelectedCustomer = Rxn<CustomerModel>();
  final formSelectedAccount = Rxn<AccountModel>();
  final formAmount = 0.0.obs;
  final formPaymentMethod = 'Cash'.obs;
  final formReference = ''.obs;
  final formNotes = ''.obs;

  @override
  void onReady() {
    super.onReady();
    loadMetadata();
    loadReceipts();
  }

  Future<void> loadMetadata() async {
    try {
      final custs = await _customerRepo.getAllCustomers(activeOnly: true);
      final accounts = await _accountRepo.getAllAccounts(activeOnly: true);
      // Filter cash and bank accounts (Asset accounts)
      final cashBank = accounts.where((a) => a.accountCode == '1000' || a.accountCode == '1010' || a.isAsset).toList();
      customers.assignAll(custs);
      bankCashAccounts.assignAll(cashBank);
    } catch (_) {}
  }

  Future<void> loadReceipts() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _receiptService.getAllReceipts(
        customerId: selectedCustomerId.value > 0 ? selectedCustomerId.value : null,
        search: searchQuery.value,
      );
      receipts.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load receipts: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Timer? _searchDebounce;

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadReceipts();
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  void setCustomerFilter(int customerId) {
    selectedCustomerId.value = customerId;
    loadReceipts();
  }

  Future<void> prepareNewReceiptForm({CustomerModel? defaultCustomer}) async {
    await loadMetadata();
    editingReceiptId.value = null;
    formNextReceiptNumber.value = await _receiptService.getNextReceiptNumber();
    formReceiptDate.value = DateTime.now();
    formSelectedCustomer.value = defaultCustomer;
    formSelectedAccount.value = bankCashAccounts.isNotEmpty ? bankCashAccounts.first : null;
    formAmount.value = defaultCustomer != null && defaultCustomer.outstandingBalance > 0
        ? defaultCustomer.outstandingBalance
        : 0.0;
    formPaymentMethod.value = 'Cash';
    formReference.value = '';
    formNotes.value = '';
  }

  Future<void> prepareEditReceiptForm(ReceiptModel receipt) async {
    await loadMetadata();
    final full = await _receiptService.getReceiptById(receipt.id!) ?? receipt;
    editingReceiptId.value = full.id;
    formNextReceiptNumber.value = full.receiptNumber;
    formReceiptDate.value = full.receiptDate;
    formSelectedCustomer.value = customers.firstWhereOrNull((c) => c.id == full.customerId);
    formSelectedAccount.value = bankCashAccounts.firstWhereOrNull((a) => a.id == full.accountId);
    formAmount.value = full.amount;
    formPaymentMethod.value = full.paymentMethod;
    formReference.value = full.reference ?? '';
    formNotes.value = full.notes ?? '';
  }

  Future<bool> submitReceipt() async {
    if (formSelectedCustomer.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a customer', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
    if (formSelectedAccount.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select deposit account (Cash/Bank)', snackPosition: SnackPosition.BOTTOM);
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
      final receipt = ReceiptModel(
        id: editingReceiptId.value,
        receiptNumber: formNextReceiptNumber.value,
        receiptDate: formReceiptDate.value,
        customerId: formSelectedCustomer.value!.id!,
        accountId: formSelectedAccount.value!.id!,
        amount: formAmount.value,
        paymentMethod: formPaymentMethod.value,
        reference: formReference.value,
        notes: formNotes.value,
      );

      if (editingReceiptId.value != null) {
        await _receiptService.updateReceipt(receipt);
        await loadReceipts();
        editingReceiptId.value = null;
        if (Get.context != null) {
          Get.snackbar('Success', 'Receipt updated successfully',
              snackPosition: SnackPosition.BOTTOM);
        }
        return true;
      } else {
        await _receiptService.createReceipt(receipt);
        await loadReceipts();
        if (Get.context != null) {
          Get.snackbar('Success', 'Receipt created successfully',
              snackPosition: SnackPosition.BOTTOM);
        }
        return true;
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save receipt: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deleteReceipt(ReceiptModel receipt) async {
    try {
      await _receiptService.deleteReceipt(receipt.id!);
      await loadReceipts();
      if (Get.context != null) {
        Get.snackbar('Success', 'Receipt #${receipt.receiptNumber} deleted successfully', snackPosition: SnackPosition.BOTTOM);
      }
      return true;
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to delete receipt: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
  }
}
