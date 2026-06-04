import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

class AppResponsive {
  const AppResponsive._();

  static const formMaxWidth = 560.0;
  static const detailMaxWidth = 640.0;
  static const feedMaxWidth = 720.0;

  static double pageHorizontalPaddingForWidth(double width) {
    return switch (AppBreakpoints.sizeClassForWidth(width)) {
      AppSizeClass.tiny => 12,
      AppSizeClass.compact => 16,
      AppSizeClass.medium => 24,
      AppSizeClass.expanded => 32,
    };
  }

  static double cardPaddingForWidth(double width) {
    return switch (AppBreakpoints.sizeClassForWidth(width)) {
      AppSizeClass.tiny => 12,
      AppSizeClass.compact => 16,
      AppSizeClass.medium || AppSizeClass.expanded => 20,
    };
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 16,
    double bottom = 24,
  }) {
    final horizontal = pageHorizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
    );
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  static EdgeInsets listPadding(
    BuildContext context, {
    double top = 16,
    double bottom = 96,
  }) {
    final horizontal = pageHorizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
    );
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  static EdgeInsets cardPadding(BuildContext context) {
    return EdgeInsets.all(
      cardPaddingForWidth(MediaQuery.sizeOf(context).width),
    );
  }

  static bool isTiny(BuildContext context) {
    return AppBreakpoints.of(context) == AppSizeClass.tiny;
  }
}

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppResponsive.detailMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
