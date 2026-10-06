import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/constants/accounting_constants.dart';
import '../core/utils/currency_utils.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/sales_invoice_model.dart';
import '../models/sales_order_item_model.dart';
import '../models/sales_order_model.dart';
import '../models/sales_return_item_model.dart';
import '../models/sales_return_model.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/sales_repository.dart';
import '../services/sales_order_service.dart';

class SalesOrderController extends GetxController {
  final SalesOrderService _service;
  final CustomerRepository _customerRepo;
  final ProductRepository _productRepo;
  final SalesRepository _salesRepo;

  SalesOrderController({
    SalesOrderService? service,
    CustomerRepository? customerRepo,
    ProductRepository? productRepo,
    SalesRepository? salesRepo,
  })  : _service = service ?? SalesOrderService(),
        _customerRepo = customerRepo ?? CustomerRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _salesRepo = salesRepo ?? SalesRepository();

  // Active Tab: 0 = Sales Orders, 1 = Sales Returns
  final activeTabIndex = 0.obs;

  // Metadata
  final customers = <CustomerModel>[].obs;
  final products = <ProductModel>[].obs;
  final recentInvoices = <SalesInvoiceModel>[].obs;

  // Lists
  final orders = <SalesOrderModel>[].obs;
  final returns = <SalesReturnModel>[].obs;

  // Loading & error
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  // Filters
  final searchQuery = ''.obs;
  final selectedStatus = 'All'.obs;
  final selectedCustomerId = 0.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  // Selected item for details dialog
  final selectedOrder = Rxn<SalesOrderModel>();
  final selectedReturn = Rxn<SalesReturnModel>();

  // ===================== SALES ORDER FORM =====================
  final formOrderNumber = ''.obs;
  final formOrderDate = DateTime.now().obs;
  final formExpectedDeliveryDate = Rxn<DateTime>();
  final formOrderCustomer = Rxn<CustomerModel>();
  final formOrderItems = <SalesOrderItemModel>[].obs;
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

  // ===================== SALES RETURN FORM =====================
  final formReturnNumber = ''.obs;
  final formReturnDate = DateTime.now().obs;
  final formReturnCustomer = Rxn<CustomerModel>();
  final formReferenceInvoice = Rxn<SalesInvoiceModel>();
  final formReturnItems = <SalesReturnItemModel>[].obs;
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
      final custs = await _customerRepo.getAllCustomers(activeOnly: true);
      final prods = await _productRepo.getAllProducts(activeOnly: true);
      final invs = await _salesRepo.getAllSalesInvoices();
      customers.assignAll(custs);
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
          customerId: selectedCustomerId.value > 0 ? selectedCustomerId.value : null,
          status: selectedStatus.value,
          search: searchQuery.value,
        );
        orders.assignAll(list);
      } else {
        final list = await _service.getAllReturns(
          fromDate: fromDate.value,
          toDate: toDate.value,
          customerId: selectedCustomerId.value > 0 ? selectedCustomerId.value : null,
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

  void setCustomerFilter(int custId) {
    selectedCustomerId.value = custId;
    loadData();
  }

  // ===================== SALES ORDER ACTIONS =====================

  Future<void> prepareNewOrderForm() async {
    try {
      formOrderNumber.value = await _service.getNextOrderNumber();
      formOrderDate.value = DateTime.now();
      formExpectedDeliveryDate.value = null;
      formOrderCustomer.value = null;
      formOrderItems.clear();
      formOrderDiscount.value = 0.0;
      formOrderStatus.value = AccountingConstants.statusPending;
      formOrderNotes.value = '';
    } catch (_) {}
  }

  void resetOrderForm() {
    formOrderDate.value = DateTime.now();
    formExpectedDeliveryDate.value = null;
    formOrderCustomer.value = null;
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
    final taxAmount = SalesOrderItemModel.calculateTax(qty, rate, discount, taxRate);
    final total = SalesOrderItemModel.calculateTotal(qty, rate, discount, taxRate);

    formOrderItems.add(SalesOrderItemModel(
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
      final taxAmount = SalesOrderItemModel.calculateTax(qty, rate, discount, existing.taxRate);
      final total = SalesOrderItemModel.calculateTotal(qty, rate, discount, existing.taxRate);
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

    if (formOrderCustomer.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a customer', snackPosition: SnackPosition.BOTTOM);
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

      final order = SalesOrderModel(
        orderNumber: formOrderNumber.value,
        orderDate: formOrderDate.value,
        expectedDeliveryDate: formExpectedDeliveryDate.value,
        customerId: formOrderCustomer.value!.id!,
        subtotal: formOrderSubtotal,
        discount: formOrderDiscount.value,
        taxAmount: formOrderTaxTotal,
        grandTotal: formOrderGrandTotal,
        status: formOrderStatus.value,
        notes: formOrderNotes.value,
      );

      final id = await _service.createSalesOrder(
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
          'Sales Order created successfully',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return true;
    } catch (e, stack) {
      debugPrint('Failed to save Sales Order: $e\n$stack');
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save order: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ===================== SALES RETURN ACTIONS =====================

  Future<void> prepareNewReturnForm() async {
    try {
      formReturnNumber.value = await _service.getNextReturnNumber();
      formReturnDate.value = DateTime.now();
      formReturnCustomer.value = null;
      formReferenceInvoice.value = null;
      formReturnItems.clear();
      formReturnDiscount.value = 0.0;
      formReturnReason.value = '';
    } catch (_) {}
  }

  void resetReturnForm() {
    formReturnDate.value = DateTime.now();
    formReturnCustomer.value = null;
    formReferenceInvoice.value = null;
    formReturnItems.clear();
    formReturnDiscount.value = 0.0;
    formReturnReason.value = '';
    _service.getNextReturnNumber().then((v) {
      formReturnNumber.value = v;
    }).catchError((_) {});
  }

  void onSelectReferenceInvoice(SalesInvoiceModel? inv) {
    formReferenceInvoice.value = inv;
    if (inv != null) {
      // Find customer
      final cust = customers.firstWhereOrNull((c) => c.id == inv.customerId);
      if (cust != null) {
        formReturnCustomer.value = cust;
      }
    }
  }

  void addReturnItem(ProductModel product, double qty, double rate, double discount) {
    final taxRate = product.taxRate;
    final taxAmount = SalesReturnItemModel.calculateTax(qty, rate, discount, taxRate);
    final total = SalesReturnItemModel.calculateTotal(qty, rate, discount, taxRate);

    formReturnItems.add(SalesReturnItemModel(
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
      final taxAmount = SalesReturnItemModel.calculateTax(qty, rate, discount, existing.taxRate);
      final total = SalesReturnItemModel.calculateTotal(qty, rate, discount, existing.taxRate);
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

    if (formReturnCustomer.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a customer', snackPosition: SnackPosition.BOTTOM);
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

      final ret = SalesReturnModel(
        returnNumber: formReturnNumber.value,
        returnDate: formReturnDate.value,
        customerId: formReturnCustomer.value!.id!,
        referenceInvoiceId: formReferenceInvoice.value?.id,
        referenceInvoiceNumber: formReferenceInvoice.value?.invoiceNumber,
        subtotal: formReturnSubtotal,
        discount: formReturnDiscount.value,
        taxAmount: formReturnTaxTotal,
        grandTotal: formReturnGrandTotal,
        reason: formReturnReason.value,
      );

      final id = await _service.createSalesReturn(
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
          'Sales Return created successfully',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return true;
    } catch (e, stack) {
      debugPrint('Failed to save Sales Return: $e\n$stack');
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save return: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
