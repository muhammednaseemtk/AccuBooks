import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/utils/currency_utils.dart';
import '../models/product_model.dart';
import '../models/purchase_invoice_item_model.dart';
import '../models/purchase_invoice_model.dart';
import '../models/supplier_model.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repository.dart';
import '../services/purchase_service.dart';

class PurchaseController extends GetxController {
  final PurchaseService _purchaseService;
  final SupplierRepository _supplierRepo;
  final ProductRepository _productRepo;

  PurchaseController({
    PurchaseService? purchaseService,
    SupplierRepository? supplierRepo,
    ProductRepository? productRepo,
  })  : _purchaseService = purchaseService ?? PurchaseService(),
        _supplierRepo = supplierRepo ?? SupplierRepository(),
        _productRepo = productRepo ?? ProductRepository();

  final purchases = <PurchaseInvoiceModel>[].obs;
  final suppliers = <SupplierModel>[].obs;
  final products = <ProductModel>[].obs;

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  // Filters
  final searchQuery = ''.obs;
  final selectedStatus = 'All'.obs;
  final selectedSupplierId = 0.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  // Selected for viewing
  final selectedPurchase = Rxn<PurchaseInvoiceModel>();

  // Editing state
  final editingPurchaseId = Rxn<int>();
  bool get isEditing => editingPurchaseId.value != null;

  // Form State
  final formNextPurchaseNumber = ''.obs;
  final formPurchaseDate = DateTime.now().obs;
  final formSelectedSupplier = Rxn<SupplierModel>();
  final formItems = <PurchaseInvoiceItemModel>[].obs;
  final formDiscount = 0.0.obs;
  final formPaidAmount = 0.0.obs;
  final formNotes = ''.obs;

  double get formSubtotal => CurrencyUtils.round(
        formItems.fold(0.0, (sum, i) => sum + ((i.quantity * i.rate) - i.discount)),
      );
  double get formTaxTotal => CurrencyUtils.round(
        formItems.fold(0.0, (sum, i) => sum + i.taxAmount),
      );
  double get formGrandTotal => CurrencyUtils.round(
        (formSubtotal - formDiscount.value) + formTaxTotal,
      );
  double get formBalanceAmount => CurrencyUtils.round(
        formGrandTotal - formPaidAmount.value,
      );

  @override
  void onReady() {
    super.onReady();
    loadMetadata();
    loadPurchases();
    if (formNextPurchaseNumber.value.isEmpty) {
      prepareNewPurchaseForm();
    }
  }

  Future<void> loadMetadata() async {
    try {
      final sups = await _supplierRepo.getAllSuppliers(activeOnly: true);
      final prods = await _productRepo.getAllProducts(activeOnly: true);
      suppliers.assignAll(sups);
      products.assignAll(prods);
    } catch (_) {}
  }

  Future<void> loadPurchases() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _purchaseService.getAllPurchases(
        fromDate: fromDate.value,
        toDate: toDate.value,
        supplierId: selectedSupplierId.value > 0 ? selectedSupplierId.value : null,
        paymentStatus: selectedStatus.value,
        search: searchQuery.value,
      );
      purchases.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load purchases: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Timer? _searchDebounce;

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadPurchases();
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  void setStatusFilter(String status) {
    selectedStatus.value = status;
    loadPurchases();
  }

  void setSupplierFilter(int supplierId) {
    selectedSupplierId.value = supplierId;
    loadPurchases();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    fromDate.value = from;
    toDate.value = to;
    loadPurchases();
  }

  Future<void> prepareNewPurchaseForm() async {
    await loadMetadata();
    editingPurchaseId.value = null;
    formNextPurchaseNumber.value = await _purchaseService.getNextPurchaseNumber();
    formPurchaseDate.value = DateTime.now();
    formSelectedSupplier.value = null;
    formItems.clear();
    formDiscount.value = 0.0;
    formPaidAmount.value = 0.0;
    formNotes.value = '';
  }

  Future<void> loadPurchaseForEdit(PurchaseInvoiceModel invoice) async {
    await loadMetadata();
    final full = await _purchaseService.getPurchaseById(invoice.id!) ?? invoice;
    editingPurchaseId.value = full.id;
    formNextPurchaseNumber.value = full.invoiceNumber;
    formPurchaseDate.value = full.invoiceDate;
    formSelectedSupplier.value = suppliers.firstWhereOrNull((s) => s.id == full.supplierId);
    formDiscount.value = full.discount;
    formPaidAmount.value = full.paidAmount;
    formNotes.value = full.notes ?? '';
    formItems.assignAll(full.items);
  }

  void resetForm() {
    editingPurchaseId.value = null;
    formSelectedSupplier.value = null;
    formItems.clear();
    formDiscount.value = 0.0;
    formPaidAmount.value = 0.0;
    formNotes.value = '';
    formPurchaseDate.value = DateTime.now();
    _purchaseService.getNextPurchaseNumber().then((val) {
      formNextPurchaseNumber.value = val;
    }).catchError((_) {});
  }

