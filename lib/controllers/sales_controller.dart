import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/utils/currency_utils.dart';
import '../models/company_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/sales_invoice_item_model.dart';
import '../models/sales_invoice_model.dart';
import '../repositories/company_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../services/pdf_service.dart';
import '../services/sales_service.dart';

class SalesController extends GetxController {
  final SalesService _salesService;
  final CustomerRepository _customerRepo;
  final ProductRepository _productRepo;
  final CompanyRepository _companyRepo;

  SalesController({
    SalesService? salesService,
    CustomerRepository? customerRepo,
    ProductRepository? productRepo,
    CompanyRepository? companyRepo,
  })  : _salesService = salesService ?? SalesService(),
        _customerRepo = customerRepo ?? CustomerRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _companyRepo = companyRepo ?? CompanyRepository();

  final invoices = <SalesInvoiceModel>[].obs;
  final customers = <CustomerModel>[].obs;
  final products = <ProductModel>[].obs;
  final company = Rxn<CompanyModel>();

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  // Filters
  final searchQuery = ''.obs;
  final selectedStatus = 'All'.obs;
  final selectedCustomerId = 0.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  // Selected for viewing
  final selectedInvoice = Rxn<SalesInvoiceModel>();

  // Form State for creating/editing invoice
  final editingInvoiceId = Rxn<int>();
  bool get isEditing => editingInvoiceId.value != null;
  final formNextInvoiceNumber = ''.obs;
  final formInvoiceDate = DateTime.now().obs;
  final formSelectedCustomer = Rxn<CustomerModel>();
  final formItems = <SalesInvoiceItemModel>[].obs;
  final formDiscount = 0.0.obs;
  final formPaidAmount = 0.0.obs;
  final formNotes = ''.obs;

