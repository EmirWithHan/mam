import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/layout/app_breakpoints.dart';
import 'package:match_a_man/core/layout/responsive_layout.dart';

void main() {
  group('AppBreakpoints', () {
    test('maps release target widths to size classes', () {
      expect(AppBreakpoints.sizeClassForWidth(320), AppSizeClass.tiny);
      expect(AppBreakpoints.sizeClassForWidth(360), AppSizeClass.compact);
      expect(AppBreakpoints.sizeClassForWidth(599), AppSizeClass.compact);
      expect(AppBreakpoints.sizeClassForWidth(600), AppSizeClass.medium);
      expect(AppBreakpoints.sizeClassForWidth(839), AppSizeClass.medium);
      expect(AppBreakpoints.sizeClassForWidth(840), AppSizeClass.expanded);
    });
  });

  group('AppResponsive', () {
    test('uses standard page horizontal padding by width', () {
      expect(AppResponsive.pageHorizontalPaddingForWidth(320), 12);
      expect(AppResponsive.pageHorizontalPaddingForWidth(390), 16);
      expect(AppResponsive.pageHorizontalPaddingForWidth(600), 24);
      expect(AppResponsive.pageHorizontalPaddingForWidth(1024), 32);
    });

    test('uses standard card padding by width', () {
      expect(AppResponsive.cardPaddingForWidth(320), 12);
      expect(AppResponsive.cardPaddingForWidth(390), 16);
      expect(AppResponsive.cardPaddingForWidth(600), 20);
      expect(AppResponsive.cardPaddingForWidth(1024), 20);
    });

    test('keeps documented content width caps stable', () {
      expect(AppResponsive.formMaxWidth, 560);
      expect(AppResponsive.detailMaxWidth, 640);
      expect(AppResponsive.feedMaxWidth, 720);
    });
  });
}
