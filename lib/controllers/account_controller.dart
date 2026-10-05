import 'dart:async';
import 'package:get/get.dart';
import '../models/account_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/journal_repository.dart';

class AccountController extends GetxController {
  final AccountRepository _accountRepo;
  final JournalRepository _journalRepo;

  AccountController({
    AccountRepository? accountRepo,
    JournalRepository? journalRepo,
  })  : _accountRepo = accountRepo ?? AccountRepository(),
        _journalRepo = journalRepo ?? JournalRepository();

  final accounts = <AccountModel>[].obs;
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final searchQuery = ''.obs;
  final selectedTypeFilter = 'All'.obs;

  Timer? _searchDebounce;

  // Selected account for details / ledger
  final selectedAccount = Rxn<AccountModel>();
  final accountLedger = <Map<String, dynamic>>[].obs;
  final isLoadingLedger = false.obs;

  @override
  void onReady() {
    super.onReady();
    loadAccounts();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> loadAccounts() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _accountRepo.getAllAccounts(
        search: searchQuery.value,
        type: selectedTypeFilter.value,
        activeOnly: false,
      );
      accounts.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load accounts: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadAccounts();
    });
  }

  void setTypeFilter(String type) {
    selectedTypeFilter.value = type;
    loadAccounts();
  }

  Future<bool> saveAccount(AccountModel account) async {
    try {
      isSubmitting.value = true;
      if (account.id == null) {
        await _accountRepo.insertAccount(account);
      } else {
        await _accountRepo.updateAccount(account);
      }
      await loadAccounts();
      Get.snackbar('Success', 'Account saved successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to save account: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deactivateAccount(int id) async {
    try {
      final canDelete = await _accountRepo.canDeleteAccount(id);
      if (!canDelete) {
        Get.snackbar(
          'Notice',
          'Account has existing transactions. It will be marked inactive instead of permanently deleted.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      await _accountRepo.deactivateAccount(id);
      await loadAccounts();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Unable to deactivate account: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> loadAccountLedger(AccountModel account, {DateTime? fromDate, DateTime? toDate}) async {
    try {
      selectedAccount.value = account;
      isLoadingLedger.value = true;
      final lines = await _journalRepo.getGeneralLedgerLines(
        accountId: account.id!,
        fromDate: fromDate,
        toDate: toDate,
      );
      accountLedger.assignAll(lines);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load ledger: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoadingLedger.value = false;
    }
  }
}