  // Form calculations
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
    loadInvoices();
    if (formNextInvoiceNumber.value.isEmpty) {
      prepareNewInvoiceForm();
    }
  }

  Future<void> loadMetadata() async {
    try {
      final custs = await _customerRepo.getAllCustomers(activeOnly: true);
      final prods = await _productRepo.getAllProducts(activeOnly: true);
      final comp = await _companyRepo.getCompany();
      customers.assignAll(custs);
      products.assignAll(prods);
      company.value = comp;
    } catch (_) {}
  }

  Future<void> loadInvoices() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _salesService.getAllInvoices(
        fromDate: fromDate.value,
        toDate: toDate.value,
        customerId: selectedCustomerId.value > 0 ? selectedCustomerId.value : null,
        paymentStatus: selectedStatus.value,
        search: searchQuery.value,
      );
      invoices.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load invoices: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Timer? _searchDebounce;

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadInvoices();
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  void setStatusFilter(String status) {
    selectedStatus.value = status;
    loadInvoices();
  }

  void setCustomerFilter(int customerId) {
    selectedCustomerId.value = customerId;
    loadInvoices();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    fromDate.value = from;
    toDate.value = to;
    loadInvoices();
  }

  Future<void> prepareNewInvoiceForm() async {
    await loadMetadata();
    editingInvoiceId.value = null;
    formNextInvoiceNumber.value = await _salesService.getNextInvoiceNumber();
    formInvoiceDate.value = DateTime.now();
    formSelectedCustomer.value = null;
    formItems.clear();
    formDiscount.value = 0.0;
    formPaidAmount.value = 0.0;
    formNotes.value = '';
  }

  Future<void> loadInvoiceForEdit(SalesInvoiceModel invoice) async {
    await loadMetadata();
    final fullInvoice = await _salesService.getInvoiceById(invoice.id!) ?? invoice;
    editingInvoiceId.value = fullInvoice.id;
    formNextInvoiceNumber.value = fullInvoice.invoiceNumber;
    formInvoiceDate.value = fullInvoice.invoiceDate;
    formSelectedCustomer.value = customers.firstWhereOrNull((c) => c.id == fullInvoice.customerId);
    formDiscount.value = fullInvoice.discount;
    formPaidAmount.value = fullInvoice.paidAmount;
    formNotes.value = fullInvoice.notes ?? '';
    formItems.assignAll(fullInvoice.items);
  }

  void resetForm() {
    editingInvoiceId.value = null;
    formSelectedCustomer.value = null;
    formItems.clear();
    formDiscount.value = 0.0;
    formPaidAmount.value = 0.0;
    formNotes.value = '';
    formInvoiceDate.value = DateTime.now();
    _salesService.getNextInvoiceNumber().then((val) {
      formNextInvoiceNumber.value = val;
    }).catchError((_) {});
  }

  void addFormItem(ProductModel product, double quantity, double rate, double discount) {
    final taxRate = product.taxRate;
    final taxAmount = SalesInvoiceItemModel.calculateTax(quantity, rate, discount, taxRate);
    final total = SalesInvoiceItemModel.calculateTotal(quantity, rate, discount, taxRate);

    formItems.add(SalesInvoiceItemModel(
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
      final taxAmount = SalesInvoiceItemModel.calculateTax(quantity, rate, discount, taxRate);
      final total = SalesInvoiceItemModel.calculateTotal(quantity, rate, discount, taxRate);

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

  Future<bool> submitInvoice({int? paymentAccountId}) async {
    if (isSubmitting.value) return false;

    if (formSelectedCustomer.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a customer', snackPosition: SnackPosition.BOTTOM);
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

      if (formNextInvoiceNumber.value.trim().isEmpty) {
        formNextInvoiceNumber.value = await _salesService.getNextInvoiceNumber();
      }

      final invoice = SalesInvoiceModel(
        id: editingInvoiceId.value,
        invoiceNumber: formNextInvoiceNumber.value,
        invoiceDate: formInvoiceDate.value,
        customerId: formSelectedCustomer.value!.id!,
        subtotal: formSubtotal,
        discount: formDiscount.value,
        taxAmount: formTaxTotal,
        grandTotal: formGrandTotal,
        paidAmount: formPaidAmount.value,
        balanceAmount: formBalanceAmount,
        notes: formNotes.value,
      );

      if (editingInvoiceId.value != null) {
        await _salesService.updateSalesInvoice(
          invoice: invoice,
          items: List.from(formItems),
          paymentAccountId: paymentAccountId,
        );

        await loadInvoices();
        final updated = await _salesService.getInvoiceById(editingInvoiceId.value!);
        selectedInvoice.value = updated;

        resetForm();

        if (Get.context != null) {
          Get.snackbar(
            'Success',
            'Sales Invoice updated successfully',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return true;
      } else {
        final id = await _salesService.createSalesInvoice(
          invoice: invoice,
          items: List.from(formItems),
          paymentAccountId: paymentAccountId,
        );

        await loadInvoices();
        final created = await _salesService.getInvoiceById(id);
        selectedInvoice.value = created;

        resetForm();

        if (Get.context != null) {
          Get.snackbar(
            'Success',
            'Sales Invoice added successfully',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return true;
      }
    } catch (e, stack) {
      debugPrint('Failed to save invoice: $e\n$stack');
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save invoice: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> cancelInvoice(int invoiceId, String reason) async {
    try {
      await _salesService.cancelSalesInvoice(invoiceId, reason: reason);
      await loadInvoices();
      if (selectedInvoice.value?.id == invoiceId) {
        selectedInvoice.value = await _salesService.getInvoiceById(invoiceId);
      }
      if (Get.context != null) {
        Get.snackbar('Success', 'Invoice cancelled successfully', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to cancel invoice: $e', snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  Future<bool> deleteInvoice(SalesInvoiceModel invoice) async {
    try {
      await _salesService.deleteSalesInvoice(invoice.id!);
      await loadInvoices();
      if (selectedInvoice.value?.id == invoice.id) {
        selectedInvoice.value = null;
      }
      if (Get.context != null) {
        Get.snackbar('Success', 'Sales Invoice deleted successfully', snackPosition: SnackPosition.BOTTOM);
      }
      return true;
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to delete invoice: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
  }

  Future<void> printCurrentInvoice(SalesInvoiceModel invoice) async {
    try {
      final comp = company.value ?? await _companyRepo.getCompany();
      if (comp == null) throw Exception('Company info missing');
      await PdfService.printInvoice(company: comp, invoice: invoice);
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Unable to print invoice: $e', snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  Future<void> shareCurrentInvoicePdf(SalesInvoiceModel invoice) async {
    try {
      final comp = company.value ?? await _companyRepo.getCompany();
      if (comp == null) throw Exception('Company info missing');
      await PdfService.shareInvoicePdf(company: comp, invoice: invoice);
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Unable to export PDF: $e', snackPosition: SnackPosition.BOTTOM);
      }
    }
  }
}
