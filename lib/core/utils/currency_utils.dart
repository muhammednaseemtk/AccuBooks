import 'package:intl/intl.dart';

class CurrencyUtils {
  static String defaultSymbol = '₹';

  /// Format an amount into standard localized currency string, e.g. ₹ 1,25,000.00
  static String format(double? amount, {String? symbol, int decimalDigits = 2}) {
    final value = amount ?? 0.0;
    final curSymbol = symbol ?? defaultSymbol;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '$curSymbol ',
      decimalDigits: decimalDigits,
    );
    return formatter.format(value);
  }

  /// Format amount without currency symbol
  static String formatRaw(double? amount, {int decimalDigits = 2}) {
    final value = amount ?? 0.0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: decimalDigits,
    );
    return formatter.format(value).trim();
  }

  /// Round value to 2 decimal places to avoid floating-point inaccuracies
  static double round(double value, [int places = 2]) {
    return ((value * 100).roundToDouble()) / 100;
  }

  /// Safe double parse from string
  static double parse(String? text) {
    if (text == null || text.trim().isEmpty) return 0.0;
    final sanitized = text.replaceAll(',', '').replaceAll('₹', '').replaceAll(' ', '').trim();
    return double.tryParse(sanitized) ?? 0.0;
  }
}
