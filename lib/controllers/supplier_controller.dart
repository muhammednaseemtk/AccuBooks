import 'dart:async';
import 'package:get/get.dart';
import '../models/supplier_model.dart';
import '../repositories/supplier_repository.dart';

class SupplierController extends GetxController {
  final SupplierRepository _supplierRepo;

  SupplierController({SupplierRepository? supplierRepo})
      : _supplierRepo = supplierRepo ?? SupplierRepository();

  final suppliers = <SupplierModel>[].obs;
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;
  final searchQuery = ''.obs;

  Timer? _searchDebounce;

  // Selected supplier for details / ledger
  final selectedSupplier = Rxn<SupplierModel>();
  final supplierLedger = <Map<String, dynamic>>[].obs;
  final isLoadingLedger = false.obs;

  @override
  void onReady() {
    super.onReady();
    loadSuppliers();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> loadSuppliers() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _supplierRepo.getAllSuppliers(
        search: searchQuery.value,
        activeOnly: false,
      );
      suppliers.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load suppliers: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadSuppliers();
    });
  }

  Future<bool> saveSupplier(SupplierModel supplier) async {
    try {
      isSubmitting.value = true;
      if (supplier.id == null) {
        await _supplierRepo.insertSupplier(supplier);
        await loadSuppliers();
        if (Get.context != null) {
          Get.snackbar('Success', 'Supplier created successfully', snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        await _supplierRepo.updateSupplier(supplier);
        await loadSuppliers();
        if (Get.context != null) {
          Get.snackbar('Success', 'Supplier updated successfully', snackPosition: SnackPosition.BOTTOM);
        }
      }
      return true;
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save supplier: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deleteSupplier(SupplierModel supplier) async {
    try {
      final canDelete = await _supplierRepo.canDeleteSupplier(supplier.id!);
      if (!canDelete) {
        Get.snackbar(
          'Cannot Delete',
          'Supplier "${supplier.name}" has active invoices, payments, or purchase returns. Please delete or cancel those records first.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      await _supplierRepo.deleteSupplier(supplier.id!);
      await loadSuppliers();
      Get.snackbar('Success', 'Supplier "${supplier.name}" deleted successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Unable to delete supplier: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> deactivateSupplier(int id) async {
    try {
      await _supplierRepo.deactivateSupplier(id);
      await loadSuppliers();
      Get.snackbar('Success', 'Supplier deactivated', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to deactivate supplier: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> loadSupplierDetails(int supplierId) async {
    try {
      isLoadingLedger.value = true;
      final sup = await _supplierRepo.getSupplierById(supplierId);
      selectedSupplier.value = sup;
      final ledger = await _supplierRepo.getSupplierLedgerEntries(supplierId);
      supplierLedger.assignAll(ledger);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load supplier details: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoadingLedger.value = false;
    }
  }
}