  void addFormItem(ProductModel product, double quantity, double rate, double discount) {
    final taxRate = product.taxRate;
    final taxAmount = PurchaseInvoiceItemModel.calculateTax(quantity, rate, discount, taxRate);
    final total = PurchaseInvoiceItemModel.calculateTotal(quantity, rate, discount, taxRate);

    formItems.add(PurchaseInvoiceItemModel(
      productId: product.id!,
      productName: product.name,
      productCode: product.productCode,
      unit: product.unit,
      quantity: quantity,
      rate: rate,
      discount: discount,
      taxRate: taxRate,
      taxAmount: taxAmount,
      total: total,
    ));
  }

  void updateFormItem(int index, ProductModel product, double quantity, double rate, double discount) {
    if (index >= 0 && index < formItems.length) {
      final taxRate = product.taxRate;
      final taxAmount = PurchaseInvoiceItemModel.calculateTax(quantity, rate, discount, taxRate);
      final total = PurchaseInvoiceItemModel.calculateTotal(quantity, rate, discount, taxRate);

      formItems[index] = formItems[index].copyWith(
        productId: product.id!,
        productName: product.name,
        productCode: product.productCode,
        unit: product.unit,
        quantity: quantity,
        rate: rate,
        discount: discount,
        taxRate: taxRate,
        taxAmount: taxAmount,
        total: total,
      );
    }
  }

  void removeFormItem(int index) {
    if (index >= 0 && index < formItems.length) {
      formItems.removeAt(index);
    }
  }

  Future<bool> submitPurchase({int? paymentAccountId}) async {
    if (isSubmitting.value) return false;

    if (formSelectedSupplier.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a supplier', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
    if (formItems.isEmpty) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please add at least one product item', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }

    try {
      isSubmitting.value = true;

      if (formNextPurchaseNumber.value.trim().isEmpty) {
        formNextPurchaseNumber.value = await _purchaseService.getNextPurchaseNumber();
      }

      final invoice = PurchaseInvoiceModel(
        id: editingPurchaseId.value,
        invoiceNumber: formNextPurchaseNumber.value,
        invoiceDate: formPurchaseDate.value,
        supplierId: formSelectedSupplier.value!.id!,
        subtotal: formSubtotal,
        discount: formDiscount.value,
        taxAmount: formTaxTotal,
        grandTotal: formGrandTotal,
        paidAmount: formPaidAmount.value,
        balanceAmount: formBalanceAmount,
        notes: formNotes.value,
      );

      if (editingPurchaseId.value != null) {
        await _purchaseService.updatePurchaseInvoice(
          invoice: invoice,
          items: List.from(formItems),
          paymentAccountId: paymentAccountId,
        );

        await loadPurchases();
        final updated = await _purchaseService.getPurchaseById(editingPurchaseId.value!);
        selectedPurchase.value = updated;

        resetForm();

        if (Get.context != null) {
          Get.snackbar('Success', 'Purchase Invoice updated successfully',
              snackPosition: SnackPosition.BOTTOM);
        }
        return true;
      } else {
        final id = await _purchaseService.createPurchaseInvoice(
          invoice: invoice,
          items: List.from(formItems),
          paymentAccountId: paymentAccountId,
        );

        await loadPurchases();
        final created = await _purchaseService.getPurchaseById(id);
        selectedPurchase.value = created;

        resetForm();

        if (Get.context != null) {
          Get.snackbar('Success', 'Purchase Invoice added successfully',
              snackPosition: SnackPosition.BOTTOM);
        }
        return true;
      }
    } catch (e, stack) {
      debugPrint('[PurchaseController] submitPurchase error: $e\n$stack');
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save purchase: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> cancelPurchase(int invoiceId, String reason) async {
    try {
      await _purchaseService.cancelPurchaseInvoice(invoiceId, reason: reason);
      await loadPurchases();
      if (selectedPurchase.value?.id == invoiceId) {
        selectedPurchase.value = await _purchaseService.getPurchaseById(invoiceId);
      }
      if (Get.context != null) {
        Get.snackbar('Success', 'Invoice cancelled successfully', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to cancel purchase: $e', snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  Future<bool> deletePurchase(PurchaseInvoiceModel invoice) async {
    try {
      await _purchaseService.deletePurchaseInvoice(invoice.id!);
      await loadPurchases();
      if (selectedPurchase.value?.id == invoice.id) {
        selectedPurchase.value = null;
      }
      if (Get.context != null) {
        Get.snackbar('Success', 'Purchase Invoice deleted successfully', snackPosition: SnackPosition.BOTTOM);
      }
      return true;
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to delete purchase invoice: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
  }
}
