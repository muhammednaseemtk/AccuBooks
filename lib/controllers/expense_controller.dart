import 'dart:async';
import 'package:get/get.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../models/account_model.dart';
import '../models/expense_model.dart';
import '../models/journal_line_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/expense_repository.dart';
import '../services/accounting_service.dart';

class ExpenseController extends GetxController {
  final ExpenseRepository _expenseRepo;
  final AccountRepository _accountRepo;
  final AccountingService _accountingService;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  ExpenseController({
    ExpenseRepository? expenseRepo,
    AccountRepository? accountRepo,
    AccountingService? accountingService,
  })  : _expenseRepo = expenseRepo ?? ExpenseRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _accountingService = accountingService ?? AccountingService();

  final expenses = <ExpenseModel>[].obs;
  final expenseAccounts = <AccountModel>[].obs;
  final paymentAccounts = <AccountModel>[].obs;

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final searchQuery = ''.obs;
  final selectedAccountId = 0.obs;

  // New/Edit Expense Form
  final editingExpenseId = Rxn<int>();
  bool get isEditing => editingExpenseId.value != null;
  final formNextExpenseNumber = ''.obs;
  final formExpenseDate = DateTime.now().obs;
  final formSelectedExpenseAccount = Rxn<AccountModel>();
  final formSelectedPaymentAccount = Rxn<AccountModel>();
  final formAmount = 0.0.obs;
  final formTaxAmount = 0.0.obs;
  final formPaymentMethod = 'Cash'.obs;
  final formDescription = ''.obs;
  final formReference = ''.obs;

  @override
  void onReady() {
    super.onReady();
    loadMetadata();
    loadExpenses();
  }

  Future<void> loadMetadata() async {
    try {
      final accounts = await _accountRepo.getAllAccounts(activeOnly: true);
      final exp = accounts.where((a) => a.accountType == AccountingConstants.typeExpense).toList();
      final pay = accounts.where((a) => a.accountCode == '1000' || a.accountCode == '1010' || a.isAsset).toList();
      expenseAccounts.assignAll(exp);
      paymentAccounts.assignAll(pay);
    } catch (_) {}
  }

  Future<void> loadExpenses() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _expenseRepo.getAllExpenses(
        accountId: selectedAccountId.value > 0 ? selectedAccountId.value : null,
        search: searchQuery.value,
      );
      expenses.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load expenses: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Timer? _searchDebounce;

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadExpenses();
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  void setAccountFilter(int accountId) {
    selectedAccountId.value = accountId;
    loadExpenses();
  }

  Future<void> prepareNewExpenseForm() async {
    await loadMetadata();
    editingExpenseId.value = null;
    formNextExpenseNumber.value = await _expenseRepo.getNextExpenseNumber();
    formExpenseDate.value = DateTime.now();
    formSelectedExpenseAccount.value = expenseAccounts.isNotEmpty ? expenseAccounts.first : null;
    formSelectedPaymentAccount.value = paymentAccounts.isNotEmpty ? paymentAccounts.first : null;
    formAmount.value = 0.0;
    formTaxAmount.value = 0.0;
    formPaymentMethod.value = 'Cash';
    formDescription.value = '';
    formReference.value = '';
  }

  Future<void> prepareEditExpenseForm(ExpenseModel expense) async {
    await loadMetadata();
    final full = await _expenseRepo.getExpenseById(expense.id!) ?? expense;
    editingExpenseId.value = full.id;
    formNextExpenseNumber.value = full.expenseNumber;
    formExpenseDate.value = full.expenseDate;
    formSelectedExpenseAccount.value = expenseAccounts.firstWhereOrNull((a) => a.id == full.accountId);
    formSelectedPaymentAccount.value = paymentAccounts.firstWhereOrNull((a) => a.id == full.paymentAccountId);
    formAmount.value = full.amount;
    formTaxAmount.value = full.taxAmount;
    formPaymentMethod.value = full.paymentMethod;
    formDescription.value = full.description ?? '';
    formReference.value = full.reference ?? '';
  }

