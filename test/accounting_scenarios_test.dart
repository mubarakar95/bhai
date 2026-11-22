import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/models/models.dart';
import 'package:room_rental/core/services/supabase_service.dart';

/// End-to-end accounting scenarios that run through the real service code
/// (addStay / addPayment / checkOutStay / billing calculation) in demo mode.
///
/// Sign convention of BillingSummary.pendingAmount:
///   > 0  -> owner still has to RECEIVE money from the guest
///   < 0  -> owner has to GIVE money back to the guest (e.g. advance not used up)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final db = SupabaseService.instance;
  const propId = 'a1111111-1111-1111-1111-111111111111';
  late String roomId;
  late String personId;
  var seq = 0;

  setUpAll(() async {
    await db.initialize();
    final rooms = await db.getRooms(propId);
    roomId = rooms.first.id;
    personId = db.allCachedPersons.first.id;
  });

  Future<Stay> checkIn({
    required Duration agoIn,
    double rate = 5000,
    RentalBillingType type = RentalBillingType.monthly,
  }) async {
    seq++;
    // demo-mode ids are millisecond timestamps; avoid two stays sharing one id
    await Future.delayed(const Duration(milliseconds: 3));
    return db.addStay(Stay(
      id: '',
      personId: personId,
      roomId: roomId,
      propertyId: propId,
      ownerId: '',
      checkInDate: DateTime.now().subtract(agoIn),
      rentalTypeUsed: type,
      agreedRate: rate,
      status: 'active',
      createdAt: DateTime.now(),
    ));
  }

  Future<void> pay(Stay s, PaymentCategory type, double amount) async {
    await db.addPayment(Payment(
      id: '',
      stayId: s.id,
      personId: s.personId,
      ownerId: '',
      paymentType: type,
      amount: amount,
      paymentMode: 'cash',
      paidAt: DateTime.now(),
      recordedBy: '',
      createdAt: DateTime.now(),
    ));
  }

  BillingSummary bill(Stay s) => db.getLocalBillingSummary(s.id);

  group('Guest pays advance, stays, leaves', () {
    test('advance covers the first month exactly -> nothing pending', () async {
      final s = await checkIn(agoIn: const Duration(days: 20));
      await pay(s, PaymentCategory.advance, 5000);
      final b = bill(s);
      expect(b.totalAmountDue, 5000);
      expect(b.totalPaid, 5000);
      expect(b.pendingAmount, 0);
    });

    test('OWNER GIVES BACK: advance + deposit larger than rent -> negative pending = refund due', () async {
      final s = await checkIn(agoIn: const Duration(days: 20));
      await pay(s, PaymentCategory.deposit, 3000);
      await pay(s, PaymentCategory.advance, 5000);
      await db.checkOutStay(s.id, DateTime.now());
      final b = bill(s);
      expect(b.totalAmountDue, 5000); // 20 days -> 1 month
      expect(b.pendingAmount, -3000); // owner must give back 3000
    });

    test('refund recorded after checkout settles the ledger to zero', () async {
      final s = await checkIn(agoIn: const Duration(days: 20));
      await pay(s, PaymentCategory.deposit, 3000);
      await pay(s, PaymentCategory.advance, 5000);
      await db.checkOutStay(s.id, DateTime.now());
      await pay(s, PaymentCategory.refund, 3000);
      final b = bill(s);
      expect(b.totalPaid, 5000); // 8000 received - 3000 refunded
      expect(b.pendingAmount, 0);
    });

    test('OWNER RECEIVES: stay costs more than the advance -> positive pending', () async {
      final s = await checkIn(agoIn: const Duration(days: 40));
      await pay(s, PaymentCategory.advance, 5000);
      await db.checkOutStay(s.id, DateTime.now());
      final b = bill(s);
      expect(b.totalAmountDue, 7500); // 40 days -> 1 month + half month
      expect(b.pendingAmount, 2500); // owner still to receive 2500
    });

    test('stay past the 45th day is billed 2 full months', () async {
      final s = await checkIn(agoIn: const Duration(days: 46));
      await pay(s, PaymentCategory.advance, 5000);
      await db.checkOutStay(s.id, DateTime.now());
      expect(bill(s).totalAmountDue, 10000);
      expect(bill(s).pendingAmount, 5000);
    });

    test('partial payment leaves the balance pending', () async {
      final s = await checkIn(agoIn: const Duration(days: 20));
      await pay(s, PaymentCategory.rent, 2000);
      expect(bill(s).pendingAmount, 3000);
    });

    test('nothing paid at all -> full amount pending', () async {
      final s = await checkIn(agoIn: const Duration(days: 20));
      expect(bill(s).pendingAmount, 5000);
    });
  });

  group('Short stays (<= 15 days) are charged half the monthly rent', () {
    test('1 day and 2 day stays pay half rent', () async {
      final one = await checkIn(agoIn: const Duration(hours: 5));
      final two = await checkIn(agoIn: const Duration(days: 1, hours: 6));
      expect(bill(one).totalAmountDue, 2500);
      expect(bill(two).totalAmountDue, 2500);
    });

    test('advance larger than the half rent -> owner gives the rest back', () async {
      final s = await checkIn(agoIn: const Duration(days: 2));
      await pay(s, PaymentCategory.advance, 5000);
      await db.checkOutStay(s.id, DateTime.now());
      expect(bill(s).totalAmountDue, 2500);
      expect(bill(s).pendingAmount, -2500); // owner gives back 2500
    });

    test('day 15 is still half, day 16 is a full month', () async {
      final a = await checkIn(agoIn: const Duration(days: 15)); // day 15
      final b = await checkIn(agoIn: const Duration(days: 16)); // day 16
      expect(bill(a).totalAmountDue, 2500);
      expect(bill(b).totalAmountDue, 5000);
    });
  });

  group('Time accrual', () {
    test('due stops growing after checkout', () async {
      final s = await checkIn(agoIn: const Duration(days: 40));
      await db.checkOutStay(s.id, DateTime.now().subtract(const Duration(days: 10)));
      // stayed 30 days exactly -> 1 month, even though 40 days have passed since check-in
      expect(bill(s).totalAmountDue, 5000);
    });

    test('day 31 is still one month, day 32 adds half a month', () async {
      final a = await checkIn(agoIn: const Duration(days: 31)); // day 31
      final b = await checkIn(agoIn: const Duration(days: 32)); // day 32
      expect(bill(a).totalAmountDue, 5000);
      expect(bill(b).totalAmountDue, 7500);
    });

    test('daily rate rounds up to whole days', () async {
      final s = await checkIn(
          agoIn: const Duration(days: 4), rate: 800, type: RentalBillingType.daily);
      expect(bill(s).totalAmountDue, 3200); // 4 days
    });

    test('hourly rate rounds up to whole hours', () async {
      final s = await checkIn(
          agoIn: const Duration(hours: 2, minutes: 10), rate: 100, type: RentalBillingType.hourly);
      expect(bill(s).totalAmountDue, 300); // 3 hours
    });
  });

  group('Days are counted by calendar date (stable all day)', () {
    test('stayDaysBetween ignores the time of day', () {
      final inAt = DateTime(2026, 1, 1, 23, 59);
      expect(SupabaseService.stayDaysBetween(inAt, DateTime(2026, 1, 1, 23, 59)), 1);
      expect(SupabaseService.stayDaysBetween(inAt, DateTime(2026, 1, 2, 0, 1)), 1);
      expect(SupabaseService.stayDaysBetween(DateTime(2026, 1, 1, 6), DateTime(2026, 1, 31, 22)), 30);
      expect(SupabaseService.stayDaysBetween(DateTime(2026, 1, 1, 6), DateTime(2026, 2, 1, 1)), 31);
      expect(SupabaseService.stayDaysBetween(DateTime(2026, 1, 10), DateTime(2026, 1, 9)), 1); // never < 1
    });

    test('the daily calculation only runs against a real backend (demo mode skips it)', () async {
      expect(await db.runDailyCalculationIfNeeded(), isFalse);
    });
  });

  group('Edge cases around the 30-day boundary', () {
    test('leaving a few minutes after the 30-day mark is still 1 month (day-31 grace)', () async {
      final s = await checkIn(agoIn: const Duration(days: 30, minutes: 5));
      await db.checkOutStay(s.id, DateTime.now());
      expect(bill(s).totalAmountDue, 5000);
    });
  });
}
