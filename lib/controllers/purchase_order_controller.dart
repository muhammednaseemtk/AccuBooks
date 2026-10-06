import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/constants/accounting_constants.dart';
import '../core/utils/currency_utils.dart';
import '../models/product_model.dart';
import '../models/purchase_invoice_model.dart';
import '../models/purchase_order_item_model.dart';
import '../models/purchase_order_model.dart';
import '../models/purchase_return_item_model.dart';
import '../models/purchase_return_model.dart';
import '../models/supplier_model.dart';
import '../repositories/product_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/supplier_repository.dart';
import '../services/purchase_order_service.dart';

class PurchaseOrderController extends GetxController {
  final PurchaseOrderService _service;
  final SupplierRepository _supplierRepo;
  final ProductRepository _productRepo;
  final PurchaseRepository _purchaseRepo;

  PurchaseOrderController({
    PurchaseOrderService? service,
    SupplierRepository? supplierRepo,
    ProductRepository? productRepo,
    PurchaseRepository? purchaseRepo,
  })  : _service = service ?? PurchaseOrderService(),
        _supplierRepo = supplierRepo ?? SupplierRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _purchaseRepo = purchaseRepo ?? PurchaseRepository();

  // Active Tab: 0 = Purchase Orders, 1 = Purchase Returns
  final activeTabIndex = 0.obs;

  // Metadata
  final suppliers = <SupplierModel>[].obs;
  final products = <ProductModel>[].obs;
  final recentInvoices = <PurchaseInvoiceModel>[].obs;

  // Lists
  final orders = <PurchaseOrderModel>[].obs;
  final returns = <PurchaseReturnModel>[].obs;

  // Loading & error
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  // Filters
  final searchQuery = ''.obs;
  final selectedStatus = 'All'.obs;
  final selectedSupplierId = 0.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  // Selected item for details dialog
  final selectedOrder = Rxn<PurchaseOrderModel>();
  final selectedReturn = Rxn<PurchaseReturnModel>();

  // ===================== PURCHASE ORDER FORM =====================
  final formOrderNumber = ''.obs;
  final formOrderDate = DateTime.now().obs;
  final formExpectedDeliveryDate = Rxn<DateTime>();
  final formOrderSupplier = Rxn<SupplierModel>();
  final formOrderItems = <PurchaseOrderItemModel>[].obs;
  final formOrderDiscount = 0.0.obs;
  final formOrderStatus = AccountingConstants.statusPending.obs;
  final formOrderNotes = ''.obs;

  double get formOrderSubtotal => CurrencyUtils.round(
        formOrderItems.fold(0.0, (sum, i) => sum + ((i.quantity * i.rate) - i.discount)),
      );
  double get formOrderTaxTotal => CurrencyUtils.round(
        formOrderItems.fold(0.0, (sum, i) => sum + i.taxAmount),
      );
  double get formOrderGrandTotal => CurrencyUtils.round(
        (formOrderSubtotal - formOrderDiscount.value) + formOrderTaxTotal,
      );

  // ===================== PURCHASE RETURN FORM =====================
  final formReturnNumber = ''.obs;
  final formReturnDate = DateTime.now().obs;
  final formReturnSupplier = Rxn<SupplierModel>();
  final formReferenceInvoice = Rxn<PurchaseInvoiceModel>();
  final formReturnItems = <PurchaseReturnItemModel>[].obs;
  final formReturnDiscount = 0.0.obs;
  final formReturnReason = ''.obs;

  double get formReturnSubtotal => CurrencyUtils.round(
        formReturnItems.fold(0.0, (sum, i) => sum + ((i.quantity * i.rate) - i.discount)),
      );
  double get formReturnTaxTotal => CurrencyUtils.round(
        formReturnItems.fold(0.0, (sum, i) => sum + i.taxAmount),
      );
  double get formReturnGrandTotal => CurrencyUtils.round(
        (formReturnSubtotal - formReturnDiscount.value) + formReturnTaxTotal,
      );

  Timer? _searchDebounce;

