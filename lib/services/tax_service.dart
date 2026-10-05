import '../core/constants/accounting_constants.dart';
import '../core/utils/currency_utils.dart';

class TaxCalculationResult {
  final double baseAmount;
  final double taxRate;
  final String taxType;
  final double cgstRate;
  final double cgstAmount;
  final double sgstRate;
  final double sgstAmount;
  final double igstRate;
  final double igstAmount;
  final double totalTax;
  final double totalAmount;

  const TaxCalculationResult({
    required this.baseAmount,
    required this.taxRate,
    required this.taxType,
    this.cgstRate = 0.0,
    this.cgstAmount = 0.0,
    this.sgstRate = 0.0,
    this.sgstAmount = 0.0,
    this.igstRate = 0.0,
    this.igstAmount = 0.0,
    required this.totalTax,
    required this.totalAmount,
  });
}

class TaxService {
  /// Calculate exclusive tax amount
  static double calculateExclusiveTax({
    required double amount,
    required double rate,
  }) {
    return CurrencyUtils.round(amount * (rate / 100.0));
  }

  /// Calculate inclusive tax portion from gross amount
  static double calculateInclusiveTax({
    required double amountWithTax,
    required double rate,
  }) {
    final base = amountWithTax / (1.0 + (rate / 100.0));
    return CurrencyUtils.round(amountWithTax - base);
  }

  /// Calculate tax breakdown based on taxable amount, total tax rate, and tax type
  static TaxCalculationResult calculate({
    required double amount,
    required double taxRate,
    String taxType = AccountingConstants.taxOther,
    bool isInterState = false,
  }) {
    final base = CurrencyUtils.round(amount);
    if (base <= 0 || taxRate <= 0) {
      return TaxCalculationResult(
        baseAmount: base,
        taxRate: 0.0,
        taxType: taxType,
        totalTax: 0.0,
        totalAmount: base,
      );
    }

    final totalTax = CurrencyUtils.round(base * (taxRate / 100));
    final grandTotal = CurrencyUtils.round(base + totalTax);

    if (isInterState || taxType == AccountingConstants.taxIGST) {
      return TaxCalculationResult(
        baseAmount: base,
        taxRate: taxRate,
        taxType: AccountingConstants.taxIGST,
        igstRate: taxRate,
        igstAmount: totalTax,
        totalTax: totalTax,
        totalAmount: grandTotal,
      );
    } else if (taxType == AccountingConstants.taxCGST ||
        taxType == AccountingConstants.taxSGST ||
        taxType == 'GST' ||
        taxType == AccountingConstants.taxOther) {
      // Split evenly into CGST and SGST
      final halfRate = CurrencyUtils.round(taxRate / 2, 2);
      final cgstAmt = CurrencyUtils.round(totalTax / 2);
      final sgstAmt = CurrencyUtils.round(totalTax - cgstAmt); // ensure exact rounding

      return TaxCalculationResult(
        baseAmount: base,
        taxRate: taxRate,
        taxType: taxType,
        cgstRate: halfRate,
        cgstAmount: cgstAmt,
        sgstRate: halfRate,
        sgstAmount: sgstAmt,
        totalTax: totalTax,
        totalAmount: grandTotal,
      );
    } else {
      // VAT or flat tax
      return TaxCalculationResult(
        baseAmount: base,
        taxRate: taxRate,
        taxType: taxType,
        totalTax: totalTax,
        totalAmount: grandTotal,
      );
    }
  }
}
