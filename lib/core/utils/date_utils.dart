import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';

class AppDateUtils {
  static final DateFormat _displayFormat = DateFormat('dd-MM-yyyy');
  static final DateFormat _dbFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _shortDate = DateFormat('dd MMM yyyy');
  static final DateFormat _invoiceDate = DateFormat('dd/MM/yyyy');

  /// Open standard themed date picker dialog
  static Future<DateTime?> pickDate({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final first = firstDate ?? DateTime(2000);
    final last = lastDate ?? DateTime(2100);
    final baseInitial = initialDate ?? DateTime.now();
    final safeInitial = baseInitial.isBefore(first)
        ? first
        : (baseInitial.isAfter(last) ? last : baseInitial);

    return await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: isDark ? AppColors.primaryLight : AppColors.primary,
              onPrimary: Colors.white,
              surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              onSurface: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Format DateTime to dd-MM-yyyy
  static String format(DateTime? date) {
    if (date == null) return '';
    return _displayFormat.format(date);
  }

  /// Alias for format
  static String formatDisplay(DateTime? date) => format(date);

  /// Format DateTime to readable short string (e.g. 04 Oct 2026)
  static String formatShort(DateTime? date) {
    if (date == null) return '';
    return _shortDate.format(date);
  }

  /// Format DateTime for database storage
  static String formatDb(DateTime? date) {
    final d = date ?? DateTime.now();
    return _dbFormat.format(d);
  }

  /// Parse database stored string into DateTime
  static DateTime parseDb(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return DateTime.now();
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        return _dbFormat.parse(dateStr);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  /// Format for Invoice display
  static String formatInvoice(DateTime? date) {
    if (date == null) return '';
    return _invoiceDate.format(date);
  }

  /// Start of the day (00:00:00)
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 0, 0, 0);
  }

  /// End of the day (23:59:59)
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  /// Current financial year dates (April 1 to March 31)
  static ({DateTime start, DateTime end}) getCurrentFinancialYear() {
    final now = DateTime.now();
    if (now.month >= 4) {
      return (
        start: DateTime(now.year, 4, 1),
        end: DateTime(now.year + 1, 3, 31, 23, 59, 59),
      );
    } else {
      return (
        start: DateTime(now.year - 1, 4, 1),
        end: DateTime(now.year, 3, 31, 23, 59, 59),
      );
    }
  }
}
