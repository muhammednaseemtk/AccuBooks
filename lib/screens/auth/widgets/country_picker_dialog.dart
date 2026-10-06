import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../models/country_model.dart';

Future<Country?> showCountryPickerDialog(
  BuildContext context, {
  required Country selectedCountry,
  required ValueChanged<Country> onSelected,
}) async {
  return showDialog<Country>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return CountryPickerDialog(
        selectedCountry: selectedCountry,
        onSelected: onSelected,
      );
    },
  );
}

class CountryPickerDialog extends StatefulWidget {
  final Country selectedCountry;
  final ValueChanged<Country> onSelected;

  const CountryPickerDialog({
    super.key,
    required this.selectedCountry,
    required this.onSelected,
  });

  @override
  State<CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<CountryPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Country> _filteredCountries = Countries.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = Countries.all;
      } else {
        final queryDigits = query.replaceAll(RegExp(r'\D'), '');
        _filteredCountries = Countries.all.where((c) {
          final matchesName = c.name.toLowerCase().contains(query);
          final matchesCode = c.code.toLowerCase().contains(query);
          final matchesDial = c.dialCode.toLowerCase().contains(query) ||
              (queryDigits.isNotEmpty && c.dialCode.replaceAll('+', '').contains(queryDigits));
          return matchesName || matchesCode || matchesDial;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height;
    final maxDialogHeight = (availableHeight * 0.75).clamp(320.0, 560.0);

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: maxDialogHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.public_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select Country',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: AppTextStyles.body2.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Search country or calling code...',
                  hintStyle: AppTextStyles.body2.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceVariantDark : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // Countries List
            Expanded(
              child: _filteredCountries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No countries found',
                              style: AppTextStyles.body2.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCountries.length,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemBuilder: (context, index) {
                        final country = _filteredCountries[index];
                        final isSelected = country.code == widget.selectedCountry.code &&
                            country.dialCode == widget.selectedCountry.dialCode;

                        return InkWell(
                          onTap: () {
                            widget.onSelected(country);
                            Navigator.of(context).pop(country);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Text(
                                  country.flag,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    country.name,
                                    style: AppTextStyles.body2.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceVariantDark : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    country.dialCode,
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
