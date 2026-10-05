import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class AppTableColumn {
  final String title;
  final double? width;
  final bool isNumeric;
  final Alignment alignment;

  const AppTableColumn({
    required this.title,
    this.width,
    this.isNumeric = false,
    this.alignment = Alignment.centerLeft,
  });
}

class AppTable extends StatefulWidget {
  final List<AppTableColumn> columns;
  final List<List<Widget>> rows;
  final List<VoidCallback?>? onRowTaps;
  final double minWidth;
  final bool showDividers;

  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTaps,
    this.minWidth = 700,
    this.showDividers = true,
  });

  @override
  State<AppTable> createState() => _AppTableState();
}

class _AppTableState extends State<AppTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : widget.minWidth;
        final effectiveWidth = availableWidth > widget.minWidth ? availableWidth : widget.minWidth;

        final tableContent = SizedBox(
          width: effectiveWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Container(
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: widget.columns.map((col) {
                    final cell = Align(
                      alignment: col.alignment,
                      child: Text(
                        col.title.toUpperCase(),
                        style: AppTextStyles.tableHeader.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    );

                    if (col.width != null) {
                      return SizedBox(width: col.width, child: cell);
                    }
                    return Expanded(child: cell);
                  }).toList(),
                ),
              ),

              // Data Rows
              if (widget.rows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: borderColor),
                      right: BorderSide(color: borderColor),
                      bottom: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No records found',
                      style: AppTextStyles.body2.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                )
              else
                for (int index = 0; index < widget.rows.length; index++) ...[
                  if (index > 0 && widget.showDividers)
                    Divider(height: 1, thickness: 1, color: borderColor),
                  Material(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    child: InkWell(
                      onTap: widget.onRowTaps != null && index < widget.onRowTaps!.length
                          ? widget.onRowTaps![index]
                          : null,
                      hoverColor: (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight)
                          .withValues(alpha: 0.5),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: borderColor),
                            right: BorderSide(color: borderColor),
                            bottom: index == widget.rows.length - 1
                                ? BorderSide(color: borderColor)
                                : BorderSide.none,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: List.generate(widget.columns.length, (colIndex) {
                            final col = widget.columns[colIndex];
                            final rowData = widget.rows[index];
                            final cell = colIndex < rowData.length
                                ? Align(alignment: col.alignment, child: rowData[colIndex])
                                : const SizedBox();

                            if (col.width != null) {
                              return SizedBox(width: col.width, child: cell);
                            }
                            return Expanded(child: cell);
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
            ],
          ),
        );

        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: effectiveWidth > availableWidth,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: tableContent,
          ),
        );
      },
    );
  }
}
