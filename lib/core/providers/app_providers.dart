import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/app_update_service.dart';

final dbService = SupabaseService.instance;
final dbServiceProvider = Provider<SupabaseService>((ref) => SupabaseService.instance);

// --- Auth Provider ---
class AuthNotifier extends StateNotifier<AsyncValue<Owner?>> {
  final SupabaseService _db;
  StreamSubscription<AuthState>? _authSubscription;

  /// [service] is injectable so the notifier can be tested without a backend.
  AuthNotifier({SupabaseService? service})
      : _db = service ?? dbService,
        super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    if (!_db.isUsingMock) {
      try {
        // 1. If an active session is already present in memory on startup, load profile immediately
        if (Supabase.instance.client.auth.currentSession != null) {
          checkCurrentUser(showGlobalLoading: false);
        }

        // 2. Listen to all auth state changes, including initialSession restored from local storage!
        _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final event = data.event;
          if (event == AuthChangeEvent.initialSession) {
            if (data.session != null) {
              await checkCurrentUser(showGlobalLoading: false);
            } else {
              // No persisted session found
              if (Supabase.instance.client.auth.currentSession == null) {
                state = const AsyncValue.data(null);
              }
            }
          } else if (event == AuthChangeEvent.signedIn ||
                     event == AuthChangeEvent.tokenRefreshed ||
                     event == AuthChangeEvent.userUpdated) {
            await checkCurrentUser(showGlobalLoading: false);
          } else if (event == AuthChangeEvent.signedOut) {
            state = const AsyncValue.data(null);
          }
        });

