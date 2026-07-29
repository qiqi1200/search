import 'package:flutter_test/flutter_test.dart';
import 'package:yanler_browser/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const YanlerApp());
    expect(find.text('Yanler'), findsOneWidget);
  });
}
