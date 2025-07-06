// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget test', (WidgetTester tester) async {
    // Build a simple widget and verify it works
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Test App'),
        ),
      ),
    );

    // Verify that the text appears
    expect(find.text('Test App'), findsOneWidget);
  });
}
