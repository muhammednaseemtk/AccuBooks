import 'dart:async';
import 'package:get/get.dart';
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

  // Form State for creating invoice
  final formNextInvoiceNumber = ''.obs;
  final formInvoiceDate = DateTime.now().obs;
  final formSelectedCustomer = Rxn<CustomerModel>();
  final formItems = <SalesInvoiceItemModel>[].obs;
  final formDiscount = 0.0.obs;
  final formPaidAmount = 0.0.obs;
  final formNotes = ''.obs;

  // Form calculations
  double get formSubtotal => formItems.fold(0.0, (sum, i) => sum + ((i.quantity * i.rate) - i.discount));
  double get formTaxTotal => formItems.fold(0.0, (sum, i) => sum + i.taxAmount);
  double get formGrandTotal => (formSubtotal - formDiscount.value) + formTaxTotal;
  double get formBalanceAmount => formGrandTotal - formPaidAmount.value;

  @override
  void onReady() {
    super.onReady();
    loadMetadata();
    loadInvoices();
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
    formNextInvoiceNumber.value = await _salesService.getNextInvoiceNumber();
    formInvoiceDate.value = DateTime.now();
    formSelectedCustomer.value = null;
    formItems.clear();
    formDiscount.value = 0.0;
    formPaidAmount.value = 0.0;
    formNotes.value = '';
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

  void removeFormItem(int index) {
    if (index >= 0 && index < formItems.length) {
      formItems.removeAt(index);
    }
  }

  Future<bool> submitInvoice({int? paymentAccountId}) async {
    if (formSelectedCustomer.value == null) {
      Get.snackbar('Error', 'Please select a customer', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (formItems.isEmpty) {
      Get.snackbar('Error', 'Please add at least one product item', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    try {
      isSubmitting.value = true;
      final invoice = SalesInvoiceModel(
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

      final id = await _salesService.createSalesInvoice(
        invoice: invoice,
        items: formItems,
        paymentAccountId: paymentAccountId,
      );

      await loadInvoices();
      final created = await _salesService.getInvoiceById(id);
      selectedInvoice.value = created;

      Get.snackbar('Success', 'Invoice #${invoice.invoiceNumber} saved successfully!',
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to save invoice: $e', snackPosition: SnackPosition.BOTTOM);
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
      Get.snackbar('Success', 'Invoice cancelled and inventory restored', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel invoice: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool> deleteInvoice(SalesInvoiceModel invoice) async {
    try {
      await _salesService.deleteSalesInvoice(invoice.id!);
      await loadInvoices();
      if (selectedInvoice.value?.id == invoice.id) {
        selectedInvoice.value = null;
      }
      Get.snackbar('Success', 'Invoice #${invoice.invoiceNumber} deleted successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete invoice: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> printCurrentInvoice(SalesInvoiceModel invoice) async {
    try {
      final comp = company.value ?? await _companyRepo.getCompany();
      if (comp == null) throw Exception('Company info missing');
      await PdfService.printInvoice(company: comp, invoice: invoice);
    } catch (e) {
      Get.snackbar('Error', 'Unable to print invoice: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> shareCurrentInvoicePdf(SalesInvoiceModel invoice) async {
    try {
      final comp = company.value ?? await _companyRepo.getCompany();
      if (comp == null) throw Exception('Company info missing');
      await PdfService.shareInvoicePdf(company: comp, invoice: invoice);
    } catch (e) {
      Get.snackbar('Error', 'Unable to export PDF: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
