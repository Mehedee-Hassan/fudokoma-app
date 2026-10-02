// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:follo_cart/main.dart';

void main() {
  testWidgets('shows the map-first explore screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FolloCartApp());

    expect(find.text('Find your next bite'), findsOneWidget);
    expect(find.text('Near you now'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });
}
