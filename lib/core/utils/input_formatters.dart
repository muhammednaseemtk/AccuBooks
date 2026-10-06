import 'package:flutter/services.dart';

/// Formatter that restricts input to a valid decimal number.
/// Only allows digits 0-9 and at most one decimal separator ('.').
/// Rejects alphabetic characters, spaces, emojis, symbols (₹, %, @, etc.),
/// and multiple decimal points.
class DecimalTextInputFormatter extends TextInputFormatter {
  final int? decimalRange;

  const DecimalTextInputFormatter({this.decimalRange});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Must only contain digits and at most one decimal point
    final regExp = RegExp(r'^\d*\.?\d*$');
    if (!regExp.hasMatch(newValue.text)) {
      return oldValue;
    }

    // Optional limitation on number of decimal digits
    if (decimalRange != null && newValue.text.contains('.')) {
      final parts = newValue.text.split('.');
      if (parts.length > 1 && parts[1].length > decimalRange!) {
        return oldValue;
      }
    }

    return newValue;
  }
}

/// Centralized input formatters for AccuBooks.
class AppInputFormatters {
  AppInputFormatters._();

  /// Formatter for strictly whole integers (e.g., Phone numbers, verification codes, whole counts).
  /// Strictly allows only 0-9.
  static TextInputFormatter get digitsOnly => FilteringTextInputFormatter.digitsOnly;

  /// Formatter for decimal amounts, prices, rates, taxes, and quantities.
  /// Allows digits 0-9 and at most one decimal point.
  static TextInputFormatter decimal({int? decimalRange}) =>
      DecimalTextInputFormatter(decimalRange: decimalRange);

  /// Limit max characters
  static TextInputFormatter length(int maxLength) =>
      LengthLimitingTextInputFormatter(maxLength);
}
