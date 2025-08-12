// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:test_open_rdp/main.dart';

void main() {
  testWidgets('RDP app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RDPApp());

    // Verify that the main UI elements are present.
    expect(find.text('RDP Connection Manager'), findsOneWidget);
    expect(find.text('New RDP Connection'), findsOneWidget);
    expect(find.text('Connect RDP'), findsOneWidget);
  });
}
