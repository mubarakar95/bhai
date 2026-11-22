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
      expect(dueShort, equals(2500.0)); // short stay (<=15 days) = half a month

      final dueMulti = dbService.calculateMonthlyRentDue(
        agreedRate: 5000.0,
        stayDays: 35,
        minDays: 0,
        minCharge: 0.0,
      );
      expect(dueMulti, equals(7500.0)); // 35 days = 1 month + half a month
    });

    test('Blank room values fall back to the defaults (15 days, half the rent)', () {
      double due(int days) => dbService.calculateMonthlyRentDue(
          agreedRate: 8000.0, stayDays: days, minDays: 0, minCharge: 0.0);
      expect(due(2), 4000.0);
      expect(due(15), 4000.0);
      expect(due(16), 8000.0);
    });

    test('Room-specific values override the defaults', () {
      double due(int days) => dbService.calculateMonthlyRentDue(
          agreedRate: 8000.0, stayDays: days, minDays: 7, minCharge: 1000.0);
      expect(due(7), 1000.0);
      expect(due(8), 8000.0);
      expect(due(31), 8000.0); // day 31 is still one month
      expect(due(37), 9000.0); // 1 month + 7 extra days -> + minimum charge
      expect(due(38), 16000.0); // 8 extra days -> a full 2nd month
    });

    test('Standard monthly rule: 30-day cycles with half-month step (rate 6000)', () {
      double due(int days) => dbService.calculateMonthlyRentDue(
            agreedRate: 6000.0, stayDays: days, minDays: 0, minCharge: 0.0);

      // short stay: up to 15 days = half a month
      expect(due(1), 3000.0);
      expect(due(2), 3000.0);
      expect(due(15), 3000.0);
      // first cycle
      expect(due(16), 6000.0);
      expect(due(30), 6000.0);
      expect(due(31), 6000.0); // the 31st day is still 1 month
      // 32..45 days -> 1 month + half
      expect(due(32), 9000.0);
      expect(due(45), 9000.0);
      // 46th day -> full 2nd month
      expect(due(46), 12000.0);
      expect(due(60), 12000.0);
      // pattern repeats every 30 days
      expect(due(61), 12000.0);
      expect(due(62), 15000.0);
      expect(due(75), 15000.0);
      expect(due(76), 18000.0);
      expect(due(91), 18000.0);
      expect(due(92), 21000.0);
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
