import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../models/subscription_plan.dart';
import '../utils/image_optimizer.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  bool _useMock = true;
  bool get isUsingMock => _useMock;

  // Local Mock Data Stores
  final List<Owner> _mockOwners = [];
  final List<Property> _mockProperties = [];
  final List<Room> _mockRooms = [];
  final List<Person> _mockPersons = [];
  final List<Stay> _mockStays = [];
  final List<Payment> _mockPayments = [];
  final List<BillingSummary> _mockBillingSummaries = [];
  final List<ReportsLog> _mockReportsLog = [];

  // Offline Real-Mode Cache Stores
  Owner? _cachedOwner;
  final List<Property> _cachedProperties = [];
  final Map<String, List<Room>> _cachedRooms = {};
  final List<Person> _cachedPersons = [];
  final List<Stay> _cachedStays = [];
  final Map<String, List<Payment>> _cachedPayments = {};
  final List<Map<String, dynamic>> _pendingSyncQueue = [];

  DateTime? _lastPropertiesSync;
  DateTime? _lastStaysSync;
  final Map<String, DateTime> _lastRoomsSync = {};
  final Map<String, DateTime> _lastPaymentsSync = {};

  int get pendingSyncCount => _pendingSyncQueue.length;
  List<Person> get allCachedPersons => _useMock ? List.unmodifiable(_mockPersons) : List.unmodifiable(_cachedPersons);

  String? _currentOwnerId;

  Future<void> initialize({String? url, String? anonKey}) async {
    // Always load offline persistent cache on startup
    await _loadOfflineDataFromDisk();

    if (url != null && anonKey != null && url.isNotEmpty && anonKey.isNotEmpty && !url.contains('YOUR_')) {
      try {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
        );
        _useMock = false;
        // Trigger non-blocking sync queue flush in the background
        _processPendingSyncQueue();
        // Periodic background cloud sync timer (every 3 minutes)
        Timer.periodic(const Duration(minutes: 3), (timer) {
          if (!_useMock && _pendingSyncQueue.isNotEmpty) {
            _processPendingSyncQueue();
          }
        });
      } catch (e) {
        debugPrint('Supabase init failed, falling back to mock: $e');
        _useMock = true;
        await _loadMockDataFromDisk();
      }
    } else {
      _useMock = true;
      await _loadMockDataFromDisk();
    }
  }

  void _setupMockData() {
    _mockOwners.clear();
    _mockProperties.clear();
    _mockRooms.clear();
    _mockPersons.clear();
    _mockStays.clear();
    _mockPayments.clear();
    _mockBillingSummaries.clear();
    _mockReportsLog.clear();

    // Add Mock Owner
    _currentOwnerId = '11111111-1111-1111-1111-111111111111';
    _mockOwners.add(Owner(
      id: _currentOwnerId!,
      fullName: 'Rajesh Kumar',
      businessName: 'Royal PG & Hostels',
      businessAddress: 'Plot 45, Sector 62, Noida, Uttar Pradesh - 201301',
      mobileNo: '+919876543210',
      email: 'owner1@test.com',
      subscriptionPlan: 'free',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ));

    // Add Mock Properties
    final prop1 = Property(
      id: 'a1111111-1111-1111-1111-111111111111',
      ownerId: _currentOwnerId!,
      name: 'Royal PG Sector 62',
      address: 'Plot 45, Sector 62',
      city: 'Noida',
      state: 'Uttar Pradesh',
      pincode: '201301',
      propertyType: 'PG',
      contactNo: '+919876543210',
      photos: ['https://images.unsplash.com/photo-1555854877-bab0e564b8d5'],
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    _mockProperties.add(prop1);

    // Add Mock Rooms
    final room1 = Room(
      id: 'r1111111-1111-1111-1111-111111111111',
      propertyId: prop1.id,
      roomNumber: '101-A',
      capacity: 2,
      currentOccupancy: 1,
      rentalType: 'monthly',
      dailyRate: 0.00,
      monthlyRate: 0.00,
      hourlyRate: 0.00,
      status: RoomStatus.available,
      photos: [],
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    final room2 = Room(
      id: 'r2222222-2222-2222-2222-222222222222',
      propertyId: prop1.id,
      roomNumber: '102-B',
      capacity: 1,
      currentOccupancy: 1,
      rentalType: 'monthly',
      dailyRate: 0.00,
      monthlyRate: 0.00,
      hourlyRate: 0.00,
      status: RoomStatus.full,
      photos: [],
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    _mockRooms.addAll([room1, room2]);

    // Add Mock Persons
    final guest1 = Person(
      id: 'g1111111-1111-1111-1111-111111111111',
      name: 'Amit Sharma',
      mobileNo: '+919999999901',
      aadhaarNo: '123456789012',
      fatherName: 'Vijay Sharma',
      policeStationCircle: 'Sector 58 Police Station',
      address: 'Sector 15, Near Metro',
      city: 'Noida',
      state: 'Uttar Pradesh',
      pincode: '201301',
      dob: DateTime(1995, 5, 15),
      isBlacklisted: false,
      createdByOwnerId: _currentOwnerId!,
      personPhoto: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );
    final guest2 = Person(
      id: 'g2222222-2222-2222-2222-222222222222',
      name: 'Rohan Verma',
      mobileNo: '+919999999902',
      aadhaarNo: '987654321098',
      fatherName: 'Suresh Verma',
      policeStationCircle: 'Indiranagar Police Station',
      address: 'Koramangala 4th Block',
      city: 'Bengaluru',
      state: 'Karnataka',
      pincode: '560034',
      dob: DateTime(1998, 11, 20),
      isBlacklisted: false,
      createdByOwnerId: _currentOwnerId!,
      personPhoto: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    );
    final guest3 = Person(
      id: 'g3333333-3333-3333-3333-333333333333',
      name: 'Vijay Mallya',
      mobileNo: '+919999999903',
      aadhaarNo: '111122223333',
      fatherName: 'Vittal Mallya',
      policeStationCircle: 'CBI Special Circle',
      address: 'UB City, Lavelle Road',
      city: 'Bengaluru',
      state: 'Karnataka',
      pincode: '560001',
      dob: DateTime(1955, 12, 18),
      isBlacklisted: true,
      blacklistReason: 'Absconded with dues and property damage',
      blacklistedBy: _currentOwnerId,
      blacklistedAt: DateTime.now().subtract(const Duration(days: 20)),
      createdByOwnerId: '22222222-2222-2222-2222-222222222222',
      personPhoto: 'https://images.unsplash.com/photo-1560250097-0b93528c311a',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    _mockPersons.addAll([guest1, guest2, guest3]);

    // Add Mock Stays
    final stay1 = Stay(
      id: 's1111111-1111-1111-1111-111111111111',
      personId: guest1.id,
      roomId: room1.id,
      propertyId: prop1.id,
      ownerId: _currentOwnerId!,
      checkInDate: DateTime.now().subtract(const Duration(days: 5)),
      rentalTypeUsed: RentalBillingType.monthly,
      agreedRate: 8000.00,
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      person: guest1,
      room: room1,
    );
    final stay2 = Stay(
      id: 's2222222-2222-2222-2222-222222222222',
      personId: guest2.id,
      roomId: room2.id,
      propertyId: prop1.id,
      ownerId: _currentOwnerId!,
      checkInDate: DateTime.now().subtract(const Duration(days: 45)),
      checkOutDate: DateTime.now().subtract(const Duration(days: 15)),
      rentalTypeUsed: RentalBillingType.monthly,
      agreedRate: 10000.00,
      status: 'checked_out',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      person: guest2,
      room: room2,
    );
    _mockStays.addAll([stay1, stay2]);

    // Add Mock Payments
    _mockPayments.add(Payment(
      id: 'p1111111-1111-1111-1111-111111111111',
      stayId: stay1.id,
      personId: guest1.id,
      ownerId: _currentOwnerId!,
      paymentType: PaymentCategory.deposit,
      amount: 2000.00,
      paymentMode: 'upi',
      paidAt: DateTime.now().subtract(const Duration(days: 5)),
      notes: 'Security deposit',
      recordedBy: _currentOwnerId!,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ));
    _mockPayments.add(Payment(
      id: 'p2222222-2222-2222-2222-222222222222',
      stayId: stay1.id,
      personId: guest1.id,
      ownerId: _currentOwnerId!,
      paymentType: PaymentCategory.advance,
      amount: 3000.00,
      paymentMode: 'upi',
      paidAt: DateTime.now().subtract(const Duration(days: 5)),
      notes: 'Rent advance',
      recordedBy: _currentOwnerId!,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ));

    _mockPayments.add(Payment(
      id: 'p3333333-3333-3333-3333-333333333333',
      stayId: stay2.id,
      personId: guest2.id,
      ownerId: _currentOwnerId!,
      paymentType: PaymentCategory.deposit,
      amount: 5000.00,
      paymentMode: 'bank_transfer',
      paidAt: DateTime.now().subtract(const Duration(days: 45)),
      notes: 'Deposit',
      recordedBy: _currentOwnerId!,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ));
    _mockPayments.add(Payment(
      id: 'p4444444-4444-4444-4444-444444444444',
      stayId: stay2.id,
      personId: guest2.id,
      ownerId: _currentOwnerId!,
      paymentType: PaymentCategory.rent,
      amount: 10000.00,
      paymentMode: 'cash',
      paidAt: DateTime.now().subtract(const Duration(days: 15)),
      notes: 'Full month rent payment & settlement',
      recordedBy: _currentOwnerId!,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ));
    _mockPayments.add(Payment(
      id: 'p5555555-5555-5555-5555-555555555555',
      stayId: stay2.id,
      personId: guest2.id,
      ownerId: _currentOwnerId!,
      paymentType: PaymentCategory.refund,
      amount: 5000.00,
      paymentMode: 'upi',
      paidAt: DateTime.now().subtract(const Duration(days: 15)),
      notes: 'Refund of deposit at checkout',
      recordedBy: _currentOwnerId!,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ));

    _recalculateMockBilling(stay1.id);
    _recalculateMockBilling(stay2.id);
  }

  Future<void> _loadMockDataFromDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mock_db.json');
      if (!await file.exists()) {
        _setupMockData();
        await _saveMockDataToDisk();
        return;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        _setupMockData();
        await _saveMockDataToDisk();
        return;
      }

      final data = jsonDecode(content) as Map<String, dynamic>;

      _mockOwners.clear();
      _mockProperties.clear();
      _mockRooms.clear();
      _mockPersons.clear();
      _mockStays.clear();
      _mockPayments.clear();
      _mockBillingSummaries.clear();

      _currentOwnerId = data['current_owner_id'] as String?;
      if (_currentOwnerId == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          _currentOwnerId = prefs.getString('persisted_mock_owner_id');
        } catch (_) {}
      }

      if (data['owners'] != null) {
        for (var json in (data['owners'] as List)) {
          _mockOwners.add(Owner.fromJson(Map<String, dynamic>.from(json)));
        }
      }

      if (data['properties'] != null) {
        for (var json in (data['properties'] as List)) {
          _mockProperties.add(Property.fromJson(Map<String, dynamic>.from(json)));
        }
      }

      if (data['rooms'] != null) {
        for (var json in (data['rooms'] as List)) {
          _mockRooms.add(Room.fromJson(Map<String, dynamic>.from(json)));
        }
      }

      if (data['persons'] != null) {
        for (var json in (data['persons'] as List)) {
          _mockPersons.add(Person.fromJson(Map<String, dynamic>.from(json)));
        }
      }

      if (data['stays'] != null) {
        for (var json in (data['stays'] as List)) {
          final map = Map<String, dynamic>.from(json);
          final stay = Stay.fromJson(map);
          final person = _mockPersons.firstWhere(
            (p) => p.id == stay.personId,
            orElse: () => stay.person ?? Person(
              id: stay.personId,
              name: 'Guest',
              mobileNo: '',
              aadhaarNo: '',
              fatherName: '',
              policeStationCircle: '',
              personPhoto: '',
              address: '',
              city: '',
              state: '',
              pincode: '',
              dob: DateTime.now(),
              isBlacklisted: false,
              createdByOwnerId: stay.ownerId,
              createdAt: DateTime.now(),
            ),
          );
          final room = _mockRooms.firstWhere(
            (r) => r.id == stay.roomId,
            orElse: () => stay.room ?? Room(
              id: stay.roomId,
              propertyId: stay.propertyId,
              roomNumber: 'N/A',
              capacity: 1,
              currentOccupancy: 0,
              rentalType: 'monthly',
              dailyRate: 0,
              monthlyRate: 0,
              hourlyRate: 0,
              status: RoomStatus.available,
              photos: [],
              createdAt: DateTime.now(),
            ),
          );
          _mockStays.add(Stay(
            id: stay.id,
            personId: stay.personId,
            roomId: stay.roomId,
            propertyId: stay.propertyId,
            ownerId: stay.ownerId,
            checkInDate: stay.checkInDate,
            checkOutDate: stay.checkOutDate,
            rentalTypeUsed: stay.rentalTypeUsed,
            agreedRate: stay.agreedRate,
            status: stay.status,
            createdAt: stay.createdAt,
            person: person,
            room: room,
          ));
        }
      }

      if (data['payments'] != null) {
        for (var json in (data['payments'] as List)) {
          _mockPayments.add(Payment.fromJson(Map<String, dynamic>.from(json)));
        }
      }

      for (var stay in _mockStays) {
        _recalculateMockBilling(stay.id);
      }
    } catch (e) {
      debugPrint('Error loading mock data from disk: $e');
      _setupMockData();
      await _saveMockDataToDisk();
    }
  }

  Future<void> _saveMockDataToDisk() async {
    if (!_useMock) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mock_db.json');

      final data = {
        'current_owner_id': _currentOwnerId,
        'owners': _mockOwners.map((o) {
          final m = o.toJson();
          m['created_at'] = o.createdAt.toIso8601String();
          return m;
        }).toList(),
        'properties': _mockProperties.map((p) {
          final m = p.toJson();
          m['id'] = p.id;
          m['created_at'] = p.createdAt.toIso8601String();
          return m;
        }).toList(),
        'rooms': _mockRooms.map((r) {
          final m = r.toJson();
          m['id'] = r.id;
          m['created_at'] = r.createdAt.toIso8601String();
          return m;
        }).toList(),
        'persons': _mockPersons.map((p) {
          final m = p.toJson();
          m['id'] = p.id;
          m['created_at'] = p.createdAt.toIso8601String();
          return m;
        }).toList(),
        'stays': _mockStays.map((s) {
          final m = s.toJson();
          m['id'] = s.id;
          m['created_at'] = s.createdAt.toIso8601String();
          return m;
        }).toList(),
        'payments': _mockPayments.map((p) {
          final m = p.toJson();
          m['id'] = p.id;
          m['created_at'] = p.createdAt.toIso8601String();
          return m;
        }).toList(),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving mock data to disk: $e');
    }
  }

  double calculateMonthlyRentDue({
    required double agreedRate,
    required int stayDays,
    required int minDays,
    required double minCharge,
  }) {
    if (minDays > 0 && minCharge > 0) {
      if (stayDays <= minDays) {
        return minCharge;
      }
      final fullMonths = stayDays ~/ 30;
      final remainderDays = stayDays % 30;
      if (remainderDays == 0) {
        return agreedRate * max(1, fullMonths);
      } else if (remainderDays <= minDays) {
        return (agreedRate * fullMonths) + minCharge;
      } else {
        return agreedRate * (fullMonths + 1);
      }
    } else {
      final months = max(1, (stayDays / 30.0).ceil());
      return agreedRate * months;
    }
  }

  void _recalculateMockBilling(String stayId) {
    final stayIndex = _mockStays.indexWhere((s) => s.id == stayId);
    if (stayIndex == -1) return;
    final stay = _mockStays[stayIndex];

    final now = DateTime.now();
    final checkIn = stay.checkInDate.toLocal();
    final checkOut = (stay.checkOutDate ?? now).toLocal();
    final duration = checkOut.isBefore(checkIn) ? Duration.zero : checkOut.difference(checkIn);
    final totalHours = duration.inSeconds / 3600.0;
    double due = 0.0;
    
    switch (stay.rentalTypeUsed) {
      case RentalBillingType.hourly:
        final hours = max(1.0, totalHours.ceilToDouble());
        due = stay.agreedRate * hours;
        break;
      case RentalBillingType.daily:
        final days = max(1, (totalHours / 24.0).ceil());
        due = stay.agreedRate * days;
        break;
      case RentalBillingType.monthly:
        final room = stay.room ??
            (_mockRooms.where((r) => r.id == stay.roomId).isNotEmpty
                ? _mockRooms.firstWhere((r) => r.id == stay.roomId)
                : null);
        final minDays = room?.minimumDays ?? 0;
        final minCharge = room?.minimumCharge ?? 0.0;
        final stayDays = max(1, (duration.inSeconds / 86400.0).ceil());
        due = calculateMonthlyRentDue(
          agreedRate: stay.agreedRate,
          stayDays: stayDays,
          minDays: minDays,
          minCharge: minCharge,
        );
        break;
    }
    due = max(0.0, due);

    double paid = 0.0;
    for (var p in _mockPayments.where((p) => p.stayId == stayId)) {
      if (p.paymentType == PaymentCategory.refund) {
        paid -= p.amount;
      } else {
        paid += p.amount;
      }
    }

    final summaryIndex = _mockBillingSummaries.indexWhere((s) => s.stayId == stayId);
    final summary = BillingSummary(
      stayId: stayId,
      totalAmountDue: double.parse(due.toStringAsFixed(2)),
      totalPaid: double.parse(paid.toStringAsFixed(2)),
      pendingAmount: double.parse((due - paid).toStringAsFixed(2)),
      lastCalculatedAt: DateTime.now(),
    );

    if (summaryIndex != -1) {
      _mockBillingSummaries[summaryIndex] = summary;
    } else {
      _mockBillingSummaries.add(summary);
    }
  }

  // --- Offline-First Persistence & Sync Engine ---

  Future<void> _loadOfflineDataFromDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_db.json');
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final data = jsonDecode(content) as Map<String, dynamic>;

      if (data['cached_owner'] != null) {
        _cachedOwner = Owner.fromJson(Map<String, dynamic>.from(data['cached_owner']));
      }

      if (data['properties'] != null) {
        _cachedProperties.clear();
        for (var json in (data['properties'] as List)) {
          _cachedProperties.add(Property.fromJson(Map<String, dynamic>.from(json)));
        }
      }

      if (data['rooms'] != null) {
        _cachedRooms.clear();
        final roomsMap = data['rooms'] as Map<String, dynamic>;
        roomsMap.forEach((propId, list) {
          _cachedRooms[propId] = (list as List)
              .map((json) => Room.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        });
      }

      if (data['persons'] != null) {
        _cachedPersons.clear();
        for (var json in (data['persons'] as List)) {
          _cachedPersons.add(Person.fromJson(Map<String, dynamic>.from(json)));
        }
      }

      if (data['stays'] != null) {
        _cachedStays.clear();
        for (var json in (data['stays'] as List)) {
          final s = Stay.fromJson(Map<String, dynamic>.from(json));
          Person? person = s.person;
          if (person == null) {
            final matches = _cachedPersons.where((p) => p.id == s.personId);
            if (matches.isNotEmpty) person = matches.first;
          }
          _cachedStays.add(Stay(
            id: s.id,
            personId: s.personId,
            roomId: s.roomId,
            propertyId: s.propertyId,
            ownerId: s.ownerId,
            checkInDate: s.checkInDate,
            checkOutDate: s.checkOutDate,
            rentalTypeUsed: s.rentalTypeUsed,
            agreedRate: s.agreedRate,
            status: s.status,
            createdAt: s.createdAt,
            person: person,
            room: s.room,
          ));
        }
      }

      if (data['payments'] != null) {
        _cachedPayments.clear();
        final payMap = data['payments'] as Map<String, dynamic>;
        payMap.forEach((stayId, list) {
          _cachedPayments[stayId] = (list as List)
              .map((json) => Payment.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        });
      }

      if (data['pending_sync'] != null) {
        _pendingSyncQueue.clear();
        for (var json in (data['pending_sync'] as List)) {
          _pendingSyncQueue.add(Map<String, dynamic>.from(json));
        }
      }
    } catch (e) {
      debugPrint('Error loading offline cache from disk: $e');
    }
  }

  Future<void> _saveOfflineDataToDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_db.json');

      final roomsJson = <String, dynamic>{};
      _cachedRooms.forEach((key, list) {
        roomsJson[key] = list.map((r) {
          final m = r.toJson();
          m['id'] = r.id;
          m['created_at'] = r.createdAt.toIso8601String();
          return m;
        }).toList();
      });

      final payJson = <String, dynamic>{};
      _cachedPayments.forEach((key, list) {
        payJson[key] = list.map((p) {
          final m = p.toJson();
          m['id'] = p.id;
          m['created_at'] = p.createdAt.toIso8601String();
          return m;
        }).toList();
      });

      final data = {
        'cached_owner': _cachedOwner != null
            ? (() {
                final m = _cachedOwner!.toJson();
                m['created_at'] = _cachedOwner!.createdAt.toIso8601String();
                return m;
              })()
            : null,
        'properties': _cachedProperties.map((p) {
          final m = p.toJson();
          m['id'] = p.id;
          m['created_at'] = p.createdAt.toIso8601String();
          return m;
        }).toList(),
        'rooms': roomsJson,
        'persons': _cachedPersons.map((p) {
          final m = p.toJson();
          m['id'] = p.id;
          m['created_at'] = p.createdAt.toIso8601String();
          return m;
        }).toList(),
        'stays': _cachedStays.map((s) {
          final m = s.toJson();
          m['id'] = s.id;
          m['created_at'] = s.createdAt.toIso8601String();
          return m;
        }).toList(),
        'payments': payJson,
        'pending_sync': _pendingSyncQueue,
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving offline cache to disk: $e');
    }
  }

  void _queuePendingSync({
    required String table,
    required String action,
    String? id,
    Map<String, dynamic> data = const {},
  }) {
    // Only queue items if cloud sync is supported for this account
    if (!isCloudSyncAllowed) return;
    _pendingSyncQueue.add({
      'table': table,
      'action': action,
      'id': id,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _saveOfflineDataToDisk();
  }

  bool get isCloudSyncAllowed {
    final owner = _cachedOwner;
    return SubscriptionPlanConfig.isPaidPlan(owner?.subscriptionPlan) ||
        SubscriptionPlanConfig.isTrialActive(owner);
  }

  Future<int> _processPendingSyncQueue() async {
    if (_useMock || _pendingSyncQueue.isEmpty) return 0;
    // Free tier users do not sync to Cloud
    if (!isCloudSyncAllowed) return 0;
    final toProcess = List<Map<String, dynamic>>.from(_pendingSyncQueue);
    int syncedCount = 0;

    for (var item in toProcess) {
      final table = item['table'] as String;
      final action = item['action'] as String;
      final data = Map<String, dynamic>.from((item['data'] as Map?) ?? {});
      final id = item['id'] as String?;

      if (table == 'stays') {
        data.remove('persons');
        data.remove('rooms');
      }

      try {
        if (action == 'insert') {
          await Supabase.instance.client.from(table).upsert(data);
        } else if (action == 'update' && id != null) {
          await Supabase.instance.client.from(table).update(data).eq('id', id);
        } else if (action == 'delete' && id != null) {
          await Supabase.instance.client.from(table).delete().eq('id', id);
        }
        _pendingSyncQueue.remove(item);
        syncedCount++;
      } catch (e) {
        debugPrint('Pending sync item notice for $table: $e');
        // If it's a schema cache mismatch for nested properties, strip and retry once
        if (table == 'stays' && (data.containsKey('persons') || data.containsKey('rooms'))) {
          data.remove('persons');
          data.remove('rooms');
          try {
            await Supabase.instance.client.from(table).upsert(data);
            _pendingSyncQueue.remove(item);
            syncedCount++;
            continue;
          } catch (_) {}
        }
        // Stop on first persistent failure to keep sequence intact
        break;
      }
    }

    if (syncedCount > 0) {
      await _saveOfflineDataToDisk();
    }
    return syncedCount;
  }

  Future<int> syncPendingData() async {
    if (!isCloudSyncAllowed) return 0;
    return await _processPendingSyncQueue();
  }

  // --- Offline Data Export & Import ---

  Future<String> exportOfflineData() async {
    final roomsJson = <String, dynamic>{};
    _cachedRooms.forEach((key, list) {
      roomsJson[key] = list.map((r) {
        final m = r.toJson();
        m['id'] = r.id;
        m['created_at'] = r.createdAt.toIso8601String();
        return m;
      }).toList();
    });

    final payJson = <String, dynamic>{};
    _cachedPayments.forEach((key, list) {
      payJson[key] = list.map((p) {
        final m = p.toJson();
        m['id'] = p.id;
        m['created_at'] = p.createdAt.toIso8601String();
        return m;
      }).toList();
    });

    final data = {
      'app': 'Bhai App',
      'version': '1.2.1',
      'exported_at': DateTime.now().toIso8601String(),
      'cached_owner': _cachedOwner != null
          ? (() {
              final m = _cachedOwner!.toJson();
              m['created_at'] = _cachedOwner!.createdAt.toIso8601String();
              return m;
            })()
          : null,
      'properties': _cachedProperties.map((p) {
        final m = p.toJson();
        m['id'] = p.id;
        m['created_at'] = p.createdAt.toIso8601String();
        return m;
      }).toList(),
      'rooms': roomsJson,
      'persons': _cachedPersons.map((p) {
        final m = p.toJson();
        m['id'] = p.id;
        m['created_at'] = p.createdAt.toIso8601String();
        return m;
      }).toList(),
      'stays': _cachedStays.map((s) {
        final m = s.toJson();
        m['id'] = s.id;
        m['created_at'] = s.createdAt.toIso8601String();
        return m;
      }).toList(),
      'payments': payJson,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<({int properties, int rooms, int guests, int stays, int payments})>
      importOfflineData(String jsonString) async {
    final Map<String, dynamic> data =
        jsonDecode(jsonString) as Map<String, dynamic>;

    int propCount = 0;
    int roomCount = 0;
    int guestCount = 0;
    int stayCount = 0;
    int paymentCount = 0;

    // 1. Merge Properties
    if (data['properties'] != null && data['properties'] is List) {
      for (var json in (data['properties'] as List)) {
        try {
          final prop =
              Property.fromJson(Map<String, dynamic>.from(json as Map));
          final existingIdx =
              _cachedProperties.indexWhere((p) => p.id == prop.id);
          if (existingIdx != -1) {
            _cachedProperties[existingIdx] = prop;
          } else {
            _cachedProperties.add(prop);
          }
          propCount++;
        } catch (e) {
          debugPrint('Error importing property item: $e');
        }
      }
    }

    // 2. Merge Rooms
    if (data['rooms'] != null && data['rooms'] is Map) {
      final roomsMap = data['rooms'] as Map;
      roomsMap.forEach((propId, list) {
        final pId = propId.toString();
        _cachedRooms.putIfAbsent(pId, () => []);
        if (list is List) {
          for (var json in list) {
            try {
              final rm = Room.fromJson(Map<String, dynamic>.from(json as Map));
              final existingIdx =
                  _cachedRooms[pId]!.indexWhere((r) => r.id == rm.id);
              if (existingIdx != -1) {
                _cachedRooms[pId]![existingIdx] = rm;
              } else {
                _cachedRooms[pId]!.add(rm);
              }
              roomCount++;
            } catch (e) {
              debugPrint('Error importing room item: $e');
            }
          }
        }
      });
    }

    // 3. Merge Persons / Guests
    if (data['persons'] != null && data['persons'] is List) {
      for (var json in (data['persons'] as List)) {
        try {
          final person =
              Person.fromJson(Map<String, dynamic>.from(json as Map));
          final existingIdx =
              _cachedPersons.indexWhere((p) => p.id == person.id);
          if (existingIdx != -1) {
            _cachedPersons[existingIdx] = person;
          } else {
            _cachedPersons.add(person);
          }
          guestCount++;
        } catch (e) {
          debugPrint('Error importing person item: $e');
        }
      }
    }

    // 4. Merge Stays
    if (data['stays'] != null && data['stays'] is List) {
      for (var json in (data['stays'] as List)) {
        try {
          final stay = Stay.fromJson(Map<String, dynamic>.from(json as Map));
          final existingIdx =
              _cachedStays.indexWhere((s) => s.id == stay.id);
          if (existingIdx != -1) {
            _cachedStays[existingIdx] = stay;
          } else {
            _cachedStays.add(stay);
          }
          stayCount++;
        } catch (e) {
          debugPrint('Error importing stay item: $e');
        }
      }
    }

    // 5. Merge Payments
    if (data['payments'] != null && data['payments'] is Map) {
      final paymentsMap = data['payments'] as Map;
      paymentsMap.forEach((stayId, list) {
        final sId = stayId.toString();
        _cachedPayments.putIfAbsent(sId, () => []);
        if (list is List) {
          for (var json in list) {
            try {
              final pm =
                  Payment.fromJson(Map<String, dynamic>.from(json as Map));
              final existingIdx =
                  _cachedPayments[sId]!.indexWhere((p) => p.id == pm.id);
              if (existingIdx != -1) {
                _cachedPayments[sId]![existingIdx] = pm;
              } else {
                _cachedPayments[sId]!.add(pm);
              }
              paymentCount++;
            } catch (e) {
              debugPrint('Error importing payment item: $e');
            }
          }
        }
      });
    }

    await _saveOfflineDataToDisk();

    return (
      properties: propCount,
      rooms: roomCount,
      guests: guestCount,
      stays: stayCount,
      payments: paymentCount,
    );
  }

  // --- Auth API ---

  String? get currentOwnerId => _useMock
      ? _currentOwnerId
      : (Supabase.instance.client.auth.currentUser?.id ??
          Supabase.instance.client.auth.currentSession?.user.id ??
          _cachedOwner?.id);

  Future<Owner?> getOwnerProfile() async {
    if (_useMock) {
      if (_currentOwnerId == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          _currentOwnerId = prefs.getString('persisted_mock_owner_id');
        } catch (_) {}
      }
      if (_currentOwnerId == null) return null;
      try {
        return _mockOwners.firstWhere((o) => o.id == _currentOwnerId);
      } catch (_) {
        return null;
      }
    } else {
      final user = Supabase.instance.client.auth.currentUser ??
          Supabase.instance.client.auth.currentSession?.user;
      if (user == null) return null;

      final meta = user.userMetadata ?? {};
      String? cachedAvatar = meta['avatar_url'] as String?;

      try {
        final dir = await getApplicationDocumentsDirectory();
        final avatarFile = File('${dir.path}/owner_avatar_${user.id}.txt');
        if (await avatarFile.exists()) {
          final path = (await avatarFile.readAsString()).trim();
          if (path.isNotEmpty) cachedAvatar = path;
        }
      } catch (_) {}

      final fallbackOwner = _cachedOwner ??
          Owner(
            id: user.id,
            fullName: meta['full_name'] as String? ?? user.email?.split('@').first ?? 'Property Owner',
            businessName: meta['business_name'] as String? ?? 'Bhai App PG',
            businessAddress: meta['business_address'] as String?,
            mobileNo: meta['mobile_no'] as String? ?? '',
            email: user.email ?? '',
            subscriptionPlan: 'free',
            avatarUrl: cachedAvatar,
            createdAt: DateTime.now(),
          );

      try {
        final res = await Supabase.instance.client
            .from('owners')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (res != null) {
          final dbAvatar = res['avatar_url'] as String?;
          final finalAvatar = (dbAvatar != null && dbAvatar.isNotEmpty) ? dbAvatar : cachedAvatar;
          final owner = Owner.fromJson(res);
          final finalOwner = owner.copyWith(
            avatarUrl: finalAvatar,
            businessAddress: owner.businessAddress ?? meta['business_address'] as String?,
          );
          _cachedOwner = finalOwner;
          await _saveOfflineDataToDisk();
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('persisted_owner_id', finalOwner.id);
            await prefs.setString('persisted_owner_data', jsonEncode(finalOwner.toJson()));
          } catch (_) {}
          return finalOwner;
        }

        // Auto-create owner profile in public.owners if not present
        final map = fallbackOwner.toJson();
        map['created_at'] = fallbackOwner.createdAt.toIso8601String();
        await Supabase.instance.client.from('owners').upsert(map);
        _cachedOwner = fallbackOwner;
        await _saveOfflineDataToDisk();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('persisted_owner_id', fallbackOwner.id);
          await prefs.setString('persisted_owner_data', jsonEncode(fallbackOwner.toJson()));
        } catch (_) {}
        return fallbackOwner;
      } catch (e) {
        debugPrint('Notice fetching owner profile from database: $e (serving cache)');
        return _cachedOwner ?? fallbackOwner;
      }
    }
  }

  Future<Owner?> getOwnerById(String ownerId) async {
    if (ownerId.trim().isEmpty) return null;
    if (_cachedOwner?.id == ownerId) return _cachedOwner;
    if (_useMock) {
      try {
        return _mockOwners.firstWhere((o) => o.id == ownerId);
      } catch (_) {
        return null;
      }
    } else {
      try {
        final res = await Supabase.instance.client
            .from('owners')
            .select()
            .eq('id', ownerId)
            .maybeSingle();
        if (res != null) {
          return Owner.fromJson(res);
        }
        return null;
      } catch (e) {
        debugPrint('Error getting owner by id ($ownerId): $e');
        return null;
      }
    }
  }

  Future<void> updateOwnerProfile({
    String? fullName,
    String? businessName,
    String? businessAddress,
    String? mobileNo,
    String? avatarUrl,
  }) async {
    final ownerId = currentOwnerId;
    if (ownerId == null) return;

    if (_useMock) {
      final index = _mockOwners.indexWhere((o) => o.id == ownerId);
      if (index != -1) {
        final existing = _mockOwners[index];
        _mockOwners[index] = Owner(
          id: existing.id,
          fullName: fullName ?? existing.fullName,
          businessName: businessName ?? existing.businessName,
          businessAddress: businessAddress ?? existing.businessAddress,
          mobileNo: mobileNo ?? existing.mobileNo,
          email: existing.email,
          subscriptionPlan: existing.subscriptionPlan,
          avatarUrl: avatarUrl ?? existing.avatarUrl,
          createdAt: existing.createdAt,
        );
        await _saveMockDataToDisk();
      }
    } else {
      if (avatarUrl != null) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final avatarFile = File('${dir.path}/owner_avatar_$ownerId.txt');
          await avatarFile.writeAsString(avatarUrl);
        } catch (e) {
          debugPrint('Error saving avatar path locally: $e');
        }
      }

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (businessName != null) updates['business_name'] = businessName;
      if (businessAddress != null) updates['business_address'] = businessAddress;
      if (mobileNo != null) updates['mobile_no'] = mobileNo;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isNotEmpty) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: updates),
          );
        } catch (e) {
          debugPrint('Error updating user metadata in Supabase Auth: $e');
        }

        try {
          await Supabase.instance.client
              .from('owners')
              .update(updates)
              .eq('id', ownerId);
        } catch (e) {
          // If schema cache was stale or column missing, fallback without business_address
          if (e.toString().contains('business_address') && updates.containsKey('business_address')) {
            final fallbackUpdates = Map<String, dynamic>.from(updates)..remove('business_address');
            if (fallbackUpdates.isNotEmpty) {
              await Supabase.instance.client
                  .from('owners')
                  .update(fallbackUpdates)
                  .eq('id', ownerId);
            }
          } else {
            rethrow;
          }
        }

        if (_cachedOwner != null) {
          _cachedOwner = _cachedOwner!.copyWith(
            fullName: fullName,
            businessName: businessName,
            businessAddress: businessAddress,
            mobileNo: mobileNo,
            avatarUrl: avatarUrl,
          );
        }
      }
    }
  }

  Future<void> updateSubscriptionPlan(String plan) async {
    final ownerId = currentOwnerId ?? _currentOwnerId;
    if (ownerId == null) return;

    if (_useMock) {
      final index = _mockOwners.indexWhere((o) => o.id == ownerId);
      if (index != -1) {
        final existing = _mockOwners[index];
        _mockOwners[index] = existing.copyWith(subscriptionPlan: plan);
        await _saveMockDataToDisk();
      }
    } else {
      // 1. Optimistically update local cached owner immediately
      if (_cachedOwner != null && _cachedOwner!.id == ownerId) {
        _cachedOwner = _cachedOwner!.copyWith(subscriptionPlan: plan);
        await _saveOfflineDataToDisk();
      }

      // 2. Try Supabase update or queue
      try {
        await ensureOwnerRecordExists(ownerId);
        await Supabase.instance.client
            .from('owners')
            .update({'subscription_plan': plan})
            .eq('id', ownerId);
      } catch (e) {
        debugPrint('Offline: queued subscription plan update for owners table: $e');
        _queuePendingSync(
          table: 'owners',
          action: 'update',
          id: ownerId,
          data: {'subscription_plan': plan},
        );
      }

      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'subscription_plan': plan}),
        );
      } catch (e) {
        debugPrint('Notice updating subscription plan in auth metadata: $e');
      }
    }
  }

  Future<String?> uploadOwnerAvatar(File file) async {
    final ownerId = currentOwnerId;
    if (ownerId == null) return null;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final ext = file.path.contains('.') ? file.path.split('.').last : 'jpg';
      final fileName = 'avatar_${ownerId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final localFile = await file.copy('${appDir.path}/$fileName');

      if (!_useMock) {
        try {
          final storagePath = 'avatars/$fileName';
          await Supabase.instance.client.storage
              .from('avatars')
              .upload(storagePath, localFile, fileOptions: const FileOptions(upsert: true));
          
          final publicUrl = Supabase.instance.client.storage
              .from('avatars')
              .getPublicUrl(storagePath);
          
          return publicUrl;
        } catch (e) {
          debugPrint('Error uploading avatar to Supabase Storage, using persistent local file path: $e');
          return localFile.path;
        }
      }
      return localFile.path;
    } catch (e) {
      debugPrint('Error saving avatar locally: $e');
      return file.path;
    }
  }

  Future<bool> signIn(String email, String password) async {
    if (_useMock) {
      final match = _mockOwners.where((o) => o.email == email);
      if (match.isNotEmpty) {
        _currentOwnerId = match.first.id;
        await _saveMockDataToDisk();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('persisted_mock_owner_id', _currentOwnerId!);
        } catch (_) {}
        return true;
      }
      throw 'Invalid email or password.';
    } else {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('persisted_owner_id', res.user!.id);
        } catch (_) {}
        return true;
      }
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String fullName, String businessName, String mobile) async {
    if (_useMock) {
      final id = 'owner-${DateTime.now().millisecondsSinceEpoch}';
      final newOwner = Owner(
        id: id,
        fullName: fullName,
        businessName: businessName,
        mobileNo: mobile,
        email: email,
        subscriptionPlan: 'free',
        createdAt: DateTime.now(),
      );
      _mockOwners.add(newOwner);
      _currentOwnerId = id;
      await _saveMockDataToDisk();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('persisted_mock_owner_id', _currentOwnerId!);
      } catch (_) {}
      return true;
    } else {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'bhai://login-callback',
        data: {
          'full_name': fullName,
          'business_name': businessName,
          'mobile_no': mobile,
        },
      );

      if (res.user != null) {
        final newOwner = Owner(
          id: res.user!.id,
          fullName: fullName,
          businessName: businessName,
          mobileNo: mobile,
          email: email,
          subscriptionPlan: 'free',
          createdAt: DateTime.now(),
        );
        final map = newOwner.toJson();
        map['created_at'] = newOwner.createdAt.toIso8601String();
        try {
          await Supabase.instance.client.from('owners').upsert(map);
        } catch (e) {
          debugPrint('Warning: Failed to insert owner profile row directly: $e');
        }

        if (res.session == null) {
          throw 'Account registered! Please check your email to confirm your account, then sign in.';
        }
        return true;
      }
      return false;
    }
  }

  Future<void> signOut() async {
    if (_useMock) {
      _currentOwnerId = null;
      await _saveMockDataToDisk();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('persisted_mock_owner_id');
      } catch (_) {}
    } else {
      await Supabase.instance.client.auth.signOut();
      _cachedOwner = null;
      _cachedProperties.clear();
      _cachedRooms.clear();
      _cachedPersons.clear();
      _cachedStays.clear();
      _cachedPayments.clear();
      _pendingSyncQueue.clear();
      await _saveOfflineDataToDisk();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('persisted_owner_id');
        await prefs.remove('persisted_owner_data');
      } catch (_) {}
    }
  }

  /// Deletes the authenticated owner account and all associated tenant data.
  /// Complies with Apple Guideline 5.1.1(v) & Google Play Account Deletion Policy.
  Future<void> deleteAccount() async {
    final ownerId = currentOwnerId;
    if (_useMock) {
      if (ownerId != null) {
        _mockOwners.removeWhere((o) => o.id == ownerId);
        _mockProperties.removeWhere((p) => p.ownerId == ownerId);
        _mockRooms.removeWhere((r) => _mockProperties.every((p) => p.id != r.propertyId));
        _mockStays.removeWhere((s) => s.ownerId == ownerId);
        _mockPayments.removeWhere((p) => p.ownerId == ownerId);
        await signOut();
      }
      return;
    }

    if (ownerId == null || ownerId.isEmpty) return;

    try {
      // 1. Try calling backend delete_user_account RPC function if configured
      await Supabase.instance.client.rpc('delete_user_account');
    } catch (_) {
      // 2. Direct database cascade deletion fallback
      try {
        await Supabase.instance.client.from('owners').delete().eq('id', ownerId);
      } catch (_) {}
    } finally {
      // 3. Clear local storage, session tokens, and sign out cleanly
      await signOut();
    }
  }

  // --- Properties API ---

  Future<void> ensureOwnerRecordExists(String ownerId) async {
    if (_useMock || ownerId.isEmpty) return;
    try {
      final res = await Supabase.instance.client
          .from('owners')
          .select('id')
          .eq('id', ownerId)
          .maybeSingle();

      if (res == null) {
        final user = Supabase.instance.client.auth.currentUser;
        final meta = user?.userMetadata ?? {};
        final map = {
          'id': ownerId,
          'full_name': meta['full_name'] as String? ?? user?.email?.split('@').first ?? 'Property Owner',
          'business_name': meta['business_name'] as String? ?? 'Bhai App PG',
          'mobile_no': meta['mobile_no'] as String? ?? '',
          'email': user?.email ?? '',
          'subscription_plan': 'free',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        await Supabase.instance.client.from('owners').upsert(map);
      }
    } catch (e) {
      debugPrint('Notice ensuring owner record in database: $e');
    }
  }

  Future<List<Property>> getProperties() async {
    if (_useMock) {
      return _mockProperties.where((p) => p.ownerId == _currentOwnerId).toList();
    } else {
      final ownerId = currentOwnerId;
      if (ownerId == null || ownerId.isEmpty) {
        return [];
      }

      // Offline First: Return cached properties immediately to eliminate DB read delays
      final cachedForOwner = _cachedProperties.where((p) => p.ownerId == ownerId).toList();
      if (cachedForOwner.isNotEmpty) {
        _backgroundSyncProperties(ownerId);
        return List.from(cachedForOwner);
      }

      try {
        final res = await Supabase.instance.client
            .from('properties')
            .select()
            .eq('owner_id', ownerId);
        final list = (res as List).map((json) => Property.fromJson(json)).toList();
        _cachedProperties.removeWhere((p) => p.ownerId == ownerId);
        _cachedProperties.addAll(list);
        await _saveOfflineDataToDisk();
        return list;
      } catch (e) {
        debugPrint('Error fetching properties from Supabase (serving cache): $e');
        return cachedForOwner;
      }
    }
  }

  void _backgroundSyncProperties(String ownerId) {
    if (_lastPropertiesSync != null &&
        DateTime.now().difference(_lastPropertiesSync!).inMinutes < 3) {
      return; // Throttled to minimize Supabase reads
    }
    _lastPropertiesSync = DateTime.now();
    Future.microtask(() async {
      try {
        final res = await Supabase.instance.client
            .from('properties')
            .select()
            .eq('owner_id', ownerId);
        final list = (res as List).map((json) => Property.fromJson(json)).toList();
        _cachedProperties.removeWhere((p) => p.ownerId == ownerId);
        _cachedProperties.addAll(list);
        await _saveOfflineDataToDisk();
      } catch (e) {
        debugPrint('Notice in background properties sync: $e');
      }
    });
  }

  Future<Property> addProperty(Property property) async {
    final ownerId = currentOwnerId ?? _currentOwnerId;
    if (_useMock) {
      final id = 'prop-${DateTime.now().millisecondsSinceEpoch}';
      final newProp = Property(
        id: id,
        ownerId: ownerId ?? '11111111-1111-1111-1111-111111111111',
        name: property.name,
        address: property.address,
        city: property.city,
        state: property.state,
        pincode: property.pincode,
        propertyType: property.propertyType,
        contactNo: property.contactNo,
        photos: property.photos,
        createdAt: DateTime.now(),
      );
      _mockProperties.add(newProp);
      await _saveMockDataToDisk();
      return newProp;
    } else {
      final propId = property.id.isNotEmpty ? property.id : const Uuid().v4();
      final effectiveOwnerId = property.ownerId.isNotEmpty ? property.ownerId : (ownerId ?? '');
      final newProp = Property(
        id: propId,
        ownerId: effectiveOwnerId,
        name: property.name,
        address: property.address,
        city: property.city,
        state: property.state,
        pincode: property.pincode,
        geoLatitude: property.geoLatitude,
        geoLongitude: property.geoLongitude,
        propertyType: property.propertyType,
        contactNo: property.contactNo,
        photos: property.photos,
        createdAt: property.createdAt,
      );

      // Optimistic write to local cache & disk
      _cachedProperties.removeWhere((p) => p.id == propId);
      _cachedProperties.add(newProp);
      await _saveOfflineDataToDisk();

      final payload = newProp.toJson();
      payload['id'] = propId;
      try {
        if (effectiveOwnerId.isNotEmpty) {
          await ensureOwnerRecordExists(effectiveOwnerId);
        }
        final res = await Supabase.instance.client
            .from('properties')
            .insert(payload)
            .select()
            .single();
        final serverProp = Property.fromJson(res);
        final idx = _cachedProperties.indexWhere((p) => p.id == propId);
        if (idx != -1) _cachedProperties[idx] = serverProp;
        await _saveOfflineDataToDisk();
        return serverProp;
      } on PostgrestException catch (pe) {
        if (pe.code == '23503' && pe.message.contains('owners')) {
          if (effectiveOwnerId.isNotEmpty) {
            await ensureOwnerRecordExists(effectiveOwnerId);
            try {
              final retryRes = await Supabase.instance.client
                  .from('properties')
                  .insert(payload)
                  .select()
                  .single();
              return Property.fromJson(retryRes);
            } catch (_) {}
          }
        }
        _queuePendingSync(table: 'properties', action: 'insert', data: payload);
        return newProp;
      } catch (e) {
        debugPrint('Notice adding property to remote DB: $e (queued for offline sync)');
        _queuePendingSync(table: 'properties', action: 'insert', data: payload);
        return newProp;
      }
    }
  }

  Future<void> updateProperty(Property property) async {
    final ownerId = currentOwnerId ?? _currentOwnerId;
    if (_useMock) {
      final idx = _mockProperties.indexWhere((p) => p.id == property.id);
      if (idx != -1) {
        _mockProperties[idx] = property;
        await _saveMockDataToDisk();
      }
    } else {
      final idx = _cachedProperties.indexWhere((p) => p.id == property.id);
      if (idx != -1) {
        _cachedProperties[idx] = property;
      } else {
        _cachedProperties.add(property);
      }
      await _saveOfflineDataToDisk();

      final effectiveOwnerId = property.ownerId.isNotEmpty ? property.ownerId : (ownerId ?? '');
      final payload = property.toJson();
      if ((payload['owner_id'] == null || payload['owner_id'] == '') && effectiveOwnerId.isNotEmpty) {
        payload['owner_id'] = effectiveOwnerId;
      }
      try {
        if (effectiveOwnerId.isNotEmpty) {
          await ensureOwnerRecordExists(effectiveOwnerId);
        }
        await Supabase.instance.client
            .from('properties')
            .update(payload)
            .eq('id', property.id);
      } catch (e) {
        debugPrint('Offline: queued updateProperty: $e');
        _queuePendingSync(table: 'properties', action: 'update', id: property.id, data: payload);
      }
    }
  }

  Future<void> deleteProperty(String propertyId) async {
    if (_useMock) {
      _mockProperties.removeWhere((p) => p.id == propertyId);
      _mockRooms.removeWhere((r) => r.propertyId == propertyId);
      final removedStayIds = _mockStays.where((s) => s.propertyId == propertyId).map((s) => s.id).toSet();
      _mockStays.removeWhere((s) => s.propertyId == propertyId);
      _mockPayments.removeWhere((pay) => removedStayIds.contains(pay.stayId));
      await _saveMockDataToDisk();
    } else {
      _cachedProperties.removeWhere((p) => p.id == propertyId);
      _cachedRooms.remove(propertyId);
      final removedStayIds = _cachedStays.where((s) => s.propertyId == propertyId).map((s) => s.id).toSet();
      _cachedStays.removeWhere((s) => s.propertyId == propertyId);
      for (final sid in removedStayIds) {
        _cachedPayments.remove(sid);
      }
      await _saveOfflineDataToDisk();

      try {
        await Supabase.instance.client
            .from('properties')
            .delete()
            .eq('id', propertyId);
      } catch (e) {
        debugPrint('Offline: queued deleteProperty: $e');
        _queuePendingSync(table: 'properties', action: 'delete', id: propertyId);
      }
    }
  }

  // --- Rooms API ---

  List<Room> reconcileRoomsWithActiveStays(List<Room> rooms, {String? propertyId}) {
    final stays = _useMock ? _mockStays : _cachedStays;
    final activeStays = stays.where((s) => s.status == 'active').toList();

    final updatedList = <Room>[];
    for (var room in rooms) {
      final actualOccupancy = activeStays.where((s) => s.roomId == room.id).length;
      final expectedStatus = actualOccupancy >= room.capacity
          ? RoomStatus.full
          : (room.status == RoomStatus.maintenance ? RoomStatus.maintenance : RoomStatus.available);

      if (room.currentOccupancy != actualOccupancy || (room.status != expectedStatus && room.status != RoomStatus.maintenance)) {
        final reconciled = Room(
          id: room.id,
          propertyId: room.propertyId,
          roomNumber: room.roomNumber,
          capacity: room.capacity,
          currentOccupancy: actualOccupancy,
          rentalType: room.rentalType,
          dailyRate: room.dailyRate,
          monthlyRate: room.monthlyRate,
          hourlyRate: room.hourlyRate,
          minimumDays: room.minimumDays,
          minimumCharge: room.minimumCharge,
          status: expectedStatus,
          photos: room.photos,
          createdAt: room.createdAt,
        );
        updatedList.add(reconciled);

        if (_useMock) {
          final idx = _mockRooms.indexWhere((r) => r.id == room.id);
          if (idx != -1) _mockRooms[idx] = reconciled;
        } else {
          final propRooms = _cachedRooms[room.propertyId];
          if (propRooms != null) {
            final idx = propRooms.indexWhere((r) => r.id == room.id);
            if (idx != -1) propRooms[idx] = reconciled;
          }
          Future.microtask(() async {
            try {
              await Supabase.instance.client.from('rooms').update({
                'current_occupancy': actualOccupancy,
                'status': expectedStatus.toString().split('.').last,
              }).eq('id', room.id);
            } catch (e) {
              debugPrint('Notice during auto-healing room ${room.roomNumber} occupancy: $e');
            }
          });
        }
      } else {
        updatedList.add(room);
      }
    }
    return updatedList;
  }

  Future<List<Room>> getRooms(String propertyId) async {
    if (_useMock) {
      final list = _mockRooms.where((r) => r.propertyId == propertyId).toList();
      return reconcileRoomsWithActiveStays(list, propertyId: propertyId);
    } else {
      final cached = _cachedRooms[propertyId];
      if (cached != null && cached.isNotEmpty) {
        _backgroundSyncRooms(propertyId);
        return reconcileRoomsWithActiveStays(List.from(cached), propertyId: propertyId);
      }

      try {
        final res = await Supabase.instance.client
            .from('rooms')
            .select()
            .eq('property_id', propertyId);
        final list = (res as List).map((json) => Room.fromJson(json)).toList();
        final reconciled = reconcileRoomsWithActiveStays(list, propertyId: propertyId);
        _cachedRooms[propertyId] = reconciled;
        await _saveOfflineDataToDisk();
        return List<Room>.from(reconciled);
      } catch (e) {
        debugPrint('Error fetching rooms (serving cache): $e');
        return reconcileRoomsWithActiveStays(cached ?? [], propertyId: propertyId);
      }
    }
  }

  void _backgroundSyncRooms(String propertyId) {
    final lastSync = _lastRoomsSync[propertyId];
    if (lastSync != null && DateTime.now().difference(lastSync).inMinutes < 3) {
      return;
    }
    _lastRoomsSync[propertyId] = DateTime.now();
    Future.microtask(() async {
      try {
        final res = await Supabase.instance.client
            .from('rooms')
            .select()
            .eq('property_id', propertyId);
        final list = (res as List).map((json) => Room.fromJson(json)).toList();
        _cachedRooms[propertyId] = reconcileRoomsWithActiveStays(list, propertyId: propertyId);
        await _saveOfflineDataToDisk();
      } catch (e) {
        debugPrint('Notice in background rooms sync: $e');
      }
    });
  }

  Future<Room> addRoom(Room room) async {
    if (_useMock) {
      final id = 'room-${DateTime.now().millisecondsSinceEpoch}';
      final newRoom = Room(
        id: id,
        propertyId: room.propertyId,
        roomNumber: room.roomNumber,
        capacity: room.capacity,
        currentOccupancy: 0,
        rentalType: room.rentalType,
        dailyRate: room.dailyRate,
        monthlyRate: room.monthlyRate,
        hourlyRate: room.hourlyRate,
        minimumDays: room.minimumDays,
        minimumCharge: room.minimumCharge,
        status: RoomStatus.available,
        photos: room.photos,
        createdAt: DateTime.now(),
      );
      _mockRooms.add(newRoom);
      await _saveMockDataToDisk();
      return newRoom;
    } else {
      final roomId = room.id.isNotEmpty ? room.id : const Uuid().v4();
      final newRoom = Room(
        id: roomId,
        propertyId: room.propertyId,
        roomNumber: room.roomNumber,
        capacity: room.capacity,
        currentOccupancy: room.currentOccupancy,
        rentalType: room.rentalType,
        dailyRate: room.dailyRate,
        monthlyRate: room.monthlyRate,
        hourlyRate: room.hourlyRate,
        minimumDays: room.minimumDays,
        minimumCharge: room.minimumCharge,
        status: room.status,
        photos: room.photos,
        createdAt: room.createdAt,
      );

      _cachedRooms.putIfAbsent(room.propertyId, () => []);
      _cachedRooms[room.propertyId]!.removeWhere((r) => r.id == roomId);
      _cachedRooms[room.propertyId]!.add(newRoom);
      await _saveOfflineDataToDisk();

      final payload = newRoom.toJson();
      payload['id'] = roomId;
      try {
        final res = await Supabase.instance.client
            .from('rooms')
            .insert(payload)
            .select()
            .single();
        final serverRoom = Room.fromJson(res);
        final list = _cachedRooms[room.propertyId];
        if (list != null) {
          final idx = list.indexWhere((r) => r.id == roomId);
          if (idx != -1) list[idx] = serverRoom;
        }
        await _saveOfflineDataToDisk();
        return serverRoom;
      } catch (e) {
        debugPrint('Offline: queued addRoom: $e');
        _queuePendingSync(table: 'rooms', action: 'insert', data: payload);
        return newRoom;
      }
    }
  }

  Future<Room> updateRoom(Room room) async {
    if (_useMock) {
      final idx = _mockRooms.indexWhere((r) => r.id == room.id);
      if (idx != -1) {
        _mockRooms[idx] = room;
        await _saveMockDataToDisk();
      }
      return room;
    } else {
      final list = _cachedRooms[room.propertyId];
      if (list != null) {
        final idx = list.indexWhere((r) => r.id == room.id);
        if (idx != -1) {
          list[idx] = room;
        } else {
          list.add(room);
        }
      } else {
        _cachedRooms[room.propertyId] = [room];
      }
      await _saveOfflineDataToDisk();

      final payload = room.toJson();
      try {
        final res = await Supabase.instance.client
            .from('rooms')
            .update(payload)
            .eq('id', room.id)
            .select()
            .single();
        final serverRoom = Room.fromJson(res);
        final currentList = _cachedRooms[room.propertyId];
        if (currentList != null) {
          final idx = currentList.indexWhere((r) => r.id == room.id);
          if (idx != -1) currentList[idx] = serverRoom;
        }
        await _saveOfflineDataToDisk();
        return serverRoom;
      } catch (e) {
        debugPrint('Offline: queued updateRoom: $e');
        _queuePendingSync(table: 'rooms', action: 'update', id: room.id, data: payload);
        return room;
      }
    }
  }

  Future<void> deleteRoom(String roomId, String propertyId) async {
    if (_useMock) {
      _mockRooms.removeWhere((r) => r.id == roomId);
      final removedStayIds = _mockStays.where((s) => s.roomId == roomId).map((s) => s.id).toSet();
      _mockStays.removeWhere((s) => s.roomId == roomId);
      _mockPayments.removeWhere((pay) => removedStayIds.contains(pay.stayId));
      await _saveMockDataToDisk();
    } else {
      if (_cachedRooms[propertyId] != null) {
        _cachedRooms[propertyId]!.removeWhere((r) => r.id == roomId);
      }
      final removedStayIds = _cachedStays.where((s) => s.roomId == roomId).map((s) => s.id).toSet();
      _cachedStays.removeWhere((s) => s.roomId == roomId);
      for (final sid in removedStayIds) {
        _cachedPayments.remove(sid);
      }
      await _saveOfflineDataToDisk();

      try {
        await Supabase.instance.client
            .from('rooms')
            .delete()
            .eq('id', roomId);
      } catch (e) {
        debugPrint('Offline: queued deleteRoom: $e');
        _queuePendingSync(table: 'rooms', action: 'delete', id: roomId);
      }
    }
  }

  // --- Persons / Guests API ---

  Future<Person?> searchGuestByAadhaar(String aadhaar) async {
    final clean = aadhaar.trim();
    if (clean.isEmpty) return null;

    if (_useMock) {
      final matches = _mockPersons.where((p) => p.aadhaarNo == clean);
      return matches.isNotEmpty ? matches.first : null;
    } else {
      // 1. Query Supabase for real-time accurate verification
      try {
        final res = await Supabase.instance.client
            .from('persons')
            .select()
            .eq('aadhaar_no', clean)
            .maybeSingle();
        if (res != null) {
          final person = Person.fromJson(res);
          _cachedPersons.removeWhere((p) => p.id == person.id);
          _cachedPersons.add(person);
          await _saveOfflineDataToDisk();
          return person;
        }
      } catch (e) {
        debugPrint('Error searching guest by Aadhaar (offline fallback): $e');
      }

      // 2. Fallback to local cached persons if offline
      final cachedMatches = _cachedPersons.where((p) => p.aadhaarNo == clean);
      if (cachedMatches.isNotEmpty) {
        return cachedMatches.first;
      }
      return null;
    }
  }

  Future<Person?> searchGuestByMobile(String mobile) async {
    final clean = mobile.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.isEmpty) return null;

    if (_useMock) {
      final matches = _mockPersons.where((p) => p.mobileNo.replaceAll(RegExp(r'\D'), '') == clean);
      return matches.isNotEmpty ? matches.first : null;
    } else {
      try {
        final res = await Supabase.instance.client
            .from('persons')
            .select()
            .eq('mobile_no', clean)
            .maybeSingle();
        if (res != null) {
          final person = Person.fromJson(res);
          _cachedPersons.removeWhere((p) => p.id == person.id);
          _cachedPersons.add(person);
          await _saveOfflineDataToDisk();
          return person;
        }
      } catch (e) {
        debugPrint('Error searching guest by mobile (offline fallback): $e');
      }

      final cachedMatches = _cachedPersons.where((p) => p.mobileNo.replaceAll(RegExp(r'\D'), '') == clean);
      if (cachedMatches.isNotEmpty) {
        return cachedMatches.first;
      }
      return null;
    }
  }

  Future<Person?> checkIfBlacklisted({String? aadhaar, String? mobile}) async {
    final cleanAadhaar = aadhaar?.trim() ?? '';
    final cleanMobile = mobile?.replaceAll(RegExp(r'\D'), '').trim() ?? '';

    if (cleanAadhaar.isEmpty && cleanMobile.isEmpty) return null;

    if (_useMock) {
      for (var p in _mockPersons) {
        if (p.isBlacklisted) {
          if (cleanAadhaar.isNotEmpty && p.aadhaarNo == cleanAadhaar) return p;
          if (cleanMobile.isNotEmpty && p.mobileNo.replaceAll(RegExp(r'\D'), '') == cleanMobile) return p;
        }
      }
      return null;
    }

    // 1. Check local cache first
    for (var p in _cachedPersons) {
      if (p.isBlacklisted) {
        if (cleanAadhaar.isNotEmpty && p.aadhaarNo == cleanAadhaar) return p;
        if (cleanMobile.isNotEmpty && p.mobileNo.replaceAll(RegExp(r'\D'), '') == cleanMobile) return p;
      }
    }

    // 2. Query Supabase for real-time blacklist status
    try {
      var query = Supabase.instance.client
          .from('persons')
          .select()
          .eq('is_blacklisted', true);

      if (cleanAadhaar.isNotEmpty && cleanMobile.isNotEmpty) {
        query = query.or('aadhaar_no.eq.$cleanAadhaar,mobile_no.eq.$cleanMobile');
      } else if (cleanAadhaar.isNotEmpty) {
        query = query.eq('aadhaar_no', cleanAadhaar);
      } else {
        query = query.eq('mobile_no', cleanMobile);
      }

      final res = await query.limit(1);
      if ((res as List).isNotEmpty) {
        final p = Person.fromJson(res.first);
        _cachedPersons.removeWhere((item) => item.id == p.id);
        _cachedPersons.add(p);
        await _saveOfflineDataToDisk();
        return p;
      }
    } catch (e) {
      debugPrint('Notice checking blacklist in Supabase: $e');
    }
    return null;
  }

  Future<Person> addGuest(Person person) async {
    // Preserve blacklist status if already blacklisted in database or cache!
    final existingBlacklist = await checkIfBlacklisted(
      aadhaar: person.aadhaarNo,
      mobile: person.mobileNo,
    );

    final bool isAlreadyBlacklisted = (existingBlacklist != null && existingBlacklist.isBlacklisted) || person.isBlacklisted;
    final String? finalBlacklistReason = isAlreadyBlacklisted
        ? (existingBlacklist?.blacklistReason ?? person.blacklistReason)
        : null;
    final String? finalBlacklistedBy = isAlreadyBlacklisted
        ? (existingBlacklist?.blacklistedBy ?? person.blacklistedBy)
        : null;
    final DateTime? finalBlacklistedAt = isAlreadyBlacklisted
        ? (existingBlacklist?.blacklistedAt ?? person.blacklistedAt)
        : null;

    if (_useMock) {
      final id = existingBlacklist?.id.isNotEmpty == true
          ? existingBlacklist!.id
          : (person.id.isNotEmpty ? person.id : 'guest-${DateTime.now().millisecondsSinceEpoch}');
      final newPerson = Person(
        id: id,
        name: person.name,
        mobileNo: person.mobileNo,
        aadhaarNo: person.aadhaarNo,
        fatherName: person.fatherName,
        motherName: person.motherName,
        wifeName: person.wifeName,
        wifeMobileNo: person.wifeMobileNo,
        policeStationCircle: person.policeStationCircle,
        aadhaarCardPhoto: person.aadhaarCardPhoto,
        personPhoto: person.personPhoto.isNotEmpty
            ? person.personPhoto
            : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde',
        address: person.address,
        city: person.city,
        state: person.state,
        pincode: person.pincode,
        dob: person.dob,
        isBlacklisted: isAlreadyBlacklisted,
        blacklistReason: finalBlacklistReason,
        blacklistedBy: finalBlacklistedBy,
        blacklistedAt: finalBlacklistedAt,
        createdByOwnerId: existingBlacklist?.createdByOwnerId.isNotEmpty == true ? existingBlacklist!.createdByOwnerId : _currentOwnerId!,
        createdAt: existingBlacklist?.createdAt ?? DateTime.now(),
      );
      _mockPersons.removeWhere((p) => p.id == id);
      _mockPersons.add(newPerson);
      await _saveMockDataToDisk();
      return newPerson;
    } else {
      final guestId = person.id.isNotEmpty
          ? person.id
          : (existingBlacklist?.id.isNotEmpty == true ? existingBlacklist!.id : const Uuid().v4());
      final ownerId = currentOwnerId ?? _currentOwnerId ?? '';
      final newPerson = Person(
        id: guestId,
        name: person.name,
        mobileNo: person.mobileNo,
        aadhaarNo: person.aadhaarNo,
        fatherName: person.fatherName,
        motherName: person.motherName,
        wifeName: person.wifeName,
        wifeMobileNo: person.wifeMobileNo,
        policeStationCircle: person.policeStationCircle,
        aadhaarCardPhoto: person.aadhaarCardPhoto,
        personPhoto: person.personPhoto.isNotEmpty ? person.personPhoto : '',
        address: person.address,
        city: person.city,
        state: person.state,
        pincode: person.pincode,
        dob: person.dob,
        isBlacklisted: isAlreadyBlacklisted,
        blacklistReason: finalBlacklistReason,
        blacklistedBy: finalBlacklistedBy,
        blacklistedAt: finalBlacklistedAt,
        createdByOwnerId: existingBlacklist?.createdByOwnerId.isNotEmpty == true ? existingBlacklist!.createdByOwnerId : ownerId,
        createdAt: existingBlacklist?.createdAt ?? person.createdAt,
      );

      // Optimistically add to local cache & disk
      _cachedPersons.removeWhere((p) => p.id == guestId);
      _cachedPersons.add(newPerson);
      await _saveOfflineDataToDisk();

      final data = newPerson.toJson();
      data['id'] = guestId;
      if (ownerId.isNotEmpty && (existingBlacklist == null || existingBlacklist.createdByOwnerId.isEmpty)) {
        data['created_by_owner_id'] = ownerId;
      }

      try {
        final res = await Supabase.instance.client
            .from('persons')
            .upsert(data)
            .select()
            .single();
        final serverPerson = Person.fromJson(res);
        final idx = _cachedPersons.indexWhere((p) => p.id == guestId);
        if (idx != -1) _cachedPersons[idx] = serverPerson;
        await _saveOfflineDataToDisk();
        return serverPerson;
      } catch (e) {
        debugPrint('Offline: queued addGuest ($e)');
        _queuePendingSync(table: 'persons', action: 'insert', data: data);
        return newPerson;
      }
    }
  }

  Future<Person> updateGuest(Person person) async {
    if (_useMock) {
      final idx = _mockPersons.indexWhere((p) => p.id == person.id);
      if (idx != -1) {
        _mockPersons[idx] = person;
        await _saveMockDataToDisk();
      }
      return person;
    } else {
      final idx = _cachedPersons.indexWhere((p) => p.id == person.id);
      if (idx != -1) {
        _cachedPersons[idx] = person;
      } else {
        _cachedPersons.add(person);
      }
      await _saveOfflineDataToDisk();

      final data = person.toJson();
      try {
        final res = await Supabase.instance.client
            .from('persons')
            .update(data)
            .eq('id', person.id)
            .select()
            .single();
        final serverPerson = Person.fromJson(res);
        final sIdx = _cachedPersons.indexWhere((p) => p.id == person.id);
        if (sIdx != -1) _cachedPersons[sIdx] = serverPerson;
        await _saveOfflineDataToDisk();
        return serverPerson;
      } catch (e) {
        debugPrint('Offline: queued updateGuest ($e)');
        _queuePendingSync(table: 'persons', action: 'update', id: person.id, data: data);
        return person;
      }
    }
  }

  Future<void> blacklistGuest(String personId, String reason, ReportCategory reportType) async {
    if (_useMock) {
      final idx = _mockPersons.indexWhere((p) => p.id == personId);
      if (idx != -1) {
        final p = _mockPersons[idx];
        _mockPersons[idx] = Person(
          id: p.id,
          name: p.name,
          mobileNo: p.mobileNo,
          aadhaarNo: p.aadhaarNo,
          fatherName: p.fatherName,
          motherName: p.motherName,
          wifeName: p.wifeName,
          wifeMobileNo: p.wifeMobileNo,
          policeStationCircle: p.policeStationCircle,
          aadhaarCardPhoto: p.aadhaarCardPhoto,
          personPhoto: p.personPhoto,
          address: p.address,
          city: p.city,
          state: p.state,
          pincode: p.pincode,
          dob: p.dob,
          isBlacklisted: true,
          blacklistReason: reason,
          blacklistedBy: _currentOwnerId,
          blacklistedAt: DateTime.now(),
          createdByOwnerId: p.createdByOwnerId,
          createdAt: p.createdAt,
        );
      }
      _mockReportsLog.add(ReportsLog(
        id: 'report-${DateTime.now().millisecondsSinceEpoch}',
        personId: personId,
        reportedByOwnerId: _currentOwnerId!,
        reportType: reportType,
        description: reason,
        createdAt: DateTime.now(),
      ));
      await _saveMockDataToDisk();
    } else {
      final ownerId = currentOwnerId ?? 'global';
      // 1. Optimistically update local cache
      int pIdx = _cachedPersons.indexWhere((p) => p.id == personId);
      if (pIdx == -1) {
        try {
          final pRes = await Supabase.instance.client.from('persons').select().eq('id', personId).maybeSingle();
          if (pRes != null) {
            _cachedPersons.add(Person.fromJson(pRes));
            pIdx = _cachedPersons.length - 1;
          }
        } catch (_) {}
      }

      if (pIdx != -1) {
        final p = _cachedPersons[pIdx];
        _cachedPersons[pIdx] = Person(
          id: p.id,
          name: p.name,
          mobileNo: p.mobileNo,
          aadhaarNo: p.aadhaarNo,
          fatherName: p.fatherName,
          motherName: p.motherName,
          wifeName: p.wifeName,
          wifeMobileNo: p.wifeMobileNo,
          policeStationCircle: p.policeStationCircle,
          aadhaarCardPhoto: p.aadhaarCardPhoto,
          personPhoto: p.personPhoto,
          address: p.address,
          city: p.city,
          state: p.state,
          pincode: p.pincode,
          dob: p.dob,
          isBlacklisted: true,
          blacklistReason: reason,
          blacklistedBy: ownerId,
          blacklistedAt: DateTime.now(),
          createdByOwnerId: p.createdByOwnerId,
          createdAt: p.createdAt,
        );

        // Also update any stays in _cachedStays with this person
        for (int i = 0; i < _cachedStays.length; i++) {
          if (_cachedStays[i].personId == personId) {
            _cachedStays[i] = Stay(
              id: _cachedStays[i].id,
              personId: _cachedStays[i].personId,
              roomId: _cachedStays[i].roomId,
              propertyId: _cachedStays[i].propertyId,
              ownerId: _cachedStays[i].ownerId,
              checkInDate: _cachedStays[i].checkInDate,
              checkOutDate: _cachedStays[i].checkOutDate,
              rentalTypeUsed: _cachedStays[i].rentalTypeUsed,
              agreedRate: _cachedStays[i].agreedRate,
              status: _cachedStays[i].status,
              createdAt: _cachedStays[i].createdAt,
              person: _cachedPersons[pIdx],
              room: _cachedStays[i].room,
            );
          }
        }
        await _saveOfflineDataToDisk();
      }

      // 2. Sync to Supabase RPC with fallback to direct table update & queue
      try {
        await Supabase.instance.client.rpc('blacklist_guest', params: {
          'p_person_id': personId,
          'p_reason': reason,
          'p_report_type': reportType.toString().split('.').last,
        });
      } catch (e) {
        debugPrint('RPC blacklist_guest notice ($e). Fallback to table update...');
        try {
          await Supabase.instance.client.from('persons').update({
            'is_blacklisted': true,
            'blacklist_reason': reason,
            'blacklisted_by': ownerId,
            'blacklisted_at': DateTime.now().toIso8601String(),
          }).eq('id', personId);
        } catch (tblErr) {
          debugPrint('Offline: queued blacklist sync ($tblErr)');
          _queuePendingSync(
            table: 'persons',
            action: 'update',
            id: personId,
            data: {
              'is_blacklisted': true,
              'blacklist_reason': reason,
              'blacklisted_by': ownerId,
              'blacklisted_at': DateTime.now().toIso8601String(),
            },
          );
        }
      }
    }
  }

  Future<void> unblacklistGuest(String personId) async {
    final ownerId = currentOwnerId ?? _currentOwnerId;
    Person? person = getCachedPersonById(personId);
    if (person == null) {
      try {
        final res = await Supabase.instance.client.from('persons').select().eq('id', personId).maybeSingle();
        if (res != null) person = Person.fromJson(res);
      } catch (_) {}
    }

    if (person != null &&
        person.blacklistedBy != null &&
        person.blacklistedBy!.isNotEmpty &&
        person.blacklistedBy != ownerId) {
      throw Exception('Only the original owner who blacklisted this person can remove their blacklist status.');
    }

    if (_useMock) {
      final idx = _mockPersons.indexWhere((p) => p.id == personId);
      if (idx != -1) {
        final p = _mockPersons[idx];
        _mockPersons[idx] = Person(
          id: p.id,
          name: p.name,
          mobileNo: p.mobileNo,
          aadhaarNo: p.aadhaarNo,
          fatherName: p.fatherName,
          motherName: p.motherName,
          wifeName: p.wifeName,
          wifeMobileNo: p.wifeMobileNo,
          policeStationCircle: p.policeStationCircle,
          aadhaarCardPhoto: p.aadhaarCardPhoto,
          personPhoto: p.personPhoto,
          address: p.address,
          city: p.city,
          state: p.state,
          pincode: p.pincode,
          dob: p.dob,
          isBlacklisted: false,
          blacklistReason: null,
          blacklistedBy: null,
          blacklistedAt: null,
          createdByOwnerId: p.createdByOwnerId,
          createdAt: p.createdAt,
        );
      }
      await _saveMockDataToDisk();
    } else {
      // 1. Optimistically update local cache
      final pIdx = _cachedPersons.indexWhere((p) => p.id == personId);
      if (pIdx != -1) {
        final p = _cachedPersons[pIdx];
        _cachedPersons[pIdx] = Person(
          id: p.id,
          name: p.name,
          mobileNo: p.mobileNo,
          aadhaarNo: p.aadhaarNo,
          fatherName: p.fatherName,
          motherName: p.motherName,
          wifeName: p.wifeName,
          wifeMobileNo: p.wifeMobileNo,
          policeStationCircle: p.policeStationCircle,
          aadhaarCardPhoto: p.aadhaarCardPhoto,
          personPhoto: p.personPhoto,
          address: p.address,
          city: p.city,
          state: p.state,
          pincode: p.pincode,
          dob: p.dob,
          isBlacklisted: false,
          blacklistReason: null,
          blacklistedBy: null,
          blacklistedAt: null,
          createdByOwnerId: p.createdByOwnerId,
          createdAt: p.createdAt,
        );

        for (int i = 0; i < _cachedStays.length; i++) {
          if (_cachedStays[i].personId == personId) {
            _cachedStays[i] = Stay(
              id: _cachedStays[i].id,
              personId: _cachedStays[i].personId,
              roomId: _cachedStays[i].roomId,
              propertyId: _cachedStays[i].propertyId,
              ownerId: _cachedStays[i].ownerId,
              checkInDate: _cachedStays[i].checkInDate,
              checkOutDate: _cachedStays[i].checkOutDate,
              rentalTypeUsed: _cachedStays[i].rentalTypeUsed,
              agreedRate: _cachedStays[i].agreedRate,
              status: _cachedStays[i].status,
              createdAt: _cachedStays[i].createdAt,
              person: _cachedPersons[pIdx],
              room: _cachedStays[i].room,
            );
          }
        }
        await _saveOfflineDataToDisk();
      }

      // 2. Call unblacklist_guest RPC with fallback
      try {
        await Supabase.instance.client.rpc('unblacklist_guest', params: {
          'p_person_id': personId,
        });
      } catch (e) {
        debugPrint('RPC unblacklist_guest notice ($e). Fallback to table update...');
        try {
          await Supabase.instance.client.from('persons').update({
            'is_blacklisted': false,
            'blacklist_reason': null,
            'blacklisted_by': null,
            'blacklisted_at': null,
          }).eq('id', personId);
        } catch (tblErr) {
          debugPrint('Offline: queued unblacklist sync ($tblErr)');
          _queuePendingSync(
            table: 'persons',
            action: 'update',
            id: personId,
            data: {
              'is_blacklisted': false,
              'blacklist_reason': null,
              'blacklisted_by': null,
              'blacklisted_at': null,
            },
          );
        }
      }
    }
  }

  List<Person> getCachedBlacklistedPersons() {
    return _useMock
        ? _mockPersons.where((p) => p.isBlacklisted).toList()
        : _cachedPersons.where((p) => p.isBlacklisted).toList();
  }

  Future<List<Person>> fetchAllBlacklistedPersons() async {
    if (_useMock) {
      return getCachedBlacklistedPersons();
    }
    try {
      final res = await Supabase.instance.client
          .from('persons')
          .select()
          .eq('is_blacklisted', true);
      final list = (res as List).map((j) => Person.fromJson(j)).toList();
      for (var p in list) {
        final idx = _cachedPersons.indexWhere((cp) => cp.id == p.id);
        if (idx == -1) {
          _cachedPersons.add(p);
        } else {
          _cachedPersons[idx] = p;
        }
      }
      await _saveOfflineDataToDisk();
      return list;
    } catch (e) {
      debugPrint('Error fetching blacklisted persons: $e');
      return getCachedBlacklistedPersons();
    }
  }

  Future<void> deletePerson(String personId) async {
    Person? person = getCachedPersonById(personId);
    if (person == null) {
      try {
        final res = await Supabase.instance.client.from('persons').select().eq('id', personId).maybeSingle();
        if (res != null) person = Person.fromJson(res);
      } catch (_) {}
    }
    if (person != null && person.isBlacklisted) {
      throw Exception('Blacklisted guest profile cannot be deleted. You must un-blacklist the guest first.');
    }

    if (_useMock) {
      // Decrement room occupancy for any active stay being deleted
      final activeStays = _mockStays.where((s) => s.personId == personId && s.status == 'active').toList();
      for (var stay in activeStays) {
        final rIdx = _mockRooms.indexWhere((r) => r.id == stay.roomId);
        if (rIdx != -1) {
          final r = _mockRooms[rIdx];
          final newOcc = (r.currentOccupancy - 1).clamp(0, r.capacity);
          _mockRooms[rIdx] = Room(
            id: r.id,
            propertyId: r.propertyId,
            roomNumber: r.roomNumber,
            capacity: r.capacity,
            currentOccupancy: newOcc,
            rentalType: r.rentalType,
            dailyRate: r.dailyRate,
            monthlyRate: r.monthlyRate,
            hourlyRate: r.hourlyRate,
            minimumDays: r.minimumDays,
            minimumCharge: r.minimumCharge,
            status: newOcc >= r.capacity ? RoomStatus.full : RoomStatus.available,
            photos: r.photos,
            createdAt: r.createdAt,
          );
        }
      }
      _mockPersons.removeWhere((p) => p.id == personId);
      final stayIds = _mockStays.where((s) => s.personId == personId).map((s) => s.id).toSet();
      _mockStays.removeWhere((s) => s.personId == personId);
      _mockPayments.removeWhere((pay) => stayIds.contains(pay.stayId) || pay.personId == personId);
      await _saveMockDataToDisk();
    } else {
      // Decrement room occupancy locally for active stays being deleted
      final activeStays = _cachedStays.where((s) => s.personId == personId && s.status == 'active').toList();
      for (var stay in activeStays) {
        final list = _cachedRooms[stay.propertyId];
        if (list != null) {
          final rIdx = list.indexWhere((r) => r.id == stay.roomId);
          if (rIdx != -1) {
            final r = list[rIdx];
            final newOcc = (r.currentOccupancy - 1).clamp(0, r.capacity);
            list[rIdx] = Room(
              id: r.id,
              propertyId: r.propertyId,
              roomNumber: r.roomNumber,
              capacity: r.capacity,
              currentOccupancy: newOcc,
              rentalType: r.rentalType,
              dailyRate: r.dailyRate,
              monthlyRate: r.monthlyRate,
              hourlyRate: r.hourlyRate,
              minimumDays: r.minimumDays,
              minimumCharge: r.minimumCharge,
              status: newOcc >= r.capacity ? RoomStatus.full : RoomStatus.available,
              photos: r.photos,
              createdAt: r.createdAt,
            );
          }
        }
      }
      _cachedPersons.removeWhere((p) => p.id == personId);
      final stayIds = _cachedStays.where((s) => s.personId == personId).map((s) => s.id).toSet();
      _cachedStays.removeWhere((s) => s.personId == personId);
      for (final sid in stayIds) {
        _cachedPayments.remove(sid);
      }
      await _saveOfflineDataToDisk();

      try {
        await Supabase.instance.client
            .from('persons')
            .delete()
            .eq('id', personId);
      } catch (e) {
        debugPrint('Offline: queued deletePerson: $e');
        _queuePendingSync(table: 'persons', action: 'delete', id: personId);
      }
    }
  }

  Person? getCachedPersonById(String personId) {
    final list = _useMock ? _mockPersons : _cachedPersons;
    final matches = list.where((p) => p.id == personId);
    if (matches.isNotEmpty) return matches.first;
    final altList = _useMock ? _cachedPersons : _mockPersons;
    final altMatches = altList.where((p) => p.id == personId);
    return altMatches.isNotEmpty ? altMatches.first : null;
  }

  Property? getCachedPropertyById(String propertyId) {
    final list = _useMock ? _mockProperties : _cachedProperties;
    final matches = list.where((p) => p.id == propertyId);
    if (matches.isNotEmpty) return matches.first;
    final altList = _useMock ? _cachedProperties : _mockProperties;
    final altMatches = altList.where((p) => p.id == propertyId);
    return altMatches.isNotEmpty ? altMatches.first : null;
  }

  Room? getCachedRoomById(String roomId, [String? propertyId]) {
    if (_useMock) {
      final matches = _mockRooms.where((r) => r.id == roomId);
      return matches.isNotEmpty ? matches.first : null;
    } else {
      if (propertyId != null && _cachedRooms[propertyId] != null) {
        final matches = _cachedRooms[propertyId]!.where((r) => r.id == roomId);
        if (matches.isNotEmpty) return matches.first;
      }
      for (final roomList in _cachedRooms.values) {
        final matches = roomList.where((r) => r.id == roomId);
        if (matches.isNotEmpty) return matches.first;
      }
      return null;
    }
  }

  List<Room> getCachedRooms(String propertyId) {
    if (_useMock) {
      return _mockRooms.where((r) => r.propertyId == propertyId).toList();
    }
    return _cachedRooms[propertyId] ?? [];
  }

  Future<List<GuestStayHistory>> getGuestStayHistory(String personId) async {
    if (_useMock) {
      // Reconstruct history from mock stays & properties & rooms
      final history = <GuestStayHistory>[];
      for (var stay in _mockStays.where((s) => s.personId == personId)) {
        final prop = _mockProperties.firstWhere((p) => p.id == stay.propertyId,
            orElse: () => Property(
                  id: '',
                  ownerId: '',
                  name: 'Unknown PG',
                  address: '',
                  city: 'City',
                  state: '',
                  pincode: '',
                  propertyType: 'PG',
                  contactNo: '',
                  photos: [],
                  createdAt: DateTime.now(),
                ));
        final room = _mockRooms.firstWhere((r) => r.id == stay.roomId,
            orElse: () => Room(
                  id: '',
                  propertyId: '',
                  roomNumber: 'N/A',
                  capacity: 0,
                  currentOccupancy: 0,
                  rentalType: 'both',
                  dailyRate: 0,
                  monthlyRate: 0,
                  hourlyRate: 0,
                  status: RoomStatus.available,
                  photos: [],
                  createdAt: DateTime.now(),
                ));

        history.add(GuestStayHistory(
          stayId: stay.id,
          personId: personId,
          checkInDate: stay.checkInDate,
          checkOutDate: stay.checkOutDate,
          status: stay.status,
          propertyType: prop.propertyType,
          propertyName: prop.name,
          propertyCity: prop.city,
          roomNumber: room.roomNumber,
        ));
      }
      return history;
    } else {
      try {
        final res = await Supabase.instance.client
            .from('guest_stay_history')
            .select()
            .eq('person_id', personId);
        return (res as List).map((json) => GuestStayHistory.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error fetching guest stay history: $e');
        return [];
      }
    }
  }

  Future<GuestStayHistory?> getActiveStayForPerson(String personId) async {
    if (_useMock) {
      final active = _mockStays.where((s) => s.personId == personId && s.status == 'active');
      if (active.isNotEmpty) {
        final stay = active.first;
        final prop = _mockProperties.firstWhere(
          (p) => p.id == stay.propertyId,
          orElse: () => Property(
            id: '',
            ownerId: '',
            name: 'Previous Property',
            address: '',
            city: 'Kerala',
            state: 'Kerala',
            pincode: '',
            propertyType: 'PG',
            contactNo: '',
            photos: [],
            createdAt: DateTime.now(),
          ),
        );
        final room = _mockRooms.firstWhere(
          (r) => r.id == stay.roomId,
          orElse: () => Room(
            id: '',
            propertyId: '',
            roomNumber: 'N/A',
            capacity: 0,
            currentOccupancy: 0,
            rentalType: 'monthly',
            dailyRate: 0,
            monthlyRate: 0,
            hourlyRate: 0,
            status: RoomStatus.available,
            photos: [],
            createdAt: DateTime.now(),
          ),
        );
        return GuestStayHistory(
          stayId: stay.id,
          personId: personId,
          checkInDate: stay.checkInDate,
          checkOutDate: stay.checkOutDate,
          status: stay.status,
          propertyType: prop.propertyType,
          propertyName: prop.name,
          propertyCity: prop.city,
          roomNumber: room.roomNumber,
        );
      }
      return null;
    } else {
      try {
        final res = await Supabase.instance.client
            .from('stays')
            .select('id, person_id, check_in_date, check_out_date, status, properties(name, city, property_type), rooms(room_number)')
            .eq('person_id', personId)
            .eq('status', 'active')
            .maybeSingle();

        if (res != null) {
          final prop = res['properties'] as Map<String, dynamic>?;
          final room = res['rooms'] as Map<String, dynamic>?;
          return GuestStayHistory(
            stayId: res['id'].toString(),
            personId: res['person_id'].toString(),
            checkInDate: DateTime.parse(res['check_in_date'] as String),
            checkOutDate: res['check_out_date'] != null ? DateTime.parse(res['check_out_date'] as String) : null,
            status: res['status'] as String? ?? 'active',
            propertyType: prop?['property_type'] as String? ?? 'PG',
            propertyName: prop?['name'] as String? ?? 'Another Registered Property',
            propertyCity: prop?['city'] as String? ?? 'Kerala',
            roomNumber: room?['room_number'] as String? ?? 'N/A',
          );
        }
        return null;
      } catch (e) {
        debugPrint('Error checking active stay for person: $e');
        return null;
      }
    }
  }

  // --- Stays / Bookings API ---

  Future<List<Stay>> getStays({bool activeOnly = false}) async {
    if (_useMock) {
      var filtered = _mockStays.where((s) => s.ownerId == _currentOwnerId);
      if (activeOnly) {
        filtered = filtered.where((s) => s.status == 'active');
      }
      return filtered.toList();
    } else {
      final ownerId = currentOwnerId;
      if (ownerId == null || ownerId.isEmpty) {
        return [];
      }

      // Offline First: Return cached stays immediately
      final cachedStaysForOwner = _cachedStays.where((s) => s.ownerId == ownerId).map((stay) {
        if (stay.person == null) {
          final p = getCachedPersonById(stay.personId);
          if (p != null) {
            return Stay(
              id: stay.id,
              personId: stay.personId,
              roomId: stay.roomId,
              propertyId: stay.propertyId,
              ownerId: stay.ownerId,
              checkInDate: stay.checkInDate,
              checkOutDate: stay.checkOutDate,
              rentalTypeUsed: stay.rentalTypeUsed,
              agreedRate: stay.agreedRate,
              status: stay.status,
              createdAt: stay.createdAt,
              person: p,
              room: stay.room,
            );
          }
        }
        return stay;
      }).toList();

      if (cachedStaysForOwner.isNotEmpty) {
        _backgroundSyncStays(ownerId);
        var filtered = cachedStaysForOwner;
        if (activeOnly) {
          filtered = filtered.where((s) => s.status == 'active').toList();
        }
        return List.from(filtered);
      }

      try {
        var query = Supabase.instance.client
            .from('stays')
            .select('*, persons(*), rooms(*)')
            .eq('owner_id', ownerId);

        if (activeOnly) {
          query = query.eq('status', 'active');
        }

        final res = await query;
        final list = (res as List).map((json) {
          final s = Stay.fromJson(json);
          if (s.person != null) {
            final pIdx = _cachedPersons.indexWhere((p) => p.id == s.person!.id);
            if (pIdx == -1) {
              _cachedPersons.add(s.person!);
            } else {
              _cachedPersons[pIdx] = s.person!;
            }
          }
          return s;
        }).toList();

        // Also fetch all blacklisted persons so they are available in memory/offline
        try {
          final bRes = await Supabase.instance.client
              .from('persons')
              .select()
              .eq('is_blacklisted', true);
          for (var bj in (bRes as List)) {
            final bp = Person.fromJson(bj);
            final idx = _cachedPersons.indexWhere((cp) => cp.id == bp.id);
            if (idx == -1) {
              _cachedPersons.add(bp);
            } else {
              _cachedPersons[idx] = bp;
            }
          }
        } catch (_) {}

        // Preserve any local stays that are still pending sync
        final pendingStayIds = _pendingSyncQueue
            .where((item) => item['table'] == 'stays')
            .map((item) => (item['data']?['id'] ?? item['id'])?.toString())
            .whereType<String>()
            .toSet();

        final localStaysToPreserve = _cachedStays
            .where((s) => s.ownerId == ownerId && pendingStayIds.contains(s.id))
            .toList();

        // Update local cache
        _cachedStays.removeWhere((s) => s.ownerId == ownerId);
        _cachedStays.addAll(list);
        for (var ls in localStaysToPreserve) {
          if (!_cachedStays.any((s) => s.id == ls.id)) {
            _cachedStays.add(ls);
          }
        }
        await _saveOfflineDataToDisk();
        return list;
      } catch (e) {
        debugPrint('Error fetching stays from Supabase (serving cache): $e');
        var filtered = cachedStaysForOwner;
        if (activeOnly) {
          filtered = filtered.where((s) => s.status == 'active').toList();
        }
        return filtered;
      }
    }
  }

  void _backgroundSyncStays(String ownerId) {
    if (_lastStaysSync != null &&
        DateTime.now().difference(_lastStaysSync!).inMinutes < 3) {
      return; // Throttled to minimize Supabase reads
    }
    _lastStaysSync = DateTime.now();
    Future.microtask(() async {
      try {
        final res = await Supabase.instance.client
            .from('stays')
            .select('*, persons(*), rooms(*)')
            .eq('owner_id', ownerId);
        final list = (res as List).map((json) {
          final s = Stay.fromJson(json);
          if (s.person != null) {
            final pIdx = _cachedPersons.indexWhere((p) => p.id == s.person!.id);
            if (pIdx == -1) {
              _cachedPersons.add(s.person!);
            } else {
              _cachedPersons[pIdx] = s.person!;
            }
          }
          return s;
        }).toList();

        // Also sync blacklisted persons
        try {
          final bRes = await Supabase.instance.client
              .from('persons')
              .select()
              .eq('is_blacklisted', true);
          for (var bj in (bRes as List)) {
            final bp = Person.fromJson(bj);
            final idx = _cachedPersons.indexWhere((cp) => cp.id == bp.id);
            if (idx == -1) {
              _cachedPersons.add(bp);
            } else {
              _cachedPersons[idx] = bp;
            }
          }
        } catch (_) {}

        final pendingStayIds = _pendingSyncQueue
            .where((item) => item['table'] == 'stays')
            .map((item) => (item['data']?['id'] ?? item['id'])?.toString())
            .whereType<String>()
            .toSet();

        final localStaysToPreserve = _cachedStays
            .where((s) => s.ownerId == ownerId && pendingStayIds.contains(s.id))
            .toList();

        _cachedStays.removeWhere((s) => s.ownerId == ownerId);
        _cachedStays.addAll(list);
        for (var ls in localStaysToPreserve) {
          if (!_cachedStays.any((s) => s.id == ls.id)) {
            _cachedStays.add(ls);
          }
        }
        await _saveOfflineDataToDisk();
      } catch (e) {
        debugPrint('Notice in background stays sync: $e');
      }
    });
  }

  Future<Stay> addStay(Stay stay) async {
    final ownerId = currentOwnerId ?? _currentOwnerId ?? '11111111-1111-1111-1111-111111111111';
    if (_useMock) {
      final id = 'stay-${DateTime.now().millisecondsSinceEpoch}';
      final guest = _mockPersons.firstWhere((p) => p.id == stay.personId);
      final room = _mockRooms.firstWhere((r) => r.id == stay.roomId);

      // Increment room occupancy
      final roomIdx = _mockRooms.indexWhere((r) => r.id == stay.roomId);
      if (roomIdx != -1) {
        final r = _mockRooms[roomIdx];
        _mockRooms[roomIdx] = Room(
          id: r.id,
          propertyId: r.propertyId,
          roomNumber: r.roomNumber,
          capacity: r.capacity,
          currentOccupancy: r.currentOccupancy + 1,
          rentalType: r.rentalType,
          dailyRate: r.dailyRate,
          monthlyRate: r.monthlyRate,
          hourlyRate: r.hourlyRate,
          minimumDays: r.minimumDays,
          minimumCharge: r.minimumCharge,
          status: r.currentOccupancy + 1 >= r.capacity ? RoomStatus.full : RoomStatus.available,
          photos: r.photos,
          createdAt: r.createdAt,
        );
      }

      final newStay = Stay(
        id: id,
        personId: stay.personId,
        roomId: stay.roomId,
        propertyId: stay.propertyId,
        ownerId: _currentOwnerId!,
        checkInDate: stay.checkInDate,
        rentalTypeUsed: stay.rentalTypeUsed,
        agreedRate: stay.agreedRate,
        status: 'active',
        createdAt: DateTime.now(),
        person: guest,
        room: room,
      );
      _mockStays.add(newStay);
      _recalculateMockBilling(id);
      await _saveMockDataToDisk();
      return newStay;
    } else {
      final stayId = stay.id.isNotEmpty ? stay.id : const Uuid().v4();

      // Find local person and room if available to populate stay
      Person? guest = stay.person;
      if (guest == null) {
        final personMatches = _cachedPersons.where((p) => p.id == stay.personId);
        if (personMatches.isNotEmpty) guest = personMatches.first;
      }

      Room? room = stay.room;
      if (room == null) {
        final propRooms = _cachedRooms[stay.propertyId];
        if (propRooms != null) {
          final roomMatches = propRooms.where((r) => r.id == stay.roomId);
          if (roomMatches.isNotEmpty) room = roomMatches.first;
        }
      }

      // Optimistically increment room occupancy locally
      final propRooms = _cachedRooms[stay.propertyId];
      if (propRooms != null) {
        final rIdx = propRooms.indexWhere((r) => r.id == stay.roomId);
        if (rIdx != -1) {
          final r = propRooms[rIdx];
          final updatedRoom = Room(
            id: r.id,
            propertyId: r.propertyId,
            roomNumber: r.roomNumber,
            capacity: r.capacity,
            currentOccupancy: r.currentOccupancy + 1,
            rentalType: r.rentalType,
            dailyRate: r.dailyRate,
            monthlyRate: r.monthlyRate,
            hourlyRate: r.hourlyRate,
            minimumDays: r.minimumDays,
            minimumCharge: r.minimumCharge,
            status: r.currentOccupancy + 1 >= r.capacity ? RoomStatus.full : RoomStatus.available,
            photos: r.photos,
            createdAt: r.createdAt,
          );
          propRooms[rIdx] = updatedRoom;
          room = updatedRoom;
        }
      }

      final newStay = Stay(
        id: stayId,
        personId: stay.personId,
        roomId: stay.roomId,
        propertyId: stay.propertyId,
        ownerId: ownerId,
        checkInDate: stay.checkInDate,
        rentalTypeUsed: stay.rentalTypeUsed,
        agreedRate: stay.agreedRate,
        status: 'active',
        createdAt: stay.createdAt,
        person: guest,
        room: room,
      );

      // Optimistically add to local cache & disk
      _cachedStays.removeWhere((s) => s.id == stayId);
      _cachedStays.add(newStay);
      await _saveOfflineDataToDisk();

      final payload = newStay.toDatabaseJson();
      payload['owner_id'] = ownerId;

      try {
        final res = await Supabase.instance.client
            .from('stays')
            .insert(payload)
            .select('*, persons(*), rooms(*)')
            .single();
        final serverStay = Stay.fromJson(res);
        final idx = _cachedStays.indexWhere((s) => s.id == stayId);
        if (idx != -1) _cachedStays[idx] = serverStay;
        await _saveOfflineDataToDisk();
        return serverStay;
      } catch (e) {
        debugPrint('Offline: queued addStay ($e)');
        _queuePendingSync(table: 'stays', action: 'insert', data: payload);
        return newStay;
      }
    }
  }

  Future<void> checkOutStay(String stayId, DateTime checkOutDate) async {
    if (_useMock) {
      final idx = _mockStays.indexWhere((s) => s.id == stayId);
      if (idx != -1) {
        final stay = _mockStays[idx];

        // Decrement room occupancy
        final roomIdx = _mockRooms.indexWhere((r) => r.id == stay.roomId);
        if (roomIdx != -1) {
          final r = _mockRooms[roomIdx];
          _mockRooms[roomIdx] = Room(
            id: r.id,
            propertyId: r.propertyId,
            roomNumber: r.roomNumber,
            capacity: r.capacity,
            currentOccupancy: (r.currentOccupancy - 1).clamp(0, r.capacity),
            rentalType: r.rentalType,
            dailyRate: r.dailyRate,
            monthlyRate: r.monthlyRate,
            hourlyRate: r.hourlyRate,
            minimumDays: r.minimumDays,
            minimumCharge: r.minimumCharge,
            status: RoomStatus.available,
            photos: r.photos,
            createdAt: r.createdAt,
          );
        }

        _mockStays[idx] = Stay(
          id: stay.id,
          personId: stay.personId,
          roomId: stay.roomId,
          propertyId: stay.propertyId,
          ownerId: stay.ownerId,
          checkInDate: stay.checkInDate,
          checkOutDate: checkOutDate,
          rentalTypeUsed: stay.rentalTypeUsed,
          agreedRate: stay.agreedRate,
          status: 'checked_out',
          createdAt: stay.createdAt,
          person: stay.person,
          room: _mockRooms[roomIdx],
        );
        _recalculateMockBilling(stayId);
        await _saveMockDataToDisk();
      }
    } else {
      // 1. Optimistically update local stay in cache
      final idx = _cachedStays.indexWhere((s) => s.id == stayId);
      if (idx != -1) {
        final stay = _cachedStays[idx];

        // Decrement room occupancy locally
        final propRooms = _cachedRooms[stay.propertyId];
        if (propRooms != null) {
          final rIdx = propRooms.indexWhere((r) => r.id == stay.roomId);
          if (rIdx != -1) {
            final r = propRooms[rIdx];
            propRooms[rIdx] = Room(
              id: r.id,
              propertyId: r.propertyId,
              roomNumber: r.roomNumber,
              capacity: r.capacity,
              currentOccupancy: (r.currentOccupancy - 1).clamp(0, r.capacity),
              rentalType: r.rentalType,
              dailyRate: r.dailyRate,
              monthlyRate: r.monthlyRate,
              hourlyRate: r.hourlyRate,
              minimumDays: r.minimumDays,
              minimumCharge: r.minimumCharge,
              status: RoomStatus.available,
              photos: r.photos,
              createdAt: r.createdAt,
            );
          }
        }

        _cachedStays[idx] = Stay(
          id: stay.id,
          personId: stay.personId,
          roomId: stay.roomId,
          propertyId: stay.propertyId,
          ownerId: stay.ownerId,
          checkInDate: stay.checkInDate,
          checkOutDate: checkOutDate,
          rentalTypeUsed: stay.rentalTypeUsed,
          agreedRate: stay.agreedRate,
          status: 'checked_out',
          createdAt: stay.createdAt,
          person: stay.person,
          room: stay.room,
        );
        await _saveOfflineDataToDisk();
      }

      // 2. Try Supabase update or queue
      final updateData = {
        'check_out_date': checkOutDate.toIso8601String(),
        'status': 'checked_out',
      };
      try {
        await Supabase.instance.client
            .from('stays')
            .update(updateData)
            .eq('id', stayId);
      } catch (e) {
        debugPrint('Offline: queued checkOutStay ($e)');
        _queuePendingSync(table: 'stays', action: 'update', id: stayId, data: updateData);
      }
    }
  }

  Future<void> updateStayRate(String stayId, double newRate, {RentalBillingType? billingType}) async {
    if (_useMock) {
      final idx = _mockStays.indexWhere((s) => s.id == stayId);
      if (idx != -1) {
        final stay = _mockStays[idx];
        _mockStays[idx] = Stay(
          id: stay.id,
          personId: stay.personId,
          roomId: stay.roomId,
          propertyId: stay.propertyId,
          ownerId: stay.ownerId,
          checkInDate: stay.checkInDate,
          checkOutDate: stay.checkOutDate,
          rentalTypeUsed: billingType ?? stay.rentalTypeUsed,
          agreedRate: newRate,
          status: stay.status,
          createdAt: stay.createdAt,
          person: stay.person,
          room: stay.room,
        );
        _recalculateMockBilling(stayId);
        await _saveMockDataToDisk();
      }
    } else {
      final idx = _cachedStays.indexWhere((s) => s.id == stayId);
      if (idx != -1) {
        final stay = _cachedStays[idx];
        _cachedStays[idx] = Stay(
          id: stay.id,
          personId: stay.personId,
          roomId: stay.roomId,
          propertyId: stay.propertyId,
          ownerId: stay.ownerId,
          checkInDate: stay.checkInDate,
          checkOutDate: stay.checkOutDate,
          rentalTypeUsed: billingType ?? stay.rentalTypeUsed,
          agreedRate: newRate,
          status: stay.status,
          createdAt: stay.createdAt,
          person: stay.person,
          room: stay.room,
        );
        await _saveOfflineDataToDisk();
      }

      final updateData = <String, dynamic>{
        'agreed_rate': newRate,
        if (billingType != null) 'rental_type_used': billingType.toString().split('.').last,
      };
      try {
        await Supabase.instance.client
            .from('stays')
            .update(updateData)
            .eq('id', stayId);
      } catch (e) {
        debugPrint('Offline: queued updateStayRate ($e)');
        _queuePendingSync(table: 'stays', action: 'update', id: stayId, data: updateData);
      }
    }
  }

  Future<void> updateStayCheckInDate(String stayId, DateTime newCheckInDate) async {
    if (_useMock) {
      final idx = _mockStays.indexWhere((s) => s.id == stayId);
      if (idx != -1) {
        final stay = _mockStays[idx];
        _mockStays[idx] = Stay(
          id: stay.id,
          personId: stay.personId,
          roomId: stay.roomId,
          propertyId: stay.propertyId,
          ownerId: stay.ownerId,
          checkInDate: newCheckInDate,
          checkOutDate: stay.checkOutDate,
          rentalTypeUsed: stay.rentalTypeUsed,
          agreedRate: stay.agreedRate,
          status: stay.status,
          createdAt: stay.createdAt,
          person: stay.person,
          room: stay.room,
        );
        _recalculateMockBilling(stayId);
        await _saveMockDataToDisk();
      }
    } else {
      final idx = _cachedStays.indexWhere((s) => s.id == stayId);
      if (idx != -1) {
        final stay = _cachedStays[idx];
        _cachedStays[idx] = Stay(
          id: stay.id,
          personId: stay.personId,
          roomId: stay.roomId,
          propertyId: stay.propertyId,
          ownerId: stay.ownerId,
          checkInDate: newCheckInDate,
          checkOutDate: stay.checkOutDate,
          rentalTypeUsed: stay.rentalTypeUsed,
          agreedRate: stay.agreedRate,
          status: stay.status,
          createdAt: stay.createdAt,
          person: stay.person,
          room: stay.room,
        );
        await _saveOfflineDataToDisk();
      }

      final updateData = <String, dynamic>{
        'check_in_date': newCheckInDate.toIso8601String(),
      };
      try {
        await Supabase.instance.client
            .from('stays')
            .update(updateData)
            .eq('id', stayId);
      } catch (e) {
        debugPrint('Offline: queued updateStayCheckInDate ($e)');
        _queuePendingSync(table: 'stays', action: 'update', id: stayId, data: updateData);
      }
    }
  }

  Future<void> transferStayRoom({
    required String stayId,
    required String targetPropertyId,
    required String targetRoomId,
    required double newRate,
    RentalBillingType? newBillingType,
    DateTime? transferDate,
    String? remarks,
  }) async {
    if (_useMock) {
      final idx = _mockStays.indexWhere((s) => s.id == stayId);
      if (idx == -1) return;
      final stay = _mockStays[idx];
      final oldRoomId = stay.roomId;

      // 1. Decrement old room occupancy
      final oldRoomIdx = _mockRooms.indexWhere((r) => r.id == oldRoomId);
      if (oldRoomIdx != -1) {
        final r = _mockRooms[oldRoomIdx];
        final newOcc = (r.currentOccupancy - 1).clamp(0, r.capacity);
        _mockRooms[oldRoomIdx] = Room(
          id: r.id,
          propertyId: r.propertyId,
          roomNumber: r.roomNumber,
          capacity: r.capacity,
          currentOccupancy: newOcc,
          rentalType: r.rentalType,
          dailyRate: r.dailyRate,
          monthlyRate: r.monthlyRate,
          hourlyRate: r.hourlyRate,
          minimumDays: r.minimumDays,
          minimumCharge: r.minimumCharge,
          status: RoomStatus.available,
          photos: r.photos,
          createdAt: r.createdAt,
        );
      }

      // 2. Increment new room occupancy
      final newRoomIdx = _mockRooms.indexWhere((r) => r.id == targetRoomId);
      Room? targetRoom;
      if (newRoomIdx != -1) {
        final r = _mockRooms[newRoomIdx];
        final newOcc = (r.currentOccupancy + 1).clamp(0, r.capacity);
        targetRoom = Room(
          id: r.id,
          propertyId: r.propertyId,
          roomNumber: r.roomNumber,
          capacity: r.capacity,
          currentOccupancy: newOcc,
          rentalType: r.rentalType,
          dailyRate: r.dailyRate,
          monthlyRate: r.monthlyRate,
          hourlyRate: r.hourlyRate,
          minimumDays: r.minimumDays,
          minimumCharge: r.minimumCharge,
          status: newOcc >= r.capacity ? RoomStatus.full : RoomStatus.available,
          photos: r.photos,
          createdAt: r.createdAt,
        );
        _mockRooms[newRoomIdx] = targetRoom;
      }

      // 3. Update Stay
      _mockStays[idx] = Stay(
        id: stay.id,
        personId: stay.personId,
        roomId: targetRoomId,
        propertyId: targetPropertyId,
        ownerId: stay.ownerId,
        checkInDate: stay.checkInDate,
        checkOutDate: stay.checkOutDate,
        rentalTypeUsed: newBillingType ?? stay.rentalTypeUsed,
        agreedRate: newRate,
        status: stay.status,
        createdAt: stay.createdAt,
        person: stay.person,
        room: targetRoom ?? stay.room,
      );

      _recalculateMockBilling(stayId);
      await _saveMockDataToDisk();
    } else {
      final idx = _cachedStays.indexWhere((s) => s.id == stayId);
      if (idx == -1) return;
      final stay = _cachedStays[idx];
      final oldRoomId = stay.roomId;
      final oldPropertyId = stay.propertyId;

      // 1. Decrement old room occupancy locally
      final oldPropRooms = _cachedRooms[oldPropertyId];
      if (oldPropRooms != null) {
        final rIdx = oldPropRooms.indexWhere((r) => r.id == oldRoomId);
        if (rIdx != -1) {
          final r = oldPropRooms[rIdx];
          final newOcc = (r.currentOccupancy - 1).clamp(0, r.capacity);
          oldPropRooms[rIdx] = Room(
            id: r.id,
            propertyId: r.propertyId,
            roomNumber: r.roomNumber,
            capacity: r.capacity,
            currentOccupancy: newOcc,
            rentalType: r.rentalType,
            dailyRate: r.dailyRate,
            monthlyRate: r.monthlyRate,
            hourlyRate: r.hourlyRate,
            minimumDays: r.minimumDays,
            minimumCharge: r.minimumCharge,
            status: RoomStatus.available,
            photos: r.photos,
            createdAt: r.createdAt,
          );
        }
      }

      // 2. Increment new room occupancy locally
      Room? targetRoom;
      final targetPropRooms = _cachedRooms[targetPropertyId];
      if (targetPropRooms != null) {
        final rIdx = targetPropRooms.indexWhere((r) => r.id == targetRoomId);
        if (rIdx != -1) {
          final r = targetPropRooms[rIdx];
          final newOcc = (r.currentOccupancy + 1).clamp(0, r.capacity);
          targetRoom = Room(
            id: r.id,
            propertyId: r.propertyId,
            roomNumber: r.roomNumber,
            capacity: r.capacity,
            currentOccupancy: newOcc,
            rentalType: r.rentalType,
            dailyRate: r.dailyRate,
            monthlyRate: r.monthlyRate,
            hourlyRate: r.hourlyRate,
            minimumDays: r.minimumDays,
            minimumCharge: r.minimumCharge,
            status: newOcc >= r.capacity ? RoomStatus.full : RoomStatus.available,
            photos: r.photos,
            createdAt: r.createdAt,
          );
          targetPropRooms[rIdx] = targetRoom;
        }
      }

      // 3. Update Stay locally
      final updatedStay = Stay(
        id: stay.id,
        personId: stay.personId,
        roomId: targetRoomId,
        propertyId: targetPropertyId,
        ownerId: stay.ownerId,
        checkInDate: stay.checkInDate,
        checkOutDate: stay.checkOutDate,
        rentalTypeUsed: newBillingType ?? stay.rentalTypeUsed,
        agreedRate: newRate,
        status: stay.status,
        createdAt: stay.createdAt,
        person: stay.person,
        room: targetRoom ?? stay.room,
      );
      _cachedStays[idx] = updatedStay;
      await _saveOfflineDataToDisk();

      // 4. Update Supabase stays
      final stayUpdates = <String, dynamic>{
        'room_id': targetRoomId,
        'property_id': targetPropertyId,
        'agreed_rate': newRate,
        if (newBillingType != null) 'rental_type_used': newBillingType.toString().split('.').last,
      };

      try {
        await Supabase.instance.client.from('stays').update(stayUpdates).eq('id', stayId);
      } catch (e) {
        debugPrint('Offline: queued stay transfer update ($e)');
        _queuePendingSync(table: 'stays', action: 'update', id: stayId, data: stayUpdates);
      }

      // 5. Update Supabase rooms occupancy & reconcile
      reconcileRoomsWithActiveStays(_cachedRooms[oldPropertyId] ?? [], propertyId: oldPropertyId);
      if (targetPropertyId != oldPropertyId) {
        reconcileRoomsWithActiveStays(_cachedRooms[targetPropertyId] ?? [], propertyId: targetPropertyId);
      }
    }
  }

  // --- Payments API ---

  Future<List<Payment>> getPayments(String stayId) async {
    if (_useMock || stayId.startsWith('person-')) {
      return _mockPayments.where((p) => p.stayId == stayId).toList();
    } else {
      final cached = _cachedPayments[stayId];
      if (cached != null && cached.isNotEmpty) {
        _backgroundSyncPayments(stayId);
        return List.from(cached);
      }

      try {
        final res = await Supabase.instance.client
            .from('payments')
            .select()
            .eq('stay_id', stayId)
            .order('paid_at', ascending: false);
        final list = (res as List).map((json) => Payment.fromJson(json)).toList();
        _cachedPayments[stayId] = list;
        await _saveOfflineDataToDisk();
        return list;
      } catch (e) {
        debugPrint('Error fetching payments from Supabase (serving cache): $e');
        return cached ?? [];
      }
    }
  }

  void _backgroundSyncPayments(String stayId) {
    final lastSync = _lastPaymentsSync[stayId];
    if (lastSync != null && DateTime.now().difference(lastSync).inMinutes < 3) {
      return;
    }
    _lastPaymentsSync[stayId] = DateTime.now();
    Future.microtask(() async {
      try {
        final res = await Supabase.instance.client
            .from('payments')
            .select()
            .eq('stay_id', stayId)
            .order('paid_at', ascending: false);
        final list = (res as List).map((json) => Payment.fromJson(json)).toList();
        _cachedPayments[stayId] = list;
        await _saveOfflineDataToDisk();
      } catch (e) {
        debugPrint('Notice in background payments sync: $e');
      }
    });
  }

  Future<Payment> addPayment(Payment payment) async {
    final ownerId = currentOwnerId ?? _currentOwnerId ?? '11111111-1111-1111-1111-111111111111';
    if (_useMock) {
      final id = 'pay-${DateTime.now().millisecondsSinceEpoch}';
      final newPayment = Payment(
        id: id,
        stayId: payment.stayId,
        personId: payment.personId,
        ownerId: _currentOwnerId!,
        paymentType: payment.paymentType,
        amount: payment.amount,
        paymentMode: payment.paymentMode,
        paidAt: payment.paidAt,
        notes: payment.notes,
        recordedBy: _currentOwnerId!,
        createdAt: DateTime.now(),
      );
      _mockPayments.add(newPayment);
      _recalculateMockBilling(payment.stayId);
      await _saveMockDataToDisk();
      return newPayment;
    } else {
      final payId = payment.id.isNotEmpty ? payment.id : const Uuid().v4();
      final newPayment = Payment(
        id: payId,
        stayId: payment.stayId,
        personId: payment.personId,
        ownerId: ownerId,
        paymentType: payment.paymentType,
        amount: payment.amount,
        paymentMode: payment.paymentMode,
        paidAt: payment.paidAt,
        notes: payment.notes,
        recordedBy: ownerId,
        createdAt: payment.createdAt,
      );

      // Optimistically add to local cache & disk
      _cachedPayments.putIfAbsent(payment.stayId, () => []);
      _cachedPayments[payment.stayId]!.removeWhere((p) => p.id == payId);
      _cachedPayments[payment.stayId]!.insert(0, newPayment);
      await _saveOfflineDataToDisk();

      final payload = newPayment.toJson();
      payload['id'] = payId;
      payload['owner_id'] = ownerId;
      payload['recorded_by'] = ownerId;

      try {
        final res = await Supabase.instance.client
            .from('payments')
            .insert(payload)
            .select()
            .single();
        final serverPayment = Payment.fromJson(res);
        final list = _cachedPayments[payment.stayId];
        if (list != null) {
          final idx = list.indexWhere((p) => p.id == payId);
          if (idx != -1) list[idx] = serverPayment;
        }
        await _saveOfflineDataToDisk();
        return serverPayment;
      } catch (e) {
        debugPrint('Offline: queued addPayment ($e)');
        _queuePendingSync(table: 'payments', action: 'insert', data: payload);
        return newPayment;
      }
    }
  }

  // --- Billing Summary API ---

  Future<BillingSummary?> getBillingSummary(String stayId) async {
    if (_useMock || stayId.startsWith('person-')) {
      final matches = _mockBillingSummaries.where((s) => s.stayId == stayId);
      if (matches.isNotEmpty) return matches.first;
      return _calculateLocalBillingSummary(stayId);
    } else {
      // 1. Calculate local billing summary instantly (0 network wait, 0 DB read)
      final localBilling = _calculateLocalBillingSummary(stayId);

      // 2. Try fetching updated summary from Supabase in real mode
      try {
        await Supabase.instance.client.rpc('calculate_stay_billing', params: {
          'target_stay_id': stayId,
        });

        final res = await Supabase.instance.client
            .from('billing_summary')
            .select()
            .eq('stay_id', stayId)
            .maybeSingle();
        if (res != null) {
          final serverSummary = BillingSummary.fromJson(res);
          // If server calculated negative due or has time skew, fallback to sanitized local calculation
          if (serverSummary.totalAmountDue < 0) {
            return localBilling;
          }
          return serverSummary;
        }
        return localBilling;
      } catch (e) {
        // Return local calculated billing summary when offline or if RPC fails
        return localBilling;
      }
    }
  }

  BillingSummary getLocalBillingSummary(String stayId) => _calculateLocalBillingSummary(stayId);

  BillingSummary _calculateLocalBillingSummary(String stayId) {
    final stays = _useMock ? _mockStays : _cachedStays;
    final payments = _useMock
        ? _mockPayments.where((p) => p.stayId == stayId).toList()
        : (_cachedPayments[stayId] ?? []);

    Stay? stay;
    for (var s in stays) {
      if (s.id == stayId) {
        stay = s;
        break;
      }
    }

    if (stay == null) {
      return BillingSummary(
        stayId: stayId,
        totalAmountDue: 0.0,
        totalPaid: 0.0,
        pendingAmount: 0.0,
        lastCalculatedAt: DateTime.now(),
      );
    }

    final now = DateTime.now();
    final checkIn = stay.checkInDate.toLocal();
    final checkOut = (stay.checkOutDate ?? now).toLocal();
    final duration = checkOut.isBefore(checkIn) ? Duration.zero : checkOut.difference(checkIn);
    final totalHours = duration.inSeconds / 3600.0;
    double due = 0.0;

    switch (stay.rentalTypeUsed) {
      case RentalBillingType.hourly:
        final hours = max(1.0, totalHours.ceilToDouble());
        due = stay.agreedRate * hours;
        break;
      case RentalBillingType.daily:
        final days = max(1, (totalHours / 24.0).ceil());
        due = stay.agreedRate * days;
        break;
      case RentalBillingType.monthly:
        final room = stay.room ?? getCachedRoomById(stay.roomId, stay.propertyId);
        final minDays = room?.minimumDays ?? 0;
        final minCharge = room?.minimumCharge ?? 0.0;
        final stayDays = max(1, (duration.inSeconds / 86400.0).ceil());
        due = calculateMonthlyRentDue(
          agreedRate: stay.agreedRate,
          stayDays: stayDays,
          minDays: minDays,
          minCharge: minCharge,
        );
        break;
    }
    due = max(0.0, due);

    double paid = 0.0;
    for (var p in payments) {
      if (p.paymentType == PaymentCategory.refund) {
        paid -= p.amount;
      } else {
        paid += p.amount;
      }
    }

    return BillingSummary(
      stayId: stayId,
      totalAmountDue: double.parse(due.toStringAsFixed(2)),
      totalPaid: double.parse(paid.toStringAsFixed(2)),
      pendingAmount: double.parse((due - paid).toStringAsFixed(2)),
      lastCalculatedAt: DateTime.now(),
    );
  }

  // --- Storage API ---

  Future<String> uploadImage(String bucketName, File imageFile) async {
    try {
      // 1. Optimize image resolution & compress to lightweight JPEG before storing or uploading
      final optimizedFile = await AppImageOptimizer.optimizeForBucket(bucketName, imageFile);

      final appDir = await getApplicationDocumentsDirectory();
      const ext = 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.$ext';
      final localDir = Directory('${appDir.path}/offline_photos/$bucketName');
      if (!await localDir.exists()) await localDir.create(recursive: true);
      final localFile = await optimizedFile.copy('${localDir.path}/$fileName');

      if (_useMock) {
        return localFile.path;
      }

      final ownerId = currentOwnerId ?? 'global';
      final filePath = '$ownerId/$fileName';

      try {
        await Supabase.instance.client.storage
            .from(bucketName)
            .upload(filePath, localFile, fileOptions: const FileOptions(upsert: true));

        final publicUrl = Supabase.instance.client.storage
            .from(bucketName)
            .getPublicUrl(filePath);
        return publicUrl;
      } on StorageException catch (se) {
        debugPrint('Supabase StorageException on $bucketName: ${se.message} (${se.statusCode})');
        // Auto-create bucket if not found
        if (se.statusCode == '404' || se.message.toLowerCase().contains('not found')) {
          try {
            await Supabase.instance.client.storage.createBucket(
              bucketName,
              const BucketOptions(public: true),
            );
            await Supabase.instance.client.storage
                .from(bucketName)
                .upload(filePath, localFile, fileOptions: const FileOptions(upsert: true));
            return Supabase.instance.client.storage.from(bucketName).getPublicUrl(filePath);
          } catch (createErr) {
            debugPrint('Could not auto-create bucket $bucketName: $createErr. Using permanent local path.');
          }
        }
        // Fallback gracefully to permanent local file so check-in never fails
        return localFile.path;
      } catch (e) {
        debugPrint('Storage upload failed ($e): falling back to local file ${localFile.path}');
        return localFile.path;
      }
    } catch (e) {
      debugPrint('Local photo copy failed ($e): returning original file ${imageFile.path}');
      return imageFile.path;
    }
  }

  Future<void> sendContactMessage({
    required String name,
    required String contact,
    required String subject,
    required String message,
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      return;
    }
    try {
      final ownerId = currentOwnerId;
      await Supabase.instance.client.from('contact_messages').insert({
        if (ownerId != null && ownerId.isNotEmpty) 'owner_id': ownerId,
        'name': name,
        'contact': contact,
        'subject': subject,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Notice sending contact message: $e');
    }
  }
}

class ReportsLog {
  final String id;
  final String personId;
  final String reportedByOwnerId;
  final ReportCategory reportType;
  final String description;
  final DateTime createdAt;

  ReportsLog({
    required this.id,
    required this.personId,
    required this.reportedByOwnerId,
    required this.reportType,
    required this.description,
    required this.createdAt,
  });
}