  @override
  void onReady() {
    super.onReady();
    loadMetadata();
    loadData();
    prepareNewOrderForm();
    prepareNewReturnForm();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> loadMetadata() async {
    try {
      final sups = await _supplierRepo.getAllSuppliers(activeOnly: true);
      final prods = await _productRepo.getAllProducts(activeOnly: true);
      final invs = await _purchaseRepo.getAllPurchaseInvoices();
      suppliers.assignAll(sups);
      products.assignAll(prods);
      recentInvoices.assignAll(invs);
    } catch (_) {}
  }

  Future<void> loadData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      if (activeTabIndex.value == 0) {
        final list = await _service.getAllOrders(
          fromDate: fromDate.value,
          toDate: toDate.value,
          supplierId: selectedSupplierId.value > 0 ? selectedSupplierId.value : null,
          status: selectedStatus.value,
          search: searchQuery.value,
        );
        orders.assignAll(list);
      } else {
        final list = await _service.getAllReturns(
          fromDate: fromDate.value,
          toDate: toDate.value,
          supplierId: selectedSupplierId.value > 0 ? selectedSupplierId.value : null,
          search: searchQuery.value,
        );
        returns.assignAll(list);
      }
    } catch (e) {
      errorMessage.value = 'Failed to load records: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void switchTab(int index) {
    if (activeTabIndex.value == index) return;
    activeTabIndex.value = index;
    loadData();
  }

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadData();
    });
  }

  void setStatusFilter(String status) {
    selectedStatus.value = status;
    loadData();
  }

  void setSupplierFilter(int supId) {
    selectedSupplierId.value = supId;
    loadData();
  }

  // ===================== PURCHASE ORDER ACTIONS =====================

  Future<void> prepareNewOrderForm() async {
    try {
      formOrderNumber.value = await _service.getNextOrderNumber();
      formOrderDate.value = DateTime.now();
      formExpectedDeliveryDate.value = null;
      formOrderSupplier.value = null;
      formOrderItems.clear();
      formOrderDiscount.value = 0.0;
      formOrderStatus.value = AccountingConstants.statusPending;
      formOrderNotes.value = '';
    } catch (_) {}
  }

  void resetOrderForm() {
    formOrderDate.value = DateTime.now();
    formExpectedDeliveryDate.value = null;
    formOrderSupplier.value = null;
    formOrderItems.clear();
    formOrderDiscount.value = 0.0;
    formOrderStatus.value = AccountingConstants.statusPending;
    formOrderNotes.value = '';
    _service.getNextOrderNumber().then((v) {
      formOrderNumber.value = v;
    }).catchError((_) {});
  }

  void addOrderItem(ProductModel product, double qty, double rate, double discount) {
    final taxRate = product.taxRate;
    final taxAmount = PurchaseOrderItemModel.calculateTax(qty, rate, discount, taxRate);
    final total = PurchaseOrderItemModel.calculateTotal(qty, rate, discount, taxRate);

    formOrderItems.add(PurchaseOrderItemModel(
      productId: product.id!,
      productName: product.name,
      productCode: product.productCode,
      unit: product.unit,
      quantity: qty,
      rate: rate,
      discount: discount,
      taxRate: taxRate,
      taxAmount: taxAmount,
      total: total,
    ));
  }

  void updateOrderItem(int index, double qty, double rate, double discount) {
    if (index >= 0 && index < formOrderItems.length) {
      final existing = formOrderItems[index];
      final taxAmount = PurchaseOrderItemModel.calculateTax(qty, rate, discount, existing.taxRate);
      final total = PurchaseOrderItemModel.calculateTotal(qty, rate, discount, existing.taxRate);
      formOrderItems[index] = existing.copyWith(
        quantity: qty,
        rate: rate,
        discount: discount,
        taxAmount: taxAmount,
        total: total,
      );
    }
  }

  void removeOrderItem(int index) {
    if (index >= 0 && index < formOrderItems.length) {
      formOrderItems.removeAt(index);
    }
  }

  Future<bool> submitOrder() async {
    if (isSubmitting.value) return false;

    if (formOrderSupplier.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a supplier', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }

    if (formOrderItems.isEmpty) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please add at least one product item', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }

    try {
      isSubmitting.value = true;

      if (formOrderNumber.value.trim().isEmpty) {
        formOrderNumber.value = await _service.getNextOrderNumber();
      }

      final order = PurchaseOrderModel(
        orderNumber: formOrderNumber.value,
        orderDate: formOrderDate.value,
        expectedDeliveryDate: formExpectedDeliveryDate.value,
        supplierId: formOrderSupplier.value!.id!,
        subtotal: formOrderSubtotal,
        discount: formOrderDiscount.value,
        taxAmount: formOrderTaxTotal,
        grandTotal: formOrderGrandTotal,
        status: formOrderStatus.value,
        notes: formOrderNotes.value,
      );

      final id = await _service.createPurchaseOrder(
        order: order,
        items: List.from(formOrderItems),
      );

      await loadData();
      final created = await _service.getOrderById(id);
      selectedOrder.value = created;

      resetOrderForm();

      if (Get.context != null) {
        Get.snackbar(
          'Success',
          'Purchase Order created successfully',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return true;
    } catch (e, stack) {
      debugPrint('Failed to save Purchase Order: $e\n$stack');
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save order: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ===================== PURCHASE RETURN ACTIONS =====================

  Future<void> prepareNewReturnForm() async {
    try {
      formReturnNumber.value = await _service.getNextReturnNumber();
      formReturnDate.value = DateTime.now();
      formReturnSupplier.value = null;
      formReferenceInvoice.value = null;
      formReturnItems.clear();
      formReturnDiscount.value = 0.0;
      formReturnReason.value = '';
    } catch (_) {}
  }

  void resetReturnForm() {
    formReturnDate.value = DateTime.now();
    formReturnSupplier.value = null;
    formReferenceInvoice.value = null;
    formReturnItems.clear();
    formReturnDiscount.value = 0.0;
    formReturnReason.value = '';
    _service.getNextReturnNumber().then((v) {
      formReturnNumber.value = v;
    }).catchError((_) {});
  }

  void onSelectReferenceInvoice(PurchaseInvoiceModel? inv) {
    formReferenceInvoice.value = inv;
    if (inv != null) {
      final sup = suppliers.firstWhereOrNull((s) => s.id == inv.supplierId);
      if (sup != null) {
        formReturnSupplier.value = sup;
      }
    }
  }

  void addReturnItem(ProductModel product, double qty, double rate, double discount) {
    final taxRate = product.taxRate;
    final taxAmount = PurchaseReturnItemModel.calculateTax(qty, rate, discount, taxRate);
    final total = PurchaseReturnItemModel.calculateTotal(qty, rate, discount, taxRate);

    formReturnItems.add(PurchaseReturnItemModel(
      productId: product.id!,
      productName: product.name,
      productCode: product.productCode,
      unit: product.unit,
      quantity: qty,
      rate: rate,
      discount: discount,
      taxRate: taxRate,
      taxAmount: taxAmount,
      total: total,
    ));
  }

  void updateReturnItem(int index, double qty, double rate, double discount) {
    if (index >= 0 && index < formReturnItems.length) {
      final existing = formReturnItems[index];
      final taxAmount = PurchaseReturnItemModel.calculateTax(qty, rate, discount, existing.taxRate);
      final total = PurchaseReturnItemModel.calculateTotal(qty, rate, discount, existing.taxRate);
      formReturnItems[index] = existing.copyWith(
        quantity: qty,
        rate: rate,
        discount: discount,
        taxAmount: taxAmount,
        total: total,
      );
    }
  }

  void removeReturnItem(int index) {
    if (index >= 0 && index < formReturnItems.length) {
      formReturnItems.removeAt(index);
    }
  }

  Future<bool> submitReturn() async {
    if (isSubmitting.value) return false;

    if (formReturnSupplier.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a supplier', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }

    if (formReturnItems.isEmpty) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please add at least one product item to return', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }

    try {
      isSubmitting.value = true;

      if (formReturnNumber.value.trim().isEmpty) {
        formReturnNumber.value = await _service.getNextReturnNumber();
      }

      final ret = PurchaseReturnModel(
        returnNumber: formReturnNumber.value,
        returnDate: formReturnDate.value,
        supplierId: formReturnSupplier.value!.id!,
        referenceInvoiceId: formReferenceInvoice.value?.id,
        referenceInvoiceNumber: formReferenceInvoice.value?.invoiceNumber,
        subtotal: formReturnSubtotal,
        discount: formReturnDiscount.value,
        taxAmount: formReturnTaxTotal,
        grandTotal: formReturnGrandTotal,
        reason: formReturnReason.value,
      );

      final id = await _service.createPurchaseReturn(
        returnModel: ret,
        items: List.from(formReturnItems),
      );

      await loadData();
      final created = await _service.getReturnById(id);
      selectedReturn.value = created;

      resetReturnForm();

      if (Get.context != null) {
        Get.snackbar(
          'Success',
          'Purchase Return created successfully',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return true;
    } catch (e, stack) {
      debugPrint('Failed to save Purchase Return: $e\n$stack');
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save return: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
