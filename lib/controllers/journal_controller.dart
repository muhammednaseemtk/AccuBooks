import 'dart:async';
import 'package:get/get.dart';
import '../core/constants/accounting_constants.dart';
import '../core/utils/currency_utils.dart';
import '../models/account_model.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/journal_repository.dart';
import '../services/accounting_service.dart';

class JournalDraftLine {
  AccountModel? account;
  double debit;
  double credit;
  String description;

  JournalDraftLine({
    this.account,
    this.debit = 0.0,
    this.credit = 0.0,
    this.description = '',
  });
}

class JournalController extends GetxController {
  final JournalRepository _journalRepo;
  final AccountRepository _accountRepo;
  final AccountingService _accountingService;

  JournalController({
    JournalRepository? journalRepo,
    AccountRepository? accountRepo,
    AccountingService? accountingService,
  })  : _journalRepo = journalRepo ?? JournalRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _accountingService = accountingService ?? AccountingService();

  final journalEntries = <JournalEntryModel>[].obs;
  final accounts = <AccountModel>[].obs;

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  // Filters
  final searchQuery = ''.obs;
  final selectedType = 'All'.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  // Selected for viewing
  final selectedEntry = Rxn<JournalEntryModel>();

  // Form State for creating manual journal entry
  final formNextNumber = ''.obs;
  final formDate = DateTime.now().obs;
  final formDescription = ''.obs;
  final formLines = <JournalDraftLine>[].obs;

  // Dynamic calculations
  double get formTotalDebit => CurrencyUtils.round(
        formLines.fold(0.0, (sum, line) => sum + line.debit),
      );

  double get formTotalCredit => CurrencyUtils.round(
        formLines.fold(0.0, (sum, line) => sum + line.credit),
      );

  double get formDifference => CurrencyUtils.round((formTotalDebit - formTotalCredit).abs());

  bool get isFormBalanced => formDifference <= 0.01 && formTotalDebit > 0;

  @override
  void onReady() {
    super.onReady();
    loadAccounts();
    loadJournalEntries();
  }

  Future<void> loadAccounts() async {
    try {
      final list = await _accountRepo.getAllAccounts(activeOnly: true);
      accounts.assignAll(list);
    } catch (_) {}
  }

  Future<void> loadJournalEntries() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _journalRepo.getAllJournalEntries(
        fromDate: fromDate.value,
        toDate: toDate.value,
        type: selectedType.value,
        search: searchQuery.value,
      );
      journalEntries.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load journal entries: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Timer? _searchDebounce;

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadJournalEntries();
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  void setTypeFilter(String type) {
    selectedType.value = type;
    loadJournalEntries();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    fromDate.value = from;
    toDate.value = to;
    loadJournalEntries();
  }

  Future<void> prepareNewJournalForm() async {
    await loadAccounts();
    formNextNumber.value = await _journalRepo.getNextJournalNumber();
    formDate.value = DateTime.now();
    formDescription.value = '';
    formLines.assignAll([
      JournalDraftLine(),
      JournalDraftLine(),
    ]);
  }

  void addLine() {
    formLines.add(JournalDraftLine());
  }

  void removeLine(int index) {
    if (formLines.length > 2) {
      formLines.removeAt(index);
    } else {
      Get.snackbar('Notice', 'A journal entry must have at least 2 lines', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool> submitJournalEntry() async {
    if (!isFormBalanced) {
      if (Get.context != null) {
        Get.snackbar(
          'Validation Error',
          'Journal entry must be balanced (Total Debit == Total Credit). Difference: $formDifference',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return false;
    }

    for (final line in formLines) {
      if (line.account == null) {
        if (Get.context != null) {
          Get.snackbar('Error', 'Please select an account for all lines', snackPosition: SnackPosition.BOTTOM);
        }
        return false;
      }
      if (line.debit == 0 && line.credit == 0) {
        if (Get.context != null) {
          Get.snackbar('Error', 'Each line must have either a debit or credit amount', snackPosition: SnackPosition.BOTTOM);
        }
        return false;
      }
      if (line.debit > 0 && line.credit > 0) {
        if (Get.context != null) {
          Get.snackbar('Error', 'A single line cannot have both debit and credit amounts', snackPosition: SnackPosition.BOTTOM);
        }
        return false;
      }
    }

    try {
      isSubmitting.value = true;
      final linesToPost = formLines.map((draft) {
        return JournalLineModel(
          accountId: draft.account!.id!,
          debit: CurrencyUtils.round(draft.debit),
          credit: CurrencyUtils.round(draft.credit),
          description: draft.description.isNotEmpty ? draft.description : formDescription.value,
        );
      }).toList();

      await _accountingService.postManualJournal(
        date: formDate.value,
        description: formDescription.value,
        lines: linesToPost,
      );

      await loadJournalEntries();
      if (Get.context != null) {
        Get.snackbar('Success', 'Journal created successfully', snackPosition: SnackPosition.BOTTOM);
      }
      return true;
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to post journal entry: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deleteJournal(JournalEntryModel entry) async {
    try {
      if (entry.referenceId != null && entry.transactionType != AccountingConstants.transTypeJournal) {
        Get.snackbar(
          'Protected Entry',
          'This journal was automatically created by ${entry.transactionType}. Please delete or cancel the original ${entry.transactionType} instead.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      await _journalRepo.deleteJournalEntry(entry.id!);
      await loadJournalEntries();
      Get.snackbar('Success', 'Journal entry #${entry.transactionNumber} deleted successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete journal entry: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }
}
