import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/models/models.dart';
import 'package:room_rental/core/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Room Transfer & Occupancy Reconciliation Tests', () {
    final dbService = SupabaseService.instance;

    setUpAll(() async {
      await dbService.initialize();
    });

    test('reconcileRoomsWithActiveStays corrects room occupancy discrepancy', () async {
      final propId = 'a1111111-1111-1111-1111-111111111111';
      final rooms = await dbService.getRooms(propId);
      expect(rooms, isNotEmpty);

      // Create a simulated room with incorrect occupancy (e.g. 5/6 when actual active stays is 1 or 0)
      final testRoom = Room(
        id: 'room-simulated-mismatch',
        propertyId: propId,
        roomNumber: '999',
        capacity: 6,
        currentOccupancy: 5, // Erroneous occupancy counter
        rentalType: 'monthly',
        dailyRate: 300,
        monthlyRate: 7000,
        hourlyRate: 50,
        minimumDays: 0,
        minimumCharge: 0,
        status: RoomStatus.available,
        photos: [],
        createdAt: DateTime.now(),
      );

      final reconciled = dbService.reconcileRoomsWithActiveStays([testRoom], propertyId: propId);
      expect(reconciled.first.currentOccupancy, equals(0)); // Reconciled to true 0 active occupants
      expect(reconciled.first.status, equals(RoomStatus.available));
    });

    test('transferStayRoom transfers stay and updates occupancy between rooms', () async {
      final stayId = 's1111111-1111-1111-1111-111111111111';
      final propId = 'a1111111-1111-1111-1111-111111111111';
      final targetRoomId = 'r2222222-2222-2222-2222-222222222222';

      final initialRooms = await dbService.getRooms(propId);
      final sourceRoom = initialRooms.firstWhere((r) => r.id == 'r1111111-1111-1111-1111-111111111111');
      final targetRoomBefore = initialRooms.firstWhere((r) => r.id == targetRoomId);

      final initialSourceOcc = sourceRoom.currentOccupancy;
      final initialTargetOcc = targetRoomBefore.currentOccupancy;

      // Transfer stay from room1 to room2
      await dbService.transferStayRoom(
        stayId: stayId,
        targetPropertyId: propId,
        targetRoomId: targetRoomId,
        newRate: 9500.0,
        newBillingType: RentalBillingType.monthly,
      );

      final stays = await dbService.getStays();
      final updatedStay = stays.firstWhere((s) => s.id == stayId);
      expect(updatedStay.roomId, equals(targetRoomId));
      expect(updatedStay.agreedRate, equals(9500.0));

      final updatedRooms = await dbService.getRooms(propId);
      final updatedSourceRoom = updatedRooms.firstWhere((r) => r.id == sourceRoom.id);
      final updatedTargetRoom = updatedRooms.firstWhere((r) => r.id == targetRoomId);

      expect(updatedSourceRoom.currentOccupancy, equals(initialSourceOcc - 1));
      expect(updatedTargetRoom.currentOccupancy, equals(initialTargetOcc + 1));
    });

    test('Owner business address can be updated and persisted in profile', () async {
      await dbService.updateOwnerProfile(
        businessName: 'Apex Luxury PG',
        businessAddress: 'Sector 62, Noida, UP - 201301',
      );

      final owner = await dbService.getOwnerProfile();
      expect(owner, isNotNull);
      expect(owner!.businessName, equals('Apex Luxury PG'));
      expect(owner.businessAddress, equals('Sector 62, Noida, UP - 201301'));
    });
  });
}
