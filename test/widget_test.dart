import 'package:flutter_test/flutter_test.dart';
import 'package:jaimakali/main.dart';

void main() {
  testWidgets('SajniRe app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SajniReApp());

    // Verify that the title 'SajniRe!' is displayed on the login screen
    expect(find.text('SajniRe!'), findsOneWidget);
  });
}
