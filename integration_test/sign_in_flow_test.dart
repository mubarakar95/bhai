import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:room_rental/core/providers/app_providers.dart';
import 'package:room_rental/core/services/supabase_service.dart';
import 'package:room_rental/features/auth/presentation/auth_screen.dart';
import 'package:room_rental/features/home_shell.dart';
import 'package:room_rental/main.dart';

/// End-to-end smoke test that runs the real widget tree on a device or
/// simulator. With no Supabase credentials the service falls back to its
/// built-in offline mock backend, so no network or account is needed.
///
///   `flutter test integration_test -d DEVICE_ID`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SupabaseService.instance.initialize();
  });

  Future<void> launchAndSignOut(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RoomRentalApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // The mock backend starts with a seeded owner already signed in.
    expect(find.byType(HomeShell), findsOneWidget);

    final container = ProviderScope.containerOf(
        tester.element(find.byType(RoomRentalApp)));
    await container.read(authProvider.notifier).logout();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(AuthScreen), findsOneWidget);
  }

  Future<void> submitCredentials(WidgetTester tester, String email) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'), email);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('owner signs out and signs back in to the home shell',
      (tester) async {
    await launchAndSignOut(tester);

    await submitCredentials(tester, 'owner1@test.com');

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('unknown email stays on the sign in screen', (tester) async {
    await launchAndSignOut(tester);

    await submitCredentials(tester, 'nobody@example.com');

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });
}
