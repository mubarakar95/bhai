import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:room_rental/core/models/models.dart';
import 'package:room_rental/core/providers/app_providers.dart';
import 'package:room_rental/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

Owner _owner({String mobile = '9876543210'}) => Owner(
      id: 'owner-1',
      fullName: 'Rajesh Kumar',
      businessName: 'Royal PG',
      mobileNo: mobile,
      email: 'owner@example.com',
      subscriptionPlan: 'free',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late MockSupabaseService db;

  /// Builds a notifier that runs in "mock backend" mode, so no Supabase
  /// client or network is touched, and waits for its first profile load.
  Future<AuthNotifier> createNotifier({Owner? initialOwner}) async {
    when(() => db.isUsingMock).thenReturn(true);
    when(() => db.getOwnerProfile()).thenAnswer((_) async => initialOwner);
    final notifier = AuthNotifier(service: db);
    await notifier.checkCurrentUser();
    return notifier;
  }

  setUp(() {
    db = MockSupabaseService();
  });

  group('AuthNotifier.login', () {
    test('loads the owner profile after a successful sign in', () async {
      final notifier = await createNotifier();
      when(() => db.signIn('owner@example.com', 'secret'))
          .thenAnswer((_) async => true);
      when(() => db.getOwnerProfile()).thenAnswer((_) async => _owner());

      final error = await notifier.login('owner@example.com', 'secret');

      expect(error, isNull);
      expect(notifier.state.value?.id, 'owner-1');
      verify(() => db.signIn('owner@example.com', 'secret')).called(1);
    });

    test('returns a friendly message when credentials are rejected', () async {
      final notifier = await createNotifier();
      when(() => db.signIn(any(), any())).thenAnswer((_) async => false);

      final error = await notifier.login('owner@example.com', 'wrong');

      expect(error, 'Invalid email or password. Please try again.');
      expect(notifier.state.value, isNull);
    });

    test('maps network failures to a connectivity message', () async {
      final notifier = await createNotifier();
      when(() => db.signIn(any(), any()))
          .thenThrow(const SocketException('Failed host lookup'));

      final error = await notifier.login('owner@example.com', 'secret');

      expect(error, startsWith('Network error'));
    });

    test('surfaces the message from an AuthException', () async {
      final notifier = await createNotifier();
      when(() => db.signIn(any(), any()))
          .thenThrow(const AuthException('Email not confirmed'));

      final error = await notifier.login('owner@example.com', 'secret');

      expect(error, 'Email not confirmed');
    });
  });

  group('AuthNotifier session handling', () {
    test('starts signed out when there is no profile', () async {
      final notifier = await createNotifier();

      expect(notifier.state.hasValue, isTrue);
      expect(notifier.state.value, isNull);
    });

    test('logout clears the owner and signs out of the backend', () async {
      final notifier = await createNotifier(initialOwner: _owner());
      when(() => db.signOut()).thenAnswer((_) async {});

      await notifier.logout();

      expect(notifier.state.value, isNull);
      verify(() => db.signOut()).called(1);
    });

    test('logout failure keeps the user signed in and rethrows', () async {
      // e.g. there are unsynced changes: the user must not be signed out silently.
      final notifier = await createNotifier(initialOwner: _owner());
      when(() => db.signOut()).thenThrow(Exception('boom'));

      await expectLater(notifier.logout(), throwsException);

      expect(notifier.state.hasError, isFalse);
      expect(notifier.state.value, isNotNull);
    });

    test('deleteAccount failure keeps the user signed in and rethrows', () async {
      final notifier = await createNotifier(initialOwner: _owner());
      when(() => db.deleteAccount()).thenThrow(Exception('server said no'));

      await expectLater(notifier.deleteAccount(), throwsException);

      expect(notifier.state.value, isNotNull);
    });

    test('deleteAccount success signs the user out', () async {
      final notifier = await createNotifier(initialOwner: _owner());
      when(() => db.deleteAccount()).thenAnswer((_) async {});

      await notifier.deleteAccount();

      expect(notifier.state.value, isNull);
    });

    test('updateProfile saves changes then refreshes the owner', () async {
      final notifier = await createNotifier(initialOwner: _owner());
      when(() => db.updateOwnerProfile(
            fullName: any(named: 'fullName'),
            businessName: any(named: 'businessName'),
            businessAddress: any(named: 'businessAddress'),
            mobileNo: any(named: 'mobileNo'),
            avatarUrl: any(named: 'avatarUrl'),
          )).thenAnswer((_) async {});
      when(() => db.getOwnerProfile())
          .thenAnswer((_) async => _owner(mobile: '9123456780'));

      final error = await notifier.updateProfile(mobileNo: '9123456780');

      expect(error, isNull);
      expect(notifier.state.value?.mobileNo, '9123456780');
      verify(() => db.updateOwnerProfile(
            fullName: null,
            businessName: null,
            businessAddress: null,
            mobileNo: '9123456780',
            avatarUrl: null,
          )).called(1);
    });

    test('updateProfile reports network errors', () async {
      final notifier = await createNotifier(initialOwner: _owner());
      when(() => db.updateOwnerProfile(
            fullName: any(named: 'fullName'),
            businessName: any(named: 'businessName'),
            businessAddress: any(named: 'businessAddress'),
            mobileNo: any(named: 'mobileNo'),
            avatarUrl: any(named: 'avatarUrl'),
          )).thenThrow(const SocketException('Failed host lookup'));

      final error = await notifier.updateProfile(fullName: 'New Name');

      expect(error, startsWith('Network error'));
    });
  });

  test('authProvider can be overridden with an injected service', () async {
    when(() => db.isUsingMock).thenReturn(true);
    when(() => db.getOwnerProfile()).thenAnswer((_) async => _owner());
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => AuthNotifier(service: db)),
    ]);
    addTearDown(container.dispose);

    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authProvider).value?.fullName, 'Rajesh Kumar');
  });
}
