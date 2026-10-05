class ValidationUtils {
  /// Validate non-empty string
  static String? requiredField(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate valid non-negative number
  static String? positiveNumber(String? value, {String fieldName = 'Amount', bool allowZero = true}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final numVal = double.tryParse(value.replaceAll(',', '').trim());
    if (numVal == null) {
      return 'Enter a valid number for $fieldName';
    }
    if (allowZero && numVal < 0) {
      return '$fieldName cannot be negative';
    }
    if (!allowZero && numVal <= 0) {
      return '$fieldName must be greater than zero';
    }
    return null;
  }

  /// Validate email format
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validate phone number
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    if (value.trim().length < 7) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Check double balance equality within epsilon of 0.01
  static bool areBalanced(double debit, double credit, {double epsilon = 0.01}) {
    return (debit - credit).abs() <= epsilon;
  }
}
