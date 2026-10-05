import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/accounting_constants.dart';
import '../utils/date_utils.dart';
import 'database_tables.dart';

class DatabaseMigrations {
  static const int currentVersion = 1;

  static Future<void> onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Create Tables
    batch.execute(DatabaseTables.createCompaniesTable);
    batch.execute(DatabaseTables.createAccountsTable);
    batch.execute(DatabaseTables.createCustomersTable);
    batch.execute(DatabaseTables.createSuppliersTable);
    batch.execute(DatabaseTables.createCategoriesTable);
    batch.execute(DatabaseTables.createProductsTable);
    batch.execute(DatabaseTables.createTaxesTable);
    batch.execute(DatabaseTables.createSalesInvoicesTable);
    batch.execute(DatabaseTables.createSalesInvoiceItemsTable);
    batch.execute(DatabaseTables.createPurchaseInvoicesTable);
    batch.execute(DatabaseTables.createPurchaseInvoiceItemsTable);
    batch.execute(DatabaseTables.createReceiptsTable);
    batch.execute(DatabaseTables.createPaymentsTable);
    batch.execute(DatabaseTables.createExpensesTable);
    batch.execute(DatabaseTables.createJournalEntriesTable);
    batch.execute(DatabaseTables.createJournalLinesTable);
    batch.execute(DatabaseTables.createStockTransactionsTable);

    // 2. Create Indexes
    for (final indexSql in DatabaseTables.createIndexes) {
      batch.execute(indexSql);
    }

    await batch.commit(noResult: true);

    // 3. Seed Default Records
    await _seedDefaultCompany(db);
    await _seedChartOfAccounts(db);
    await _seedDefaultTaxes(db);
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future database upgrades if new version is introduced
  }

  static Future<void> _seedDefaultCompany(Database db) async {
    final now = AppDateUtils.formatDb(DateTime.now());
    final fy = AppDateUtils.getCurrentFinancialYear();

    await db.insert(DatabaseTables.tableCompanies, {
      'name': 'AccuBooks Enterprises',
      'address': 'Plot 42, Silicon Gateway, Tech Park',
      'phone': '+91 98765 43210',
      'email': 'finance@accubooks.local',
      'tax_number': 'GSTIN29ABCDE1234F1Z5',
      'currency': '₹',
      'financial_year_start': AppDateUtils.formatDb(fy.start),
      'financial_year_end': AppDateUtils.formatDb(fy.end),
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<void> _seedChartOfAccounts(Database db) async {
    final now = AppDateUtils.formatDb(DateTime.now());

    final accounts = [
      // Assets (1000 - 1999)
      {
        'account_code': AccountingConstants.codeCash,
        'account_name': 'Cash in Hand',
        'account_type': AccountingConstants.typeAsset,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeBank,
        'account_name': 'Bank Account (Main)',
        'account_type': AccountingConstants.typeAsset,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeAccountsReceivable,
        'account_name': 'Accounts Receivable (Debtors)',
        'account_type': AccountingConstants.typeAsset,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeInventory,
        'account_name': 'Inventory (Stock in Hand)',
        'account_type': AccountingConstants.typeAsset,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },

      // Liabilities (2000 - 2999)
      {
        'account_code': AccountingConstants.codeAccountsPayable,
        'account_name': 'Accounts Payable (Creditors)',
        'account_type': AccountingConstants.typeLiability,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceCredit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeGstPayable,
        'account_name': 'GST / Tax Payable (Output)',
        'account_type': AccountingConstants.typeLiability,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceCredit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeGstInputCredit,
        'account_name': 'GST Input Tax Credit',
        'account_type': AccountingConstants.typeAsset,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },

      // Equity (3000 - 3999)
      {
        'account_code': AccountingConstants.codeCapital,
        'account_name': "Owner's Capital",
        'account_type': AccountingConstants.typeEquity,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceCredit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeRetainedEarnings,
        'account_name': 'Retained Earnings',
        'account_type': AccountingConstants.typeEquity,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceCredit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },

      // Income (4000 - 4999)
      {
        'account_code': AccountingConstants.codeSales,
        'account_name': 'Sales Revenue',
        'account_type': AccountingConstants.typeIncome,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceCredit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeOtherIncome,
        'account_name': 'Other Operating Income',
        'account_type': AccountingConstants.typeIncome,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceCredit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeDiscountReceived,
        'account_name': 'Discount Received',
        'account_type': AccountingConstants.typeIncome,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceCredit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },

      // Expenses (5000 - 5999)
      {
        'account_code': AccountingConstants.codePurchases,
        'account_name': 'Cost of Goods Sold / Purchases',
        'account_type': AccountingConstants.typeExpense,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeRent,
        'account_name': 'Rent Expense',
        'account_type': AccountingConstants.typeExpense,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeSalary,
        'account_name': 'Salaries and Wages',
        'account_type': AccountingConstants.typeExpense,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeElectricity,
        'account_name': 'Electricity & Utility Expense',
        'account_type': AccountingConstants.typeExpense,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeTransportation,
        'account_name': 'Transportation & Logistics',
        'account_type': AccountingConstants.typeExpense,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeOfficeExpenses,
        'account_name': 'Office & General Expenses',
        'account_type': AccountingConstants.typeExpense,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'account_code': AccountingConstants.codeDiscountAllowed,
        'account_name': 'Discount Allowed',
        'account_type': AccountingConstants.typeExpense,
        'opening_balance': 0.0,
        'opening_balance_type': AccountingConstants.balanceDebit,
        'is_system_account': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final acc in accounts) {
      await db.insert(DatabaseTables.tableAccounts, acc);
    }
  }

  static Future<void> _seedDefaultTaxes(Database db) async {
    final now = AppDateUtils.formatDb(DateTime.now());

    final taxes = [
      {'name': 'GST 18% (Standard)', 'rate': 18.0, 'tax_type': AccountingConstants.taxOther, 'is_active': 1, 'created_at': now},
      {'name': 'CGST 9%', 'rate': 9.0, 'tax_type': AccountingConstants.taxCGST, 'is_active': 1, 'created_at': now},
      {'name': 'SGST 9%', 'rate': 9.0, 'tax_type': AccountingConstants.taxSGST, 'is_active': 1, 'created_at': now},
      {'name': 'IGST 18%', 'rate': 18.0, 'tax_type': AccountingConstants.taxIGST, 'is_active': 1, 'created_at': now},
      {'name': 'GST 12%', 'rate': 12.0, 'tax_type': AccountingConstants.taxOther, 'is_active': 1, 'created_at': now},
      {'name': 'GST 5%', 'rate': 5.0, 'tax_type': AccountingConstants.taxOther, 'is_active': 1, 'created_at': now},
      {'name': 'VAT 5%', 'rate': 5.0, 'tax_type': AccountingConstants.taxVAT, 'is_active': 1, 'created_at': now},
      {'name': 'Tax Exempt / 0%', 'rate': 0.0, 'tax_type': AccountingConstants.taxOther, 'is_active': 1, 'created_at': now},
    ];

    for (final tax in taxes) {
      await db.insert(DatabaseTables.tableTaxes, tax);
    }
  }
}
