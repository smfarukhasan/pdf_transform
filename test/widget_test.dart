import 'package:flutter_test/flutter_test.dart';
import 'package:khubsojadoc/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KhubSojaDocApp());
    expect(find.text('KhubSojaDoc'), findsWidgets);
  });
}
