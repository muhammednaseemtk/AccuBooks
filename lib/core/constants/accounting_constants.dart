class AccountingConstants {
  // Account Types
  static const String typeAsset = 'Asset';
  static const String typeLiability = 'Liability';
  static const String typeEquity = 'Equity';
  static const String typeIncome = 'Income';
  static const String typeExpense = 'Expense';

  static const List<String> accountTypes = [
    typeAsset,
    typeLiability,
    typeEquity,
    typeIncome,
    typeExpense,
  ];

  // Balance Types
  static const String balanceDebit = 'Debit';
  static const String balanceCredit = 'Credit';

  // System Account Codes
  static const String codeCash = '1000';
  static const String codeBank = '1010';
  static const String codeAccountsReceivable = '1020';
  static const String codeInventory = '1030';

  static const String codeAccountsPayable = '2000';
  static const String codeGstPayable = '2010';
  static const String codeGstInputCredit = '2020';

  static const String codeCapital = '3000';
  static const String codeRetainedEarnings = '3010';

  static const String codeSales = '4000';
  static const String codeOtherIncome = '4010';
  static const String codeDiscountReceived = '4020';

  static const String codePurchases = '5000';
  static const String codeRent = '5010';
  static const String codeSalary = '5020';
  static const String codeElectricity = '5030';
  static const String codeTransportation = '5040';
  static const String codeOfficeExpenses = '5050';
  static const String codeDiscountAllowed = '5060';

  // Transaction Types
  static const String transTypeSales = 'Sales';
  static const String transTypePurchase = 'Purchase';
  static const String transTypeReceipt = 'Receipt';
  static const String transTypePayment = 'Payment';
  static const String transTypeExpense = 'Expense';
  static const String transTypeJournal = 'Journal';
  static const String transTypeOpeningBalance = 'Opening Balance';
  static const String transTypeSalesOrder = 'Sales Order';
  static const String transTypeSalesReturn = 'Sales Return';
  static const String transTypePurchaseOrder = 'Purchase Order';
  static const String transTypePurchaseReturn = 'Purchase Return';

  // Order & Return Statuses
  static const String statusPending = 'Pending';
  static const String statusConfirmed = 'Confirmed';
  static const String statusCompleted = 'Completed';
  static const String statusCancelled = 'Cancelled';

  // Stock Transaction Types
  static const String stockPurchase = 'Purchase';
  static const String stockSale = 'Sale';
  static const String stockSalesReturn = 'Sales Return';
  static const String stockPurchaseReturn = 'Purchase Return';
  static const String stockAdjustment = 'Adjustment';
  static const String stockOpeningStock = 'Opening Stock';

  // Payment Statuses
  static const String paymentPaid = 'Paid';
  static const String paymentPartiallyPaid = 'Partially Paid';
  static const String paymentUnpaid = 'Unpaid';
  static const String paymentCancelled = 'Cancelled';

  // Payment Methods
  static const String methodCash = 'Cash';
  static const String methodBank = 'Bank';
  static const String methodCard = 'Card';
  static const String methodUPI = 'UPI';
  static const String methodOther = 'Other';

  static const List<String> paymentMethods = [
    methodCash,
    methodBank,
    methodCard,
    methodUPI,
    methodOther,
  ];

  // Tax Types
  static const String taxCGST = 'CGST';
  static const String taxSGST = 'SGST';
  static const String taxIGST = 'IGST';
  static const String taxVAT = 'VAT';
  static const String taxOther = 'Other';

  static const List<String> taxTypes = [
    taxCGST,
    taxSGST,
    taxIGST,
    taxVAT,
    taxOther,
  ];

  // Number Prefix
  static const String prefixSales = 'INV-';
  static const String prefixPurchase = 'PUR-';
  static const String prefixSalesOrder = 'SO-';
  static const String prefixSalesReturn = 'SR-';
  static const String prefixPurchaseOrder = 'PO-';
  static const String prefixPurchaseReturn = 'PR-';
  static const String prefixReceipt = 'REC-';
  static const String prefixPayment = 'PAY-';
  static const String prefixExpense = 'EXP-';
  static const String prefixJournal = 'JV-';
  static const String prefixCustomer = 'CUST-';
  static const String prefixSupplier = 'SUP-';
  static const String prefixProduct = 'PRD-';
}
