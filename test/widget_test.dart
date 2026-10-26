import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khubsojadoc/screens/home/home_screen.dart';
import 'package:khubsojadoc/constants/app_theme.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
    expect(find.text('File Transformer'), findsWidgets);
  });
}