  Future<bool> submitExpense() async {
    if (formSelectedExpenseAccount.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select an expense account', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
    if (formSelectedPaymentAccount.value == null) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Please select a payment account', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }
    if (formAmount.value <= 0) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Expense amount must be greater than zero', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    }

    try {
      isSubmitting.value = true;
      final roundedAmount = CurrencyUtils.round(formAmount.value);
      final roundedTax = CurrencyUtils.round(formTaxAmount.value);
      final totalPaid = CurrencyUtils.round(roundedAmount + roundedTax);

      final expense = ExpenseModel(
        id: editingExpenseId.value,
        expenseNumber: formNextExpenseNumber.value,
        expenseDate: formExpenseDate.value,
        accountId: formSelectedExpenseAccount.value!.id!,
        paymentAccountId: formSelectedPaymentAccount.value!.id!,
        amount: roundedAmount,
        taxAmount: roundedTax,
        paymentMethod: formPaymentMethod.value,
        description: formDescription.value,
        reference: formReference.value,
      );

      if (editingExpenseId.value != null) {
        await _dbHelper.transaction((txn) async {
          await _expenseRepo.updateExpense(expense, txn: txn);

          final lines = [
            JournalLineModel(
              accountId: expense.accountId,
              debit: roundedAmount,
              credit: 0.0,
              description: '${formSelectedExpenseAccount.value!.accountName}: ${expense.description ?? ''}',
            ),
            JournalLineModel(
              accountId: expense.paymentAccountId,
              debit: 0.0,
              credit: totalPaid,
              description: 'Payment for Expense #${expense.expenseNumber} via ${expense.paymentMethod}',
            ),
          ];

          if (roundedTax > 0) {
            final gstInput = await _accountRepo.getAccountByCode(AccountingConstants.codeGstInputCredit);
            final gstInputId = gstInput?.id ?? 7;
            lines.insert(
              1,
              JournalLineModel(
                accountId: gstInputId,
                debit: roundedTax,
                credit: 0.0,
                description: 'Input Tax on Expense #${expense.expenseNumber}',
              ),
            );
          }

          final entries = await txn.query(
            DatabaseTables.tableJournalEntries,
            columns: ['id'],
            where: '(reference_id = ? AND transaction_type = ?) OR transaction_number = ?',
            whereArgs: [expense.id, AccountingConstants.transTypeExpense, 'JV-EXP-${expense.id}'],
          );
          for (final e in entries) {
            final eId = e['id'] as int;
            await txn.delete(DatabaseTables.tableJournalLines, where: 'journal_entry_id = ?', whereArgs: [eId]);
            await txn.delete(DatabaseTables.tableJournalEntries, where: 'id = ?', whereArgs: [eId]);
          }

          await _accountingService.createJournalEntry(
            date: expense.expenseDate,
            type: AccountingConstants.transTypeExpense,
            description: 'Expense #${expense.expenseNumber} - ${formSelectedExpenseAccount.value!.accountName}',
            referenceId: expense.id,
            transactionNumber: 'JV-EXP-${expense.id}',
            lines: lines,
            txn: txn,
          );
        });

        await loadExpenses();
        editingExpenseId.value = null;
        if (Get.context != null) {
          Get.snackbar('Success', 'Expense updated successfully',
              snackPosition: SnackPosition.BOTTOM);
        }
        return true;
      } else {
        await _dbHelper.transaction((txn) async {
          final expenseId = await _expenseRepo.insertExpense(expense, txn: txn);

          final lines = [
            JournalLineModel(
              accountId: expense.accountId,
              debit: roundedAmount,
              credit: 0.0,
              description: '${formSelectedExpenseAccount.value!.accountName}: ${expense.description ?? ''}',
            ),
            JournalLineModel(
              accountId: expense.paymentAccountId,
              debit: 0.0,
              credit: totalPaid,
              description: 'Payment for Expense #${expense.expenseNumber} via ${expense.paymentMethod}',
            ),
          ];

          // If tax is included on expense
          if (roundedTax > 0) {
            final gstInput = await _accountRepo.getAccountByCode(AccountingConstants.codeGstInputCredit);
            final gstInputId = gstInput?.id ?? 7;
            lines.insert(
              1,
              JournalLineModel(
                accountId: gstInputId,
                debit: roundedTax,
                credit: 0.0,
                description: 'Input Tax on Expense #${expense.expenseNumber}',
              ),
            );
          }

          await _accountingService.createJournalEntry(
            date: expense.expenseDate,
            type: AccountingConstants.transTypeExpense,
            description: 'Expense #${expense.expenseNumber} - ${formSelectedExpenseAccount.value!.accountName}',
            referenceId: expenseId,
            transactionNumber: 'JV-EXP-$expenseId',
            lines: lines,
            txn: txn,
          );
        });

        await loadExpenses();
        if (Get.context != null) {
          Get.snackbar('Success', 'Expense added successfully',
              snackPosition: SnackPosition.BOTTOM);
        }
        return true;
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save expense: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deleteExpense(ExpenseModel expense) async {
    try {
      await _dbHelper.transaction((txn) async {
        final entries = await txn.query(
          DatabaseTables.tableJournalEntries,
          columns: ['id'],
          where: '(reference_id = ? AND transaction_type = ?) OR transaction_number = ?',
          whereArgs: [expense.id, AccountingConstants.transTypeExpense, 'JV-EXP-${expense.id}'],
        );
        for (final e in entries) {
          final eId = e['id'] as int;
          await txn.delete(DatabaseTables.tableJournalLines, where: 'journal_entry_id = ?', whereArgs: [eId]);
          await txn.delete(DatabaseTables.tableJournalEntries, where: 'id = ?', whereArgs: [eId]);
        }
        await _expenseRepo.deleteExpense(expense.id!, txn: txn);
      });
      await loadExpenses();
      if (Get.context != null) {
        Get.snackbar('Success', 'Expense deleted successfully', snackPosition: SnackPosition.BOTTOM);
      }
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete expense: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }
}