        // 3. Safety fallback: if initialSession event does not resolve within 2.5s, check user
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && state.isLoading) {
            checkCurrentUser(showGlobalLoading: false);
          }
        });
      } catch (e) {
        debugPrint('Error setting up auth listener: $e');
        checkCurrentUser();
      }
    } else {
      checkCurrentUser();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> checkCurrentUser({bool showGlobalLoading = true}) async {
    if (showGlobalLoading) {
      state = const AsyncValue.loading();
    }
    try {
      final owner = await _db.getOwnerProfile();
      state = AsyncValue.data(owner);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final success = await _db.signIn(email, password);
      if (success) {
        await checkCurrentUser();
        return null;
      }
      return 'Invalid email or password. Please try again.';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
        return 'Network error: Unable to connect to server. Please check your internet connection.';
      }
      if (e is AuthException) {
        return e.message;
      }
      return msg.replaceAll('Exception: ', '');
    }
  }

  Future<String?> register(
    String email,
    String password,
    String fullName,
    String businessName,
    String mobile,
  ) async {
    try {
      final success = await _db.signUp(email, password, fullName, businessName, mobile);
      if (success) {
        await checkCurrentUser();
        return null;
      }
      return 'Registration failed. Please check your inputs and try again.';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
        return 'Network error: Unable to connect to server. Please check your internet connection.';
      }
      if (e is AuthException) {
        return e.message;
      }
      return msg.replaceAll('Exception: ', '');
    }
  }

  Future<String?> updateProfile({
    String? fullName,
    String? businessName,
    String? businessAddress,
    String? mobileNo,
    String? avatarUrl,
  }) async {
    try {
      await _db.updateOwnerProfile(
        fullName: fullName,
        businessName: businessName,
        businessAddress: businessAddress,
        mobileNo: mobileNo,
        avatarUrl: avatarUrl,
      );
      final updatedOwner = await _db.getOwnerProfile();
      state = AsyncValue.data(updatedOwner);
      return null;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
        return 'Network error: Unable to connect to server. Please check your internet connection.';
      }
      return msg.replaceAll('Exception: ', '');
    }
  }

  Future<void> uploadAndSetAvatar(File file) async {
    try {
      final avatarUrl = await _db.uploadOwnerAvatar(file);
      if (avatarUrl != null) {
        await updateProfile(avatarUrl: avatarUrl);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Re-reads the owner (and therefore the server-granted plan).
  Future<void> refreshOwner() async {
    try {
      final updatedOwner = await _db.getOwnerProfile();
      state = AsyncValue.data(updatedOwner);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Signs out. Throws (and leaves the user signed in) if some changes could not be
  /// uploaded yet, so nothing is silently lost.
  Future<void> logout() async {
    final previous = state;
    state = const AsyncValue.loading();
    try {
      await _db.signOut();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  /// Deletes the account. Throws (and leaves the user signed in) if the server
  /// deletion failed, instead of claiming success.
  Future<void> deleteAccount() async {
    final previous = state;
    state = const AsyncValue.loading();
    try {
      await _db.deleteAccount();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Owner?>>((ref) {
  return AuthNotifier();
});


// --- Properties Provider ---
class PropertiesNotifier extends StateNotifier<AsyncValue<List<Property>>> {
  PropertiesNotifier() : super(const AsyncValue.loading()) {
    if (dbService.currentOwnerId != null) {
      loadProperties();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> loadProperties() async {
    state = const AsyncValue.loading();
    try {
      final list = await dbService.getProperties();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addProperty(Property property) async {
    final newProp = await dbService.addProperty(property);
    state.whenData((list) {
      state = AsyncValue.data([...list, newProp]);
    });
  }

  Future<void> updateProperty(Property property) async {
    try {
      await dbService.updateProperty(property);
      await loadProperties();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteProperty(String propertyId) async {
    try {
      await dbService.deleteProperty(propertyId);
      state.whenData((list) {
        state = AsyncValue.data(list.where((p) => p.id != propertyId).toList());
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final propertiesProvider = StateNotifierProvider<PropertiesNotifier, AsyncValue<List<Property>>>((ref) {
  final notifier = PropertiesNotifier();
  ref.listen<AsyncValue<Owner?>>(authProvider, (previous, next) {
    if (next.value != null) {
      notifier.loadProperties();
    } else {
      notifier.clear();
    }
  });
  return notifier;
});


// --- Rooms Provider ---
class RoomsNotifier extends StateNotifier<AsyncValue<List<Room>>> {
  final String propertyId;
  RoomsNotifier(this.propertyId) : super(const AsyncValue.loading()) {
    loadRooms();
  }

  Future<void> loadRooms() async {
    state = const AsyncValue.loading();
    try {
      final list = await dbService.getRooms(propertyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addRoom(Room room) async {
    try {
      final newRoom = await dbService.addRoom(room);
      state.whenData((list) {
        final existingWithoutNew = list.where((r) => r.id != newRoom.id).toList();
        state = AsyncValue.data([...existingWithoutNew, newRoom]);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateRoom(Room room) async {
    try {
      final updated = await dbService.updateRoom(room);
      state.whenData((list) {
        state = AsyncValue.data(list.map((r) => r.id == updated.id ? updated : r).toList());
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await dbService.deleteRoom(roomId, propertyId);
      state.whenData((list) {
        state = AsyncValue.data(list.where((r) => r.id != roomId).toList());
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final roomsProvider = StateNotifierProvider.family<RoomsNotifier, AsyncValue<List<Room>>, String>((ref, propertyId) {
  return RoomsNotifier(propertyId);
});


// --- Stays Provider ---
class StaysNotifier extends StateNotifier<AsyncValue<List<Stay>>> {
  StaysNotifier() : super(const AsyncValue.loading()) {
    if (dbService.currentOwnerId != null) {
      loadStays();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> loadStays() async {
    state = const AsyncValue.loading();
    try {
      final list = await dbService.getStays();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addStay(Stay stay) async {
    try {
      final newStay = await dbService.addStay(stay);
      state.whenData((list) {
        state = AsyncValue.data([...list, newStay]);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> checkOut(String stayId, DateTime checkOutDate) async {
    try {
      await dbService.checkOutStay(stayId, checkOutDate);
      await loadStays(); // Reload stays to sync updated checkout statuses and Room occupancy
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteGuest(String personId) async {
    try {
      await dbService.deletePerson(personId);
      await loadStays();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateStayRate(String stayId, double newRate, {RentalBillingType? billingType}) async {
    try {
      await dbService.updateStayRate(stayId, newRate, billingType: billingType);
      await loadStays();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateStayCheckInDate(String stayId, DateTime newCheckInDate) async {
    try {
      await dbService.updateStayCheckInDate(stayId, newCheckInDate);
      await loadStays();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
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
    try {
      await dbService.transferStayRoom(
        stayId: stayId,
        targetPropertyId: targetPropertyId,
        targetRoomId: targetRoomId,
        newRate: newRate,
        newBillingType: newBillingType,
        transferDate: transferDate,
        remarks: remarks,
      );
      await loadStays();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final staysProvider = StateNotifierProvider<StaysNotifier, AsyncValue<List<Stay>>>((ref) {
  final notifier = StaysNotifier();
  ref.listen<AsyncValue<Owner?>>(authProvider, (previous, next) {
    if (next.value != null) {
      notifier.loadStays();
    } else {
      notifier.clear();
    }
  });
  return notifier;
});


// --- Payments Provider ---
class PaymentsNotifier extends StateNotifier<AsyncValue<List<Payment>>> {
  final String stayId;
  PaymentsNotifier(this.stayId) : super(const AsyncValue.loading()) {
    loadPayments();
  }

  Future<void> loadPayments() async {
    state = const AsyncValue.loading();
    try {
      final list = await dbService.getPayments(stayId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addPayment(Payment payment) async {
    try {
      final newPay = await dbService.addPayment(payment);
      state.whenData((list) {
        state = AsyncValue.data([newPay, ...list]);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final paymentsProvider = StateNotifierProvider.family<PaymentsNotifier, AsyncValue<List<Payment>>, String>((ref, stayId) {
  return PaymentsNotifier(stayId);
});


// --- Billing Summary Provider ---
final billingSummaryProvider = FutureProvider.family<BillingSummary?, String>((ref, stayId) async {
  // Listen to payments changes to trigger recalculations
  ref.watch(paymentsProvider(stayId));
  return await dbService.getBillingSummary(stayId);
});


// --- Aadhaar Search Provider ---
class AadhaarSearchNotifier extends StateNotifier<AsyncValue<Person?>> {
  AadhaarSearchNotifier() : super(const AsyncValue.data(null));

  Future<void> search(String aadhaar) async {
    state = const AsyncValue.loading();
    try {
      final person = await dbService.searchGuestByAadhaar(aadhaar);
      state = AsyncValue.data(person);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

final aadhaarSearchProvider = StateNotifierProvider<AadhaarSearchNotifier, AsyncValue<Person?>>((ref) {
  return AadhaarSearchNotifier();
});


// --- Guest Stay History Provider ---
final guestStayHistoryProvider = FutureProvider.family<List<GuestStayHistory>, String>((ref, personId) async {
  return await dbService.getGuestStayHistory(personId);
});

// --- Text Size Scaling Provider (Persisted via SharedPreferences) ---
class TextScaleNotifier extends StateNotifier<double> {
  static const String _prefKey = 'app_text_scale_factor';

  TextScaleNotifier() : super(1.0) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScale = prefs.getDouble(_prefKey);
      if (savedScale != null) {
        state = savedScale;
      }
    } catch (_) {}
  }

  Future<void> setScale(double val) async {
    state = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKey, val);
    } catch (_) {}
  }
}

final textScaleFactorProvider = StateNotifierProvider<TextScaleNotifier, double>((ref) {
  return TextScaleNotifier();
});

// --- Home Navigation Index Provider ---
final homeNavIndexProvider = StateProvider<int>((ref) => 0);

// --- App Version & Update Provider ---
final appUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  return await AppUpdateService().fetchUpdateInfo();
});


