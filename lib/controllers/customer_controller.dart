import 'dart:async';
import 'package:get/get.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

class CustomerController extends GetxController {
  final CustomerRepository _customerRepo;

  CustomerController({CustomerRepository? customerRepo})
      : _customerRepo = customerRepo ?? CustomerRepository();

  final customers = <CustomerModel>[].obs;
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;
  final searchQuery = ''.obs;

  Timer? _searchDebounce;

  // Selected customer for details / ledger
  final selectedCustomer = Rxn<CustomerModel>();
  final customerLedger = <Map<String, dynamic>>[].obs;
  final isLoadingLedger = false.obs;

  @override
  void onReady() {
    super.onReady();
    loadCustomers();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> loadCustomers() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _customerRepo.getAllCustomers(
        search: searchQuery.value,
        activeOnly: false,
      );
      customers.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load customers: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadCustomers();
    });
  }

  Future<bool> saveCustomer(CustomerModel customer) async {
    try {
      isSubmitting.value = true;
      if (customer.id == null) {
        await _customerRepo.insertCustomer(customer);
      } else {
        await _customerRepo.updateCustomer(customer);
      }
      await loadCustomers();
      Get.snackbar('Success', 'Customer details saved', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to save customer: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deactivateCustomer(int id) async {
    try {
      await _customerRepo.deactivateCustomer(id);
      await loadCustomers();
      Get.snackbar('Success', 'Customer deactivated', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to deactivate customer: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> loadCustomerDetails(int customerId) async {
    try {
      isLoadingLedger.value = true;
      final cust = await _customerRepo.getCustomerById(customerId);
      selectedCustomer.value = cust;
      final ledger = await _customerRepo.getCustomerLedgerEntries(customerId);
      customerLedger.assignAll(ledger);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load customer details: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoadingLedger.value = false;
    }
  }
}
