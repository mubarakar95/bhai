import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Check-In Date Selection & Update Tests', () {
    final dbService = SupabaseService.instance;

    setUpAll(() async {
      await dbService.initialize();
    });

    test('updateStayCheckInDate updates stay check-in date', () async {
      final stayId = 's1111111-1111-1111-1111-111111111111';

      // Backdate check-in to 40 days ago (previously impossible with 30-day limit)
      final backdatedCheckIn = DateTime.now().subtract(const Duration(days: 40));
      await dbService.updateStayCheckInDate(stayId, backdatedCheckIn);

      final stays = await dbService.getStays();
      final updatedStay = stays.firstWhere((s) => s.id == stayId);
      expect(updatedStay.checkInDate.year, equals(backdatedCheckIn.year));
      expect(updatedStay.checkInDate.month, equals(backdatedCheckIn.month));
      expect(updatedStay.checkInDate.day, equals(backdatedCheckIn.day));
    });

    test('Date picker range bounds clamp safely', () {
      final now = DateTime.now();
      final firstDate = DateTime(2000, 1, 1);
      final lastDate = now.add(const Duration(days: 365 * 2));

      // Test clamping
      final dateTooOld = DateTime(1990, 5, 1);
      final clampedOld = dateTooOld.isBefore(firstDate)
          ? firstDate
          : (dateTooOld.isAfter(lastDate) ? lastDate : dateTooOld);
      expect(clampedOld, equals(firstDate));

      final dateTooFar = now.add(const Duration(days: 365 * 10));
      final clampedFar = dateTooFar.isBefore(firstDate)
          ? firstDate
          : (dateTooFar.isAfter(lastDate) ? lastDate : dateTooFar);
      expect(clampedFar, equals(lastDate));

      final normalPastDate = DateTime(2023, 6, 15);
      final clampedNormal = normalPastDate.isBefore(firstDate)
          ? firstDate
          : (normalPastDate.isAfter(lastDate) ? lastDate : normalPastDate);
      expect(clampedNormal, equals(normalPastDate));
    });

    test('Recalculates dues based on backdated check-in date', () {
      // 5 days stay vs 45 days stay
      final rentDue5Days = dbService.calculateMonthlyRentDue(
        agreedRate: 6000.0,
        stayDays: 5,
        minDays: 0,
        minCharge: 0.0,
      );
      // Month 1 (<30 days) is 1 full month = 6000
      expect(rentDue5Days, equals(6000.0));

      final rentDue45Days = dbService.calculateMonthlyRentDue(
        agreedRate: 6000.0,
        stayDays: 45,
        minDays: 0,
        minCharge: 0.0,
      );
      // 45 days = 1 month + 15 days = 2 full months = 12000
      expect(rentDue45Days, equals(12000.0));
    });
  });
}
