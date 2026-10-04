// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:follo_cart/auth/auth_gate.dart';

void main() {
  testWidgets('signed-out users can enter the guest app', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthGate(
          child: Scaffold(body: Text('Explore map')),
        ),
      ),
    );

    expect(find.text('Explore map'), findsOneWidget);
  });
}
