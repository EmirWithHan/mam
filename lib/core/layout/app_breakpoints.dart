import 'package:flutter/widgets.dart';

class AppBreakpoints {
  const AppBreakpoints._();

  static const tiny = 360.0;
  static const compact = 600.0;
  static const medium = 840.0;

  static bool isTiny(double width) => width < tiny;
  static bool isCompact(double width) => width >= tiny && width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= medium;

  static AppSizeClass sizeClassForWidth(double width) {
    if (isTiny(width)) return AppSizeClass.tiny;
    if (isCompact(width)) return AppSizeClass.compact;
    if (isMedium(width)) return AppSizeClass.medium;
    return AppSizeClass.expanded;
  }

  static AppSizeClass of(BuildContext context) {
    return sizeClassForWidth(MediaQuery.sizeOf(context).width);
  }
}

enum AppSizeClass { tiny, compact, medium, expanded }
