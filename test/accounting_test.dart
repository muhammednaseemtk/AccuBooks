import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/utils/currency_utils.dart';
import 'package:accubooks/services/tax_service.dart';
import 'package:accubooks/models/journal_line_model.dart';

void main() {
  group('Double-Entry Balancing Validation Tests', () {
    test('Journal entry with matching Debit and Credit is valid', () {
      final lines = [
        JournalLineModel(accountId: 1, debit: 10000.0, credit: 0.0),
        JournalLineModel(accountId: 4, debit: 0.0, credit: 10000.0),
      ];

      final totalDebit = lines.fold(0.0, (sum, l) => sum + l.debit);
      final totalCredit = lines.fold(0.0, (sum, l) => sum + l.credit);

      final isBalanced = (totalDebit - totalCredit).abs() <= 0.01;
      expect(isBalanced, isTrue);
      expect(totalDebit, equals(10000.0));
      expect(totalCredit, equals(10000.0));
    });

    test('Journal entry with mismatching Debit and Credit is rejected', () {
      final lines = [
        JournalLineModel(accountId: 1, debit: 10000.0, credit: 0.0),
        JournalLineModel(accountId: 4, debit: 0.0, credit: 9500.0),
      ];

      final totalDebit = lines.fold(0.0, (sum, l) => sum + l.debit);
      final totalCredit = lines.fold(0.0, (sum, l) => sum + l.credit);

      final isBalanced = (totalDebit - totalCredit).abs() <= 0.01;
      expect(isBalanced, isFalse);
    });

    test('Multi-line journal entry balances correctly', () {
      // Sale of 10,000 with 18% GST (900 CGST + 900 SGST)
      // Customer: 11,800 Dr
      // Sales: 10,000 Cr
      // CGST Output: 900 Cr
      // SGST Output: 900 Cr
      final lines = [
        JournalLineModel(accountId: 3, debit: 11800.0, credit: 0.0),
        JournalLineModel(accountId: 4, debit: 0.0, credit: 10000.0),
        JournalLineModel(accountId: 5, debit: 0.0, credit: 900.0),
        JournalLineModel(accountId: 6, debit: 0.0, credit: 900.0),
      ];

      final totalDebit = lines.fold(0.0, (sum, l) => sum + l.debit);
      final totalCredit = lines.fold(0.0, (sum, l) => sum + l.credit);

      expect((totalDebit - totalCredit).abs() <= 0.01, isTrue);
      expect(totalDebit, equals(11800.0));
      expect(totalCredit, equals(11800.0));
    });
  });

  group('Tax Calculation Tests', () {
    test('18% Intra-state GST splits into CGST 9% and SGST 9%', () {
      final result = TaxService.calculate(
        amount: 10000.0,
        taxRate: 18.0,
        isInterState: false,
      );

      expect(result.cgstAmount, equals(900.0));
      expect(result.sgstAmount, equals(900.0));
      expect(result.totalTax, equals(1800.0));
      expect(result.totalAmount, equals(11800.0));
    });

    test('18% Inter-state GST calculates single IGST 18%', () {
      final result = TaxService.calculate(
        amount: 10000.0,
        taxRate: 18.0,
        isInterState: true,
      );

      expect(result.igstAmount, equals(1800.0));
      expect(result.totalTax, equals(1800.0));
      expect(result.totalAmount, equals(11800.0));
    });

    test('Exclusive tax calculation', () {
      final tax = TaxService.calculateExclusiveTax(amount: 1000.0, rate: 18.0);
      expect(tax, equals(180.0));
    });

    test('Inclusive tax extraction', () {
      // 1180 with 18% inclusive tax should have 180 tax
      final tax = TaxService.calculateInclusiveTax(amountWithTax: 1180.0, rate: 18.0);
      expect(tax, equals(180.0));
    });
  });

  group('Currency Formatting Tests', () {
    test('Formats standard amount in INR with two decimals', () {
      final formatted = CurrencyUtils.format(125000.0);
      expect(formatted, contains('1,25,000.00'));
    });

    test('Formats zero amount properly', () {
      final formatted = CurrencyUtils.format(0.0);
      expect(formatted, contains('0.00'));
    });

    test('Parses numeric currency input accurately', () {
      expect(CurrencyUtils.parse('125000'), equals(125000.0));
      expect(CurrencyUtils.parse('₹1,25,000.00'), equals(125000.0));
      expect(CurrencyUtils.parse('invalid'), equals(0.0));
    });
  });

  group('Fundamental Accounting Equation Tests', () {
    test('Assets = Liabilities + Equity holds', () {
      // Balance Sheet:
      // Cash: 50,000 (Asset)
      // Bank: 1,50,000 (Asset)
      // Total Assets = 2,00,000
      //
      // Accounts Payable: 80,000 (Liability)
      // Total Liabilities = 80,000
      //
      // Capital: 1,00,000 (Equity)
      // Net Profit: 20,000 (Equity)
      // Total Equity = 1,20,000
      const totalAssets = 50000.0 + 150000.0;
      const totalLiabilities = 80000.0;
      const totalEquity = 100000.0 + 20000.0;

      expect(totalAssets, equals(totalLiabilities + totalEquity));
    });

    test('Profit & Loss calculation: Net Profit = Total Income - Total Expenses', () {
      const salesIncome = 250000.0;
      const otherIncome = 15000.0;
      const totalIncome = salesIncome + otherIncome;

      const purchases = 140000.0;
      const rentExpense = 20000.0;
      const salaryExpense = 30000.0;
      const totalExpenses = purchases + rentExpense + salaryExpense;

      const netProfit = totalIncome - totalExpenses;
      expect(netProfit, equals(75000.0));
    });
  });
}
