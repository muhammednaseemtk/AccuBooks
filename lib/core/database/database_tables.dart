class DatabaseTables {
  // Table Names
  static const String tableCompanies = 'companies';
  static const String tableOrganizations = 'organizations';
  static const String tableUsers = 'users';
  static const String tablePasswordResets = 'password_resets';
  static const String tableAccounts = 'accounts';
  static const String tableCustomers = 'customers';
  static const String tableSuppliers = 'suppliers';
  static const String tableCategories = 'categories';
  static const String tableProducts = 'products';
  static const String tableTaxes = 'taxes';
  static const String tableSalesInvoices = 'sales_invoices';
  static const String tableSalesInvoiceItems = 'sales_invoice_items';
  static const String tableSalesOrders = 'sales_orders';
  static const String tableSalesOrderItems = 'sales_order_items';
  static const String tableSalesReturns = 'sales_returns';
  static const String tableSalesReturnItems = 'sales_return_items';
  static const String tablePurchaseInvoices = 'purchase_invoices';
  static const String tablePurchaseInvoiceItems = 'purchase_invoice_items';
  static const String tablePurchaseOrders = 'purchase_orders';
  static const String tablePurchaseOrderItems = 'purchase_order_items';
  static const String tablePurchaseReturns = 'purchase_returns';
  static const String tablePurchaseReturnItems = 'purchase_return_items';
  static const String tableReceipts = 'receipts';
  static const String tablePayments = 'payments';
  static const String tableExpenses = 'expenses';
  static const String tableJournalEntries = 'journal_entries';
  static const String tableJournalLines = 'journal_lines';
  static const String tableStockTransactions = 'stock_transactions';

  // Schema creation statements
  static const String createCompaniesTable = '''
    CREATE TABLE $tableCompanies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      address TEXT,
      phone TEXT,
      email TEXT,
      tax_number TEXT,
      currency TEXT DEFAULT '₹',
      financial_year_start TEXT,
      financial_year_end TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createOrganizationsTable = '''
    CREATE TABLE $tableOrganizations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      owner_id INTEGER,
      currency TEXT DEFAULT '₹',
      tax_number TEXT,
      phone TEXT,
      email TEXT,
      address TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createUsersTable = '''
    CREATE TABLE $tableUsers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      organization_id INTEGER NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      salt TEXT NOT NULL,
      full_name TEXT NOT NULL,
      phone TEXT,
      role TEXT NOT NULL DEFAULT 'OWNER',
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (organization_id) REFERENCES $tableOrganizations (id) ON DELETE CASCADE
    );
  ''';

  static const String createPasswordResetsTable = '''
    CREATE TABLE $tablePasswordResets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL,
      token TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createAccountsTable = '''
    CREATE TABLE $tableAccounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_code TEXT UNIQUE NOT NULL,
      account_name TEXT NOT NULL,
      account_type TEXT NOT NULL,
      parent_id INTEGER,
      opening_balance REAL DEFAULT 0.0,
      opening_balance_type TEXT DEFAULT 'Debit',
      is_system_account INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createCustomersTable = '''
    CREATE TABLE $tableCustomers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_code TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      address TEXT,
      tax_number TEXT,
      credit_limit REAL DEFAULT 0.0,
      opening_balance REAL DEFAULT 0.0,
      opening_balance_type TEXT DEFAULT 'Debit',
      account_id INTEGER,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (account_id) REFERENCES $tableAccounts (id)
    );
  ''';

  static const String createSuppliersTable = '''
    CREATE TABLE $tableSuppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplier_code TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      address TEXT,
      tax_number TEXT,
      credit_limit REAL DEFAULT 0.0,
      opening_balance REAL DEFAULT 0.0,
      opening_balance_type TEXT DEFAULT 'Credit',
      account_id INTEGER,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (account_id) REFERENCES $tableAccounts (id)
    );
  ''';

  static const String createCategoriesTable = '''
    CREATE TABLE $tableCategories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createProductsTable = '''
    CREATE TABLE $tableProducts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_code TEXT UNIQUE NOT NULL,
      barcode TEXT,
      name TEXT NOT NULL,
      category_id INTEGER,
      unit TEXT DEFAULT 'Nos',
      purchase_price REAL DEFAULT 0.0,
      sales_price REAL DEFAULT 0.0,
      tax_rate REAL DEFAULT 0.0,
      stock_quantity REAL DEFAULT 0.0,
      minimum_stock REAL DEFAULT 5.0,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES $tableCategories (id)
    );
  ''';

  static const String createTaxesTable = '''
    CREATE TABLE $tableTaxes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      rate REAL NOT NULL,
      tax_type TEXT NOT NULL,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createSalesInvoicesTable = '''
    CREATE TABLE $tableSalesInvoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT UNIQUE NOT NULL,
      invoice_date TEXT NOT NULL,
      customer_id INTEGER NOT NULL,
      subtotal REAL NOT NULL DEFAULT 0.0,
      discount REAL NOT NULL DEFAULT 0.0,
      tax_amount REAL NOT NULL DEFAULT 0.0,
      grand_total REAL NOT NULL DEFAULT 0.0,
      paid_amount REAL NOT NULL DEFAULT 0.0,
      balance_amount REAL NOT NULL DEFAULT 0.0,
      payment_status TEXT NOT NULL DEFAULT 'Unpaid',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
    );
  ''';

  static const String createSalesInvoiceItemsTable = '''
    CREATE TABLE $tableSalesInvoiceItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      description TEXT,
      quantity REAL NOT NULL,
      rate REAL NOT NULL,
      discount REAL DEFAULT 0.0,
      tax_rate REAL DEFAULT 0.0,
      tax_amount REAL DEFAULT 0.0,
      total REAL NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES $tableSalesInvoices (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
    );
  ''';

  static const String createPurchaseInvoicesTable = '''
    CREATE TABLE $tablePurchaseInvoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT UNIQUE NOT NULL,
      invoice_date TEXT NOT NULL,
      supplier_id INTEGER NOT NULL,
      subtotal REAL NOT NULL DEFAULT 0.0,
      discount REAL NOT NULL DEFAULT 0.0,
      tax_amount REAL NOT NULL DEFAULT 0.0,
      grand_total REAL NOT NULL DEFAULT 0.0,
      paid_amount REAL NOT NULL DEFAULT 0.0,
      balance_amount REAL NOT NULL DEFAULT 0.0,
      payment_status TEXT NOT NULL DEFAULT 'Unpaid',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (supplier_id) REFERENCES $tableSuppliers (id)
    );
  ''';

  static const String createPurchaseInvoiceItemsTable = '''
    CREATE TABLE $tablePurchaseInvoiceItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      description TEXT,
      quantity REAL NOT NULL,
      rate REAL NOT NULL,
      discount REAL DEFAULT 0.0,
      tax_rate REAL DEFAULT 0.0,
      tax_amount REAL DEFAULT 0.0,
      total REAL NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES $tablePurchaseInvoices (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
    );
  ''';

  static const String createReceiptsTable = '''
    CREATE TABLE $tableReceipts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receipt_number TEXT UNIQUE NOT NULL,
      receipt_date TEXT NOT NULL,
      customer_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      payment_method TEXT NOT NULL,
      reference TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id),
      FOREIGN KEY (account_id) REFERENCES $tableAccounts (id)
    );
  ''';

  static const String createPaymentsTable = '''
    CREATE TABLE $tablePayments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payment_number TEXT UNIQUE NOT NULL,
      payment_date TEXT NOT NULL,
      supplier_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      payment_method TEXT NOT NULL,
      reference TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (supplier_id) REFERENCES $tableSuppliers (id),
      FOREIGN KEY (account_id) REFERENCES $tableAccounts (id)
    );
  ''';

  static const String createExpensesTable = '''
    CREATE TABLE $tableExpenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      expense_number TEXT UNIQUE NOT NULL,
      expense_date TEXT NOT NULL,
      account_id INTEGER NOT NULL,
      payment_account_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      tax_amount REAL DEFAULT 0.0,
      payment_method TEXT NOT NULL,
      description TEXT,
      reference TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (account_id) REFERENCES $tableAccounts (id),
      FOREIGN KEY (payment_account_id) REFERENCES $tableAccounts (id)
    );
  ''';

  static const String createJournalEntriesTable = '''
    CREATE TABLE $tableJournalEntries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_number TEXT UNIQUE NOT NULL,
      transaction_date TEXT NOT NULL,
      transaction_type TEXT NOT NULL,
      reference_id INTEGER,
      description TEXT,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createJournalLinesTable = '''
    CREATE TABLE $tableJournalLines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      journal_entry_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL,
      debit REAL NOT NULL DEFAULT 0.0,
      credit REAL NOT NULL DEFAULT 0.0,
      description TEXT,
      FOREIGN KEY (journal_entry_id) REFERENCES $tableJournalEntries (id) ON DELETE CASCADE,
      FOREIGN KEY (account_id) REFERENCES $tableAccounts (id)
    );
  ''';

  static const String createStockTransactionsTable = '''
    CREATE TABLE $tableStockTransactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      transaction_type TEXT NOT NULL,
      reference_id INTEGER,
      quantity_in REAL DEFAULT 0.0,
      quantity_out REAL DEFAULT 0.0,
      rate REAL DEFAULT 0.0,
      balance_quantity REAL NOT NULL,
      transaction_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
    );
  ''';

  static const String createSalesOrdersTable = '''
    CREATE TABLE $tableSalesOrders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_number TEXT UNIQUE NOT NULL,
      order_date TEXT NOT NULL,
      expected_delivery_date TEXT,
      customer_id INTEGER NOT NULL,
      subtotal REAL NOT NULL DEFAULT 0.0,
      discount REAL NOT NULL DEFAULT 0.0,
      tax_amount REAL NOT NULL DEFAULT 0.0,
      grand_total REAL NOT NULL DEFAULT 0.0,
      status TEXT NOT NULL DEFAULT 'Pending',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
    );
  ''';

  static const String createSalesOrderItemsTable = '''
    CREATE TABLE $tableSalesOrderItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      description TEXT,
      quantity REAL NOT NULL,
      rate REAL NOT NULL,
      discount REAL DEFAULT 0.0,
      tax_rate REAL DEFAULT 0.0,
      tax_amount REAL DEFAULT 0.0,
      total REAL NOT NULL,
      FOREIGN KEY (order_id) REFERENCES $tableSalesOrders (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
    );
  ''';

  static const String createSalesReturnsTable = '''
    CREATE TABLE $tableSalesReturns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_number TEXT UNIQUE NOT NULL,
      return_date TEXT NOT NULL,
      customer_id INTEGER NOT NULL,
      reference_invoice_id INTEGER,
      reference_invoice_number TEXT,
      subtotal REAL NOT NULL DEFAULT 0.0,
      discount REAL NOT NULL DEFAULT 0.0,
      tax_amount REAL NOT NULL DEFAULT 0.0,
      grand_total REAL NOT NULL DEFAULT 0.0,
      reason TEXT,
      status TEXT NOT NULL DEFAULT 'Completed',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id),
      FOREIGN KEY (reference_invoice_id) REFERENCES $tableSalesInvoices (id)
    );
  ''';

  static const String createSalesReturnItemsTable = '''
    CREATE TABLE $tableSalesReturnItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      description TEXT,
      quantity REAL NOT NULL,
      rate REAL NOT NULL,
      discount REAL DEFAULT 0.0,
      tax_rate REAL DEFAULT 0.0,
      tax_amount REAL DEFAULT 0.0,
      total REAL NOT NULL,
      FOREIGN KEY (return_id) REFERENCES $tableSalesReturns (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
    );
  ''';

  static const String createPurchaseOrdersTable = '''
    CREATE TABLE $tablePurchaseOrders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_number TEXT UNIQUE NOT NULL,
      order_date TEXT NOT NULL,
      expected_delivery_date TEXT,
      supplier_id INTEGER NOT NULL,
      subtotal REAL NOT NULL DEFAULT 0.0,
      discount REAL NOT NULL DEFAULT 0.0,
      tax_amount REAL NOT NULL DEFAULT 0.0,
      grand_total REAL NOT NULL DEFAULT 0.0,
      status TEXT NOT NULL DEFAULT 'Pending',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (supplier_id) REFERENCES $tableSuppliers (id)
    );
  ''';

  static const String createPurchaseOrderItemsTable = '''
    CREATE TABLE $tablePurchaseOrderItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      description TEXT,
      quantity REAL NOT NULL,
      rate REAL NOT NULL,
      discount REAL DEFAULT 0.0,
      tax_rate REAL DEFAULT 0.0,
      tax_amount REAL DEFAULT 0.0,
      total REAL NOT NULL,
      FOREIGN KEY (order_id) REFERENCES $tablePurchaseOrders (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
    );
  ''';

  static const String createPurchaseReturnsTable = '''
    CREATE TABLE $tablePurchaseReturns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_number TEXT UNIQUE NOT NULL,
      return_date TEXT NOT NULL,
      supplier_id INTEGER NOT NULL,
      reference_invoice_id INTEGER,
      reference_invoice_number TEXT,
      subtotal REAL NOT NULL DEFAULT 0.0,
      discount REAL NOT NULL DEFAULT 0.0,
      tax_amount REAL NOT NULL DEFAULT 0.0,
      grand_total REAL NOT NULL DEFAULT 0.0,
      reason TEXT,
      status TEXT NOT NULL DEFAULT 'Completed',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (supplier_id) REFERENCES $tableSuppliers (id),
      FOREIGN KEY (reference_invoice_id) REFERENCES $tablePurchaseInvoices (id)
    );
  ''';

  static const String createPurchaseReturnItemsTable = '''
    CREATE TABLE $tablePurchaseReturnItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      description TEXT,
      quantity REAL NOT NULL,
      rate REAL NOT NULL,
      discount REAL DEFAULT 0.0,
      tax_rate REAL DEFAULT 0.0,
      tax_amount REAL DEFAULT 0.0,
      total REAL NOT NULL,
      FOREIGN KEY (return_id) REFERENCES $tablePurchaseReturns (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
    );
  ''';

  // Indexes for high performance
  static const List<String> createIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_accounts_type ON $tableAccounts(account_type);',
    'CREATE INDEX IF NOT EXISTS idx_accounts_code ON $tableAccounts(account_code);',
    'CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON $tableJournalEntries(transaction_date);',
    'CREATE INDEX IF NOT EXISTS idx_journal_entries_type ON $tableJournalEntries(transaction_type);',
    'CREATE INDEX IF NOT EXISTS idx_journal_lines_entry ON $tableJournalLines(journal_entry_id);',
    'CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON $tableJournalLines(account_id);',
    'CREATE INDEX IF NOT EXISTS idx_stock_product ON $tableStockTransactions(product_id);',
    'CREATE INDEX IF NOT EXISTS idx_stock_date ON $tableStockTransactions(transaction_date);',
    'CREATE INDEX IF NOT EXISTS idx_sales_customer ON $tableSalesInvoices(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_sales_date ON $tableSalesInvoices(invoice_date);',
    'CREATE INDEX IF NOT EXISTS idx_sales_orders_cust ON $tableSalesOrders(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_sales_orders_date ON $tableSalesOrders(order_date);',
    'CREATE INDEX IF NOT EXISTS idx_sales_returns_cust ON $tableSalesReturns(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_sales_returns_date ON $tableSalesReturns(return_date);',
    'CREATE INDEX IF NOT EXISTS idx_purchase_supplier ON $tablePurchaseInvoices(supplier_id);',
    'CREATE INDEX IF NOT EXISTS idx_purchase_date ON $tablePurchaseInvoices(invoice_date);',
    'CREATE INDEX IF NOT EXISTS idx_purchase_orders_supp ON $tablePurchaseOrders(supplier_id);',
    'CREATE INDEX IF NOT EXISTS idx_purchase_orders_date ON $tablePurchaseOrders(order_date);',
    'CREATE INDEX IF NOT EXISTS idx_purchase_returns_supp ON $tablePurchaseReturns(supplier_id);',
    'CREATE INDEX IF NOT EXISTS idx_purchase_returns_date ON $tablePurchaseReturns(return_date);',
    'CREATE INDEX IF NOT EXISTS idx_receipts_customer ON $tableReceipts(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_payments_supplier ON $tablePayments(supplier_id);',
    'CREATE INDEX IF NOT EXISTS idx_expenses_account ON $tableExpenses(account_id);',
    'CREATE INDEX IF NOT EXISTS idx_users_email ON $tableUsers(email);',
    'CREATE INDEX IF NOT EXISTS idx_users_org ON $tableUsers(organization_id);',
    'CREATE INDEX IF NOT EXISTS idx_pw_resets_email ON $tablePasswordResets(email);',
  ];
}
