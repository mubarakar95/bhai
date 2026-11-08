import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:room_rental/core/models/models.dart';
import 'package:room_rental/core/providers/app_providers.dart';
import 'package:room_rental/features/auth/presentation/update_phone_number_screen.dart';

// Test notifier that provides a mock owner with a placeholder phone number
class TestAuthNotifier extends AuthNotifier {
  final Owner testOwner;
  TestAuthNotifier(this.testOwner) : super() {
    state = AsyncValue.data(testOwner);
  }

  @override
  Future<String?> updateProfile({
    String? fullName,
    String? businessName,
    String? businessAddress,
    String? mobileNo,
    String? avatarUrl,
  }) async {
    state = AsyncValue.data(
      Owner(
        id: testOwner.id,
        fullName: fullName ?? testOwner.fullName,
        businessName: businessName ?? testOwner.businessName,
        businessAddress: businessAddress ?? testOwner.businessAddress,
        mobileNo: mobileNo ?? testOwner.mobileNo,
        email: testOwner.email,
        subscriptionPlan: testOwner.subscriptionPlan,
        createdAt: testOwner.createdAt,
      ),
    );
    return null;
  }
}

void main() {
  testWidgets('UpdatePhoneNumberScreen displays placeholder warning and validates input',
      (WidgetTester tester) async {
    final placeholderOwner = Owner(
      id: 'test-migrated-uid',
      fullName: 'Ajmal Khan',
      mobileNo: '9000000008',
      email: 'ajmal123@gmail.com',
      subscriptionPlan: 'free',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => TestAuthNotifier(placeholderOwner)),
        ],
        child: const MaterialApp(
          home: UpdatePhoneNumberScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and user context
    expect(find.text('Update Mobile Number'), findsOneWidget);
    expect(find.textContaining('Welcome Ajmal Khan!'), findsOneWidget);
    expect(find.textContaining('Temporary placeholder: 9000000008'), findsOneWidget);
    expect(find.text('Save & Continue'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);

    // Ensure Save button is visible in scroll view
    final saveButton = find.text('Save & Continue');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Mobile number is required'), findsOneWidget);

    // Try typing another placeholder or invalid number
    final textInput = find.byType(TextFormField);
    await tester.enterText(textInput, '9000000099');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Please enter your actual active personal mobile number'), findsOneWidget);

    // Try typing a valid 10-digit number
    await tester.enterText(textInput, '9876543210');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify no validation error is shown
    expect(find.text('Mobile number is required'), findsNothing);
    expect(find.text('Please enter your actual active personal mobile number'), findsNothing);
  });
}
