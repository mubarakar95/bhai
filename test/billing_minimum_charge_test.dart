import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/models/models.dart';
import 'package:room_rental/core/services/supabase_service.dart';

void main() {
  group('Room Minimum Days & Minimum Charge Billing Tests', () {
    final dbService = SupabaseService.instance;

    test('Short stay <= minDays charges only minimum charge (e.g. 5 days <= 15 days)', () {
      final due = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 5,
        minDays: 15,
        minCharge: 500.0,
      );
      expect(due, equals(500.0));
    });

    test('Exact boundary stay == minDays charges minimum charge (e.g. 15 days == 15 days)', () {
      final due = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 15,
        minDays: 15,
        minCharge: 500.0,
      );
      expect(due, equals(500.0));
    });

    test('Stay > minDays in month 1 charges full monthly tariff (e.g. 16 days > 15 days)', () {
      final due = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 16,
        minDays: 15,
        minCharge: 500.0,
      );
      expect(due, equals(5000.0));
    });

    test('Stay of exactly 30 days charges 1 full month', () {
      final due = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 30,
        minDays: 15,
        minCharge: 500.0,
      );
      expect(due, equals(5000.0));
    });

    test('Multi-month stay: 35 days (1 month + 5 days <= 15 days) charges 1 month + min charge', () {
      final due = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 35,
        minDays: 15,
        minCharge: 500.0,
      );
      expect(due, equals(5500.0));
    });

    test('Multi-month stay: 45 days (1 month + 15 days == 15 days) charges 1 month + min charge', () {
      final due = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 45,
        minDays: 15,
        minCharge: 500.0,
      );
      expect(due, equals(5500.0));
    });

    test('Multi-month stay: 46 days (1 month + 16 days > 15 days) charges 2 full months', () {
      final due = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 46,
        minDays: 15,
        minCharge: 500.0,
      );
      expect(due, equals(10000.0));
    });

    test('When minDays is 0 or minCharge is 0 (disabled), standard monthly billing applies', () {
      final dueShort = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 5,
        minDays: 0,
        minCharge: 0.0,
      );
      expect(dueShort, equals(5000.0)); // standard full month

      final dueMulti = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 35,
        minDays: 0,
        minCharge: 0.0,
      );
      expect(dueMulti, equals(10000.0)); // standard 2 months
    });

    test('Room model serialization and deserialization preserves minimumDays and minimumCharge', () {
      final room = Room(
        id: 'room-101',
        propertyId: 'prop-1',
        roomNumber: '101',
        capacity: 2,
        currentOccupancy: 0,
        rentalType: 'monthly',
        dailyRate: 0.0,
        monthlyRate: 6000.0,
        hourlyRate: 0.0,
        minimumDays: 15,
        minimumCharge: 500.0,
        status: RoomStatus.available,
        photos: [],
        createdAt: DateTime(2026, 11, 4),
      );

      final json = room.toJson();
      expect(json['minimum_days'], equals(15));
      expect(json['minimum_charge'], equals(500.0));

      final restored = Room.fromJson(json);
      expect(restored.minimumDays, equals(15));
      expect(restored.minimumCharge, equals(500.0));
      expect(restored.monthlyRate, equals(6000.0));
    });
  });
}
