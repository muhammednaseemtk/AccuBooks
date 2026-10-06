import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/utils/input_formatters.dart';

void main() {
  group('Requirement 1 & 2: Numeric & Phone Input Formatters', () {
    group('Integer / Phone Formatter (digitsOnly)', () {
      final formatter = AppInputFormatters.digitsOnly;

      TextEditingValue apply(String oldVal, String newVal) {
        return formatter.formatEditUpdate(
          TextEditingValue(text: oldVal),
          TextEditingValue(text: newVal),
        );
      }

      test('allows digits 0-9', () {
        expect(apply('', '0123456789').text, '0123456789');
        expect(apply('', '9876543210').text, '9876543210');
        expect(apply('123', '1234').text, '1234');
      });

      test('disallows alphabetic characters', () {
        expect(apply('', 'abc').text, '');
        expect(apply('', '10abc').text, '10');
        expect(apply('123', '123a').text, '123');
      });

      test('disallows spaces and symbols', () {
        expect(apply('', '₹100').text, '100');
        expect(apply('', '100%').text, '100');
        expect(apply('', '10@20').text, '1020');
        expect(apply('', '10 20').text, '1020');
        expect(apply('', '+91 98765').text, '9198765');
        expect(apply('', '100.50').text, '10050'); // dots not allowed for digitsOnly
      });

      test('disallows emojis', () {
        expect(apply('', '100😀').text, '100');
      });
    });

    group('Decimal Fields Formatter (decimal)', () {
      final formatter = AppInputFormatters.decimal();

      TextEditingValue apply(String oldVal, String newVal) {
        return formatter.formatEditUpdate(
          TextEditingValue(text: oldVal),
          TextEditingValue(text: newVal),
        );
      }

      test('allows valid integers and decimals', () {
        // Examples from user specification:
        // Valid: 100, 100.50, 10.5
        expect(apply('', '100').text, '100');
        expect(apply('', '100.50').text, '100.50');
        expect(apply('', '10.5').text, '10.5');
        expect(apply('', '0').text, '0');
        expect(apply('', '0.25').text, '0.25');
        expect(apply('', '.').text, '.');
        expect(apply('', '.5').text, '.5');
      });

      test('strictly rejects invalid input examples from user specification', () {
        // Invalid: abc, 10abc, ₹100, 100%, 10@20
        expect(apply('', 'abc').text, '');
        expect(apply('', '10abc').text, '');
        expect(apply('', '₹100').text, '');
        expect(apply('', '100%').text, '');
        expect(apply('', '10@20').text, '');
      });

      test('rejects spaces, multiple decimal points, and emojis', () {
        expect(apply('100.50', '100.50.2').text, '100.50');
        expect(apply('', '..').text, '');
        expect(apply('10', '10 20').text, '10');
        expect(apply('50', '50😀').text, '50');
        expect(apply('', '-100').text, '');
      });

      test('respects decimalRange when specified', () {
        final twoDecimalFormatter = AppInputFormatters.decimal(decimalRange: 2);
        TextEditingValue applyRange(String oldVal, String newVal) {
          return twoDecimalFormatter.formatEditUpdate(
            TextEditingValue(text: oldVal),
            TextEditingValue(text: newVal),
          );
        }

        expect(applyRange('', '10.5').text, '10.5');
        expect(applyRange('', '10.50').text, '10.50');
        expect(applyRange('10.50', '10.505').text, '10.50');
      });
    });

    group('Account Code, Tax ID, and Barcode (digits only)', () {
      final formatter = AppInputFormatters.digitsOnly;

      TextEditingValue apply(String oldVal, String newVal) {
        return formatter.formatEditUpdate(
          TextEditingValue(text: oldVal),
          TextEditingValue(text: newVal),
        );
      }

      test('Account Code: accepts numbers only and rejects letters/symbols', () {
        expect(apply('', '1040').text, '1040');
        expect(apply('', 'ACC-1040').text, '1040');
        expect(apply('', '1040 abc').text, '1040');
        expect(apply('', '10@40').text, '1040');
      });

      test('Tax ID: accepts numbers only and rejects letters/symbols', () {
        expect(apply('', '1234567890').text, '1234567890');
        expect(apply('', '29ABCDE1234F1Z5').text, '29123415'); // non-digits stripped
        expect(apply('', 'TAX# 999').text, '999');
      });

      test('Barcode: accepts numbers only and rejects letters/symbols', () {
        expect(apply('', '8901030405060').text, '8901030405060');
        expect(apply('', 'EAN-13-890').text, '13890');
        expect(apply('', 'CODE 128').text, '128');
      });
    });
  });
}
