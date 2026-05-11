import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/widgets/app_loader.dart';

void main() {
  testWidgets('Core loader renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppLoader()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
