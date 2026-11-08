// This is a basic Flutter widget test for the Room Rental / PG Management App.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:room_rental/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: RoomRentalApp(),
      ),
    );

    // Verify that the app shows the loading state or authenticates screen
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
