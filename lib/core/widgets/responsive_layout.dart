import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveUtils.tabletBreakpoint) {
          return desktop;
        } else if (constraints.maxWidth >= ResponsiveUtils.mobileBreakpoint) {
          return tablet ?? desktop;
        } else {
          return mobile;
        }
      },
    );
  }
}

class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final double spacing;
  final bool forceColumn;
  final double breakpoint;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.spacing = 16.0,
    this.forceColumn = false,
    this.breakpoint = 580.0,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final isColumn = forceColumn || availableWidth < breakpoint;

        if (isColumn) {
          return Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisAlignment: mainAxisAlignment,
            children: children
                .expand((widget) => [widget, SizedBox(height: spacing)])
                .take(children.length * 2 - 1)
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
          children: children
              .expand((widget) => [Expanded(child: widget), SizedBox(width: spacing)])
              .take(children.length * 2 - 1)
              .toList(),
        );
      },
    );
  }
}
