import 'dart:math';
import '../../../core/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/official_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../payments/presentation/payments_screen.dart';
import 'add_guest_flow.dart';
import 'edit_guest_screen.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import '../../properties/presentation/add_edit_property_screen.dart';

class GuestsScreen extends ConsumerStatefulWidget {
  const GuestsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GuestsScreen> createState() => _GuestsScreenState();
}

class _GuestsScreenState extends ConsumerState<GuestsScreen> {
  final _searchController = TextEditingController();
  bool _filterBlacklistedOnly = false;
  String? _selectedPropertyFilterId;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staysState = ref.watch(staysProvider);
    final properties = ref.watch(propertiesProvider).value ?? [];

    return ReplicaHeaderScaffold(
      title: 'All Guest Records',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryPill,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add New Guest', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddGuestFlow()),
          );
        },
      ),
      body: Column(
        children: [
          // Glass Filter & Search Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Aadhaar, or Mobile...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPill),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                ),
                const SizedBox(height: 12),
                // Pill Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _filterBlacklistedOnly = false;
                          _selectedPropertyFilterId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: (!_filterBlacklistedOnly && _selectedPropertyFilterId == null)
                                ? AppColors.primaryPill
                                : AppColors.neutralPill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'All Guests',
                            style: TextStyle(
                              color: (!_filterBlacklistedOnly && _selectedPropertyFilterId == null)
                                  ? Colors.white
                                  : AppColors.neutralPillText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          _filterBlacklistedOnly = true;
                          _selectedPropertyFilterId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _filterBlacklistedOnly ? AppColors.primaryPill : AppColors.neutralPill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                size: 14,
                                color: _filterBlacklistedOnly ? Colors.white : AppColors.alertRed,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Blacklisted Only',
                                style: TextStyle(
                                  color: _filterBlacklistedOnly ? Colors.white : AppColors.alertRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ...properties.map((p) {
                        final isSelected = _selectedPropertyFilterId == p.id;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_selectedPropertyFilterId == p.id) {
                                  _selectedPropertyFilterId = null;
                                } else {
                                  _selectedPropertyFilterId = p.id;
                                  _filterBlacklistedOnly = false;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryPill : AppColors.neutralPill,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.business_rounded,
                                    size: 13,
                                    color: isSelected ? Colors.white : AppColors.primaryPill,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.neutralPillText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Guest List Ledger
          Expanded(
            child: staysState.when(
              data: (stays) {
                // If a stay has null person, try looking it up from dbService
                final hydratedStays = stays.map((s) {
                  if (s.person == null) {
                    final p = dbService.getCachedPersonById(s.personId);
                    if (p != null) {
                      return Stay(
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
                        person: p,
                        room: s.room,
                      );
                    }
                  }
                  return s;
                }).toList();

                // Sort: active stays first, then latest checkInDate
                hydratedStays.sort((a, b) {
                  if (a.status == 'active' && b.status != 'active') return -1;
                  if (a.status != 'active' && b.status == 'active') return 1;
                  return b.checkInDate.compareTo(a.checkInDate);
                });

                final seenPersonKeys = <String>{};
                final uniqueStays = <Stay>[];

                for (var stay in hydratedStays) {
                  final guest = stay.person;
                  final key = guest != null && guest.aadhaarNo.isNotEmpty ? guest.aadhaarNo : stay.personId;
                  if (!seenPersonKeys.contains(key)) {
                    seenPersonKeys.add(key);
                    uniqueStays.add(stay);
                  }
                }

                // Only include owner-registered persons or persons blacklisted by THIS owner not yet in stays
                final currentOwner = dbService.currentOwnerId;
                for (var p in dbService.allCachedPersons) {
                  final key = p.aadhaarNo.isNotEmpty ? p.aadhaarNo : p.id;
                  if (!seenPersonKeys.contains(key)) {
                    final isCreatedByOwner = currentOwner != null && p.createdByOwnerId == currentOwner;
                    final isBlacklistedByOwner = currentOwner != null && p.blacklistedBy == currentOwner;

                    if (isCreatedByOwner || isBlacklistedByOwner) {
                      seenPersonKeys.add(key);
                      uniqueStays.add(
                        Stay(
                          id: 'person-${p.id}',
                          personId: p.id,
                          roomId: '',
                          propertyId: '',
                          ownerId: p.blacklistedBy?.isNotEmpty == true ? p.blacklistedBy! : p.createdByOwnerId,
                          checkInDate: p.blacklistedAt ?? p.createdAt,
                          checkOutDate: null,
                          rentalTypeUsed: RentalBillingType.monthly,
                          agreedRate: 0,
                          status: isBlacklistedByOwner ? 'blacklisted' : 'registered',
                          createdAt: p.blacklistedAt ?? p.createdAt,
                          person: p,
                        ),
                      );
                    }
                  }
                }

                // Sort: blacklisted by this owner and active stays first, then latest date
                uniqueStays.sort((a, b) {
                  final aPerson = a.person;
                  final bPerson = b.person;
                  final aBlack = aPerson != null && aPerson.isBlacklisted && ((aPerson.blacklistedBy != null && aPerson.blacklistedBy == currentOwner) || (a.ownerId == currentOwner && (aPerson.blacklistedBy == null || aPerson.blacklistedBy!.isEmpty)));
                  final bBlack = bPerson != null && bPerson.isBlacklisted && ((bPerson.blacklistedBy != null && bPerson.blacklistedBy == currentOwner) || (b.ownerId == currentOwner && (bPerson.blacklistedBy == null || bPerson.blacklistedBy!.isEmpty)));
                  if (aBlack && !bBlack) return -1;
                  if (!aBlack && bBlack) return 1;
                  if (a.status == 'active' && b.status != 'active') return -1;
                  if (a.status != 'active' && b.status == 'active') return 1;
                  return b.checkInDate.compareTo(a.checkInDate);
                });

                final filtered = uniqueStays.where((stay) {
                  final guest = stay.person;
                  if (guest == null) return false;
                  final matchesQuery = _searchQuery.isEmpty ||
                      guest.name.toLowerCase().contains(_searchQuery) ||
                      guest.aadhaarNo.contains(_searchQuery) ||
                      guest.mobileNo.contains(_searchQuery);

                  final isBlacklistedByThisOwner = guest.isBlacklisted &&
                      (guest.blacklistedBy == currentOwner ||
                       (stay.ownerId == currentOwner && (guest.blacklistedBy == null || guest.blacklistedBy!.isEmpty)));

                  final matchesBlacklist = !_filterBlacklistedOnly || isBlacklistedByThisOwner;
                  final matchesProperty = _selectedPropertyFilterId == null || stay.propertyId == _selectedPropertyFilterId;

                  return matchesQuery && matchesBlacklist && matchesProperty;
                }).toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(staysProvider.notifier).loadStays();
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'No guests match the search filters.\nSwipe down to refresh from Cloud.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final stay = filtered[index];
                    final guest = stay.person!;
                    final isBlacklistedByThisOwner = guest.isBlacklisted &&
                        (guest.blacklistedBy == currentOwner ||
                         (stay.ownerId == currentOwner && (guest.blacklistedBy == null || guest.blacklistedBy!.isEmpty)));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.glassCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: SizedBox(
                          width: 50,
                          height: 50,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isBlacklistedByThisOwner
                                        ? AppColors.alertRed
                                        : (stay.status == 'active' ? AppColors.verifiedGreen : AppColors.textMuted),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  backgroundImage: AppImageHelper.getImageProvider(guest.personPhoto),
                                  radius: 22,
                                ),
                              ),
                              Positioned(
                                bottom: -1,
                                right: -1,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: isBlacklistedByThisOwner
                                        ? AppColors.alertRed
                                        : (stay.status == 'active' ? AppColors.verifiedGreen : const Color(0xFF64748B)),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isBlacklistedByThisOwner
                                        ? Icons.warning_rounded
                                        : (stay.status == 'active' ? Icons.home_rounded : Icons.history_rounded),
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          guest.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (isBlacklistedByThisOwner) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.alertRed.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.alertRed.withOpacity(0.4)),
                                ),
                                child: Text(
                                  'BLACKLISTED: ${guest.blacklistReason ?? "Violation of rules"}',
                                  style: const TextStyle(
                                    color: AppColors.alertRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            Text(
                              'Aadhaar: ${guest.aadhaarNo} • Mob: ${guest.mobileNo}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Police Circle: ${guest.policeStationCircle.isNotEmpty ? guest.policeStationCircle : "Not Specified"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMain),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GuestDetailScreen(stay: stay),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading guest records: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// --- REFINED GUEST DETAIL VIEW ---
class GuestDetailScreen extends ConsumerStatefulWidget {
  final Stay stay;

  const GuestDetailScreen({Key? key, required this.stay}) : super(key: key);

  @override
  ConsumerState<GuestDetailScreen> createState() => _GuestDetailScreenState();
}

class _GuestDetailScreenState extends ConsumerState<GuestDetailScreen> {
  Owner? _blacklistingOwner;

  @override
  void initState() {
    super.initState();
    _loadBlacklistingOwner();
  }

  Future<void> _loadBlacklistingOwner() async {
    final guest = dbService.getCachedPersonById(widget.stay.personId) ?? widget.stay.person;
    if (guest != null && guest.isBlacklisted) {
      final ownerId = guest.blacklistedBy?.isNotEmpty == true
          ? guest.blacklistedBy!
          : guest.createdByOwnerId;
      if (ownerId.isNotEmpty) {
        final owner = await dbService.getOwnerById(ownerId);
        if (mounted) {
          setState(() => _blacklistingOwner = owner);
        }
      }
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch phone dialer for $phoneNumber')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final phoneWithCountry = cleaned.length == 10 ? '91$cleaned' : cleaned;
    final Uri url = Uri.parse('https://wa.me/$phoneWithCountry');
    
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp app.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open WhatsApp: $e')),
        );
      }
    }
  }

  void _confirmDeleteGuest(BuildContext context, Person guest) {
    if (guest.isBlacklisted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.block_rounded, color: AppColors.alertRed, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('Cannot Delete Blacklisted Guest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: Text(
            'Guest "${guest.name}" is currently blacklisted.\n\n'
            'A blacklisted guest profile cannot be deleted. If you need to delete this profile, you must first remove their blacklist status (un-blacklist) and then proceed with deletion.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: AppColors.alertRed, size: 28),
            SizedBox(width: 10),
            Text('Delete Guest Profile?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${guest.name}"?\n\nThis will permanently delete this guest\'s identity record and remove all associated stay and payment ledger history. This action cannot be undone.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(staysProvider.notifier).deleteGuest(guest.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Guest profile "${guest.name}" deleted successfully.')),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete guest profile: $e'), backgroundColor: AppColors.alertRed),
                  );
                }
              }
            },
            child: const Text('DELETE GUEST', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditCheckInDateDialog(BuildContext context) {
    DateTime selectedDate = widget.stay.checkInDate.toLocal();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: const [
              Icon(Icons.edit_calendar_rounded, color: AppColors.primaryPill),
              SizedBox(width: 8),
              Text('EDIT CHECK-IN DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update the registered check-in date for this active stay. Dues and stay duration will automatically recalculate.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.glassBorder),
                ),
                leading: const Icon(Icons.login_rounded, color: AppColors.primaryPill),
                title: Text(
                  DateFormat('dd MMMM yyyy').format(selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                onTap: () async {
                  final now = DateTime.now();
                  final firstDate = DateTime(2000, 1, 1);
                  final lastDate = now.add(const Duration(days: 365 * 2));
                  final initialDate = selectedDate.isBefore(firstDate)
                      ? firstDate
                      : (selectedDate.isAfter(lastDate) ? lastDate : selectedDate);

                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    helpText: 'Select Check-in Date',
                  );
                  if (picked != null) {
                    setDlgState(() {
                      selectedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        selectedDate.hour,
                        selectedDate.minute,
                        selectedDate.second,
                      );
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(staysProvider.notifier).updateStayCheckInDate(
                      widget.stay.id,
                      selectedDate,
                    );
                ref.invalidate(billingSummaryProvider(widget.stay.id));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Check-in date updated successfully!'),
                      backgroundColor: AppColors.verifiedGreen,
                    ),
                  );
                  Navigator.pop(context); // Close detail screen so it refreshes cleanly
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRentDialog(BuildContext context) {
    final rateController = TextEditingController(text: widget.stay.agreedRate.toStringAsFixed(0));
    var selectedType = widget.stay.rentalTypeUsed;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: const [
              Icon(Icons.currency_rupee_rounded, color: AppColors.primaryPill),
              SizedBox(width: 8),
              Text('EDIT RENT / TARIFF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<RentalBillingType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Billing Frequency',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: RentalBillingType.monthly, child: Text('Monthly Rate')),
                    DropdownMenuItem(value: RentalBillingType.daily, child: Text('Daily Rate')),
                    DropdownMenuItem(value: RentalBillingType.hourly, child: Text('Hourly Rate')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Agreed Rent (₹) *',
                    hintText: 'Enter 0 for free / no rent',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newRate = double.tryParse(rateController.text.trim()) ?? 0.0;
                Navigator.pop(ctx);
                await ref.read(staysProvider.notifier).updateStayRate(
                      widget.stay.id,
                      newRate,
                      billingType: selectedType,
                    );
                ref.invalidate(billingSummaryProvider(widget.stay.id));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rent tariff updated successfully!'),
                      backgroundColor: AppColors.verifiedGreen,
                    ),
                  );
                  Navigator.pop(context); // Close detail screen so it refreshes cleanly
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferRoomDialog(BuildContext context) async {
    final properties = ref.read(propertiesProvider).value ?? [];
    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No properties available for transfer.')),
      );
      return;
    }

    String selectedPropId = widget.stay.propertyId.isNotEmpty ? widget.stay.propertyId : properties.first.id;
    List<Room> rooms = await dbService.getRooms(selectedPropId);
    String? selectedRoomId;
    final rateController = TextEditingController(text: widget.stay.agreedRate.toStringAsFixed(0));
    var selectedType = widget.stay.rentalTypeUsed;
    DateTime transferDate = DateTime.now();
    final formKey = GlobalKey<FormState>();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final availableRooms = rooms.where((r) => r.id != widget.stay.roomId).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: const [
                Icon(Icons.swap_horiz_rounded, color: AppColors.brandBlue),
                SizedBox(width: 8),
                Text('TRANSFER ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select the destination property and room. Occupancy counters and rent tariff will update automatically.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    // Target Property Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedPropId,
                      decoration: const InputDecoration(
                        labelText: 'Target Property *',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      items: properties.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (val) async {
                        if (val != null && val != selectedPropId) {
                          setDlgState(() {
                            selectedPropId = val;
                            selectedRoomId = null;
                          });
                          final newRooms = await dbService.getRooms(val);
                          setDlgState(() {
                            rooms = newRooms;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Target Room Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedRoomId,
                      decoration: const InputDecoration(
                        labelText: 'Destination Room *',
                        prefixIcon: Icon(Icons.meeting_room_rounded),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please select a room' : null,
                      items: availableRooms.map((r) {
                        final isFull = r.currentOccupancy >= r.capacity;
                        return DropdownMenuItem<String>(
                          value: isFull ? null : r.id,
                          enabled: !isFull,
                          child: Text(
                            '${r.roomNumber} (${r.currentOccupancy}/${r.capacity} beds)${isFull ? " - FULL" : ""}',
                            style: TextStyle(
                              color: isFull ? AppColors.textMuted : AppColors.textMain,
                              fontWeight: isFull ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            selectedRoomId = val;
                            final match = rooms.where((r) => r.id == val);
                            if (match.isNotEmpty) {
                              final rm = match.first;
                              if (selectedType == RentalBillingType.daily) {
                                rateController.text = rm.dailyRate.toStringAsFixed(0);
                              } else if (selectedType == RentalBillingType.hourly) {
                                rateController.text = rm.hourlyRate.toStringAsFixed(0);
                              } else {
                                rateController.text = rm.monthlyRate.toStringAsFixed(0);
                              }
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Billing Frequency
                    DropdownButtonFormField<RentalBillingType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Billing Frequency',
                        prefixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: RentalBillingType.monthly, child: Text('Monthly Rate')),
                        DropdownMenuItem(value: RentalBillingType.daily, child: Text('Daily Rate')),
                        DropdownMenuItem(value: RentalBillingType.hourly, child: Text('Hourly Rate')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            selectedType = val;
                            if (selectedRoomId != null) {
                              final match = rooms.where((r) => r.id == selectedRoomId);
                              if (match.isNotEmpty) {
                                final rm = match.first;
                                if (val == RentalBillingType.daily) {
                                  rateController.text = rm.dailyRate.toStringAsFixed(0);
                                } else if (val == RentalBillingType.hourly) {
                                  rateController.text = rm.hourlyRate.toStringAsFixed(0);
                                } else {
                                  rateController.text = rm.monthlyRate.toStringAsFixed(0);
                                }
                              }
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Rent Tariff
                    TextFormField(
                      controller: rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Agreed Rent (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Transfer Date Picker
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.glassBorder),
                      ),
                      leading: const Icon(Icons.calendar_today_rounded, color: AppColors.brandBlue, size: 20),
                      title: Text(
                        'Transfer Date: ${DateFormat('dd MMM yyyy').format(transferDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded, size: 18),
                      onTap: () async {
                        final now = DateTime.now();
                        final firstDate = DateTime(2000, 1, 1);
                        final lastDate = now.add(const Duration(days: 365));
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: transferDate,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        );
                        if (picked != null) {
                          setDlgState(() {
                            transferDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              now.hour,
                              now.minute,
                              now.second,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  shape: const StadiumBorder(),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (selectedRoomId == null) return;
                  final newRate = double.tryParse(rateController.text.trim()) ?? 0.0;
                  Navigator.pop(ctx);

                  await ref.read(staysProvider.notifier).transferStayRoom(
                        stayId: widget.stay.id,
                        targetPropertyId: selectedPropId,
                        targetRoomId: selectedRoomId!,
                        newRate: newRate,
                        newBillingType: selectedType,
                        transferDate: transferDate,
                      );
                  ref.invalidate(billingSummaryProvider(widget.stay.id));
                  ref.invalidate(roomsProvider(widget.stay.propertyId));
                  if (selectedPropId != widget.stay.propertyId) {
                    ref.invalidate(roomsProvider(selectedPropId));
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Resident transferred to new room successfully!'),
                        backgroundColor: AppColors.verifiedGreen,
                      ),
                    );
                    Navigator.pop(context); // Close detail so it re-renders cleanly
                  }
                },
                child: const Text('CONFIRM TRANSFER'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCampDetailsModal(BuildContext context, Property? camp, Room? room) {
    if (camp == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Camp Details'),
          content: Text('Camp details for property ID "${widget.stay.propertyId}" could not be found locally.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPill.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.holiday_village_rounded, color: AppColors.primaryPill, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            camp.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${camp.propertyType.toUpperCase()} Accommodation',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (camp.photos.isNotEmpty)
                        Container(
                          width: double.infinity,
                          height: 180,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AppImageHelper.buildImage(
                            camp.photos.first,
                            height: 180,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: AppColors.primaryPill.withOpacity(0.1),
                              child: const Center(child: Icon(Icons.holiday_village_rounded, size: 50, color: AppColors.primaryPill)),
                            ),
                            errorWidget: Container(
                              color: AppColors.primaryPill.withOpacity(0.1),
                              child: const Center(child: Icon(Icons.holiday_village_rounded, size: 50, color: AppColors.primaryPill)),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.neutralPill.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          children: [
                            _buildCampRow(Icons.location_on_rounded, 'Address', '${camp.address}, ${camp.city}, ${camp.state} - ${camp.pincode}'),
                            const Divider(height: 16, color: AppColors.glassBorder),
                            _buildCampRow(Icons.phone_rounded, 'Contact No', camp.contactNo.isNotEmpty ? camp.contactNo : 'Not provided'),
                            const Divider(height: 16, color: AppColors.glassBorder),
                            _buildCampRow(Icons.category_rounded, 'Property Category', camp.propertyType),
                            if (room != null) ...[
                              const Divider(height: 16, color: AppColors.glassBorder),
                              _buildCampRow(
                                Icons.meeting_room_rounded,
                                'Allocated Room Details',
                                '${room.roomNumber} • ${room.currentOccupancy}/${room.capacity} beds occupied (${room.rentalType.toUpperCase()} rate: ₹${(room.rentalType == 'daily' ? room.dailyRate : room.rentalType == 'hourly' ? room.hourlyRate : room.monthlyRate).toStringAsFixed(0)})',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (camp.contactNo.isNotEmpty) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryPill,
                                  side: const BorderSide(color: AppColors.primaryPill, width: 1.5),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                label: const Text('CALL CAMP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () => _makeCall(camp.contactNo),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPill,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('EDIT CAMP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddEditPropertyScreen(property: camp),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryPill),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final guest = dbService.getCachedPersonById(widget.stay.personId) ?? widget.stay.person;
    if (guest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guest Profile Details')),
        body: const Center(child: Text('Guest record not found.')),
      );
    }
    final billingVal = ref.watch(billingSummaryProvider(widget.stay.id));
    final historyVal = ref.watch(guestStayHistoryProvider(guest.id));
    final properties = ref.watch(propertiesProvider).value ?? [];
    Property? camp;
    for (var p in properties) {
      if (p.id == widget.stay.propertyId) {
        camp = p;
        break;
      }
    }
    camp ??= dbService.getCachedPropertyById(widget.stay.propertyId);
    final room = widget.stay.room ?? dbService.getCachedRoomById(widget.stay.roomId, widget.stay.propertyId);

    return Container(
      decoration: AppColors.backgroundGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Sliver Large Full Photo Header with Status Badge below Name
            SliverAppBar(
              expandedHeight: 290.0,
              pinned: true,
              backgroundColor: AppColors.primaryPill,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: 'Edit Guest Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditGuestScreen(guest: guest),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete Guest Profile',
                  onPressed: () => _confirmDeleteGuest(context, guest),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(left: 16, bottom: 12, right: 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      guest.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Verified Status Badge displayed directly below Person Name (scaled down relative to 16px name text)
                    guest.isBlacklisted
                        ? const StatusBadge(
                            label: 'CRITICAL: BLACKLISTED',
                            icon: Icons.dangerous_rounded,
                            backgroundColor: AppColors.alertRed,
                            fontSize: 10,
                            iconSize: 11,
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          )
                        : const StatusBadge(
                            label: 'VERIFIED ID RECORDED',
                            icon: Icons.verified_user_rounded,
                            backgroundColor: AppColors.verifiedGreen,
                            fontSize: 10,
                            iconSize: 11,
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          ),
                  ],
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => _showPhotoLightbox(context, guest.personPhoto, 'FULL GUEST PHOTO'),
                      child: Hero(
                        tag: 'guest_photo_${guest.id}',
                        child: AppImageHelper.buildImage(
                          guest.personPhoto,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: AppColors.primaryPill,
                            child: const Center(
                              child: Icon(Icons.person_rounded, size: 100, color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Gradient Shadow Overlay
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black45,
                            Colors.transparent,
                            Colors.black87,
                          ],
                          stops: [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Body
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Clean Non-Scrolling 2-Column Contact Actions Card (No Edit button, No Scrolling)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.glassCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Call Button
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPill,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _makeCall(guest.mobileNo),
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('CALL GUEST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // WhatsApp Button
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _openWhatsApp(guest.mobileNo),
                              icon: const Icon(Icons.chat_rounded, size: 18),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (guest.isBlacklisted) ...[
                      // 0. Official Blacklist Record & Landlord Contact Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.alertRed.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.alertRed, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.dangerous_rounded, color: AppColors.alertRed, size: 28),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'CRITICAL: BLACKLISTED GUEST RECORD',
                                    style: TextStyle(
                                      color: AppColors.alertRed,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.alertRed.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.report_problem_rounded, color: AppColors.alertRed, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Reason: ${guest.blacklistReason?.isNotEmpty == true ? guest.blacklistReason! : "Violation of conduct standards / unpaid dues"}',
                                          style: const TextStyle(
                                            color: AppColors.alertRed,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20, color: AppColors.glassBorder),
                                  _buildCampRow(
                                    Icons.person_pin_rounded,
                                    'Blacklisted By Landlord / User',
                                    _blacklistingOwner != null && _blacklistingOwner!.fullName.isNotEmpty
                                        ? '${_blacklistingOwner!.fullName}${_blacklistingOwner!.businessName != null && _blacklistingOwner!.businessName!.isNotEmpty ? " (${_blacklistingOwner!.businessName})" : ""}'
                                        : 'Registered Property Landlord',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCampRow(
                                    Icons.phone_in_talk_rounded,
                                    'Landlord Phone Number',
                                    _blacklistingOwner != null && _blacklistingOwner!.mobileNo.isNotEmpty
                                        ? _blacklistingOwner!.mobileNo
                                        : 'Contact on file',
                                  ),
                                  if (guest.blacklistedAt != null) ...[
                                    const SizedBox(height: 8),
                                    _buildCampRow(
                                      Icons.calendar_month_rounded,
                                      'Date Flagged',
                                      DateFormat('dd MMMM yyyy, hh:mm a').format(guest.blacklistedAt!.toLocal()),
                                    ),
                                  ],
                                  if (guest.policeStationCircle.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildCampRow(
                                      Icons.local_police_rounded,
                                      'Origin Police Circle',
                                      guest.policeStationCircle,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_blacklistingOwner != null && _blacklistingOwner!.mobileNo.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.alertRed,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _makeCall(_blacklistingOwner!.mobileNo),
                                  icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                                  label: Text(
                                    'CALL REPORTING LANDLORD (${_blacklistingOwner!.mobileNo})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.lock_rounded, color: Colors.amber.shade900, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Only the original landlord who blacklisted this individual (${_blacklistingOwner?.fullName ?? "original reporting user"}${_blacklistingOwner != null && _blacklistingOwner!.mobileNo.isNotEmpty ? " - ${_blacklistingOwner!.mobileNo}" : ""}) has permission to remove their blacklist status.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 1. Official Identity Verification Card (Enhanced Typography)
                    OfficialCard(
                      title: 'OFFICIAL IDENTITY VERIFICATION CARD',
                      borderColor: guest.isBlacklisted ? AppColors.alertRed : AppColors.primaryPill,
                      backgroundColor: Colors.white.withOpacity(0.95),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (guest.aadhaarCardPhoto != null && guest.aadhaarCardPhoto!.isNotEmpty) ...[
                            GestureDetector(
                              onTap: () => _showPhotoLightbox(context, guest.aadhaarCardPhoto!, 'AADHAAR CARD PHOTO'),
                              child: Container(
                                width: double.infinity,
                                height: 170,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AppImageHelper.buildImage(
                                  guest.aadhaarCardPhoto,
                                  height: 170,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    color: AppColors.neutralPill.withOpacity(0.3),
                                    child: const Center(
                                      child: Icon(Icons.badge_rounded, size: 64, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  errorWidget: Container(
                                    color: AppColors.neutralPill.withOpacity(0.3),
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.badge_rounded, size: 48, color: AppColors.textSecondary),
                                          SizedBox(height: 6),
                                          Text('Aadhaar Document Recorded', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          _buildDetailField('Full Name', guest.name),
                          _buildDetailField('Aadhaar No', guest.aadhaarNo),
                          _buildDetailField('Mobile No', guest.mobileNo),
                          _buildDetailField('Father\'s Name', guest.fatherName),
                          if (guest.motherName != null) _buildDetailField('Mother\'s Name', guest.motherName!),
                          _buildDetailField('Origin Police Circle', guest.policeStationCircle),
                          _buildDetailField('DOB', DateFormat('dd-MMM-yyyy').format(guest.dob)),
                          _buildDetailField(
                            'Full Address',
                            '${guest.address}, ${guest.city}, ${guest.state} - ${guest.pincode}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),



                    // 1.5. Current Stay Record & Dates Card (Checked IN / OUT Dates)
                    OfficialCard(
                      title: 'CURRENT STAY RECORD & DATES',
                      borderColor: AppColors.primaryPill,
                      backgroundColor: Colors.white.withOpacity(0.95),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'STAY STATUS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: AppColors.primaryPill,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: StatusBadge(
                                        label: widget.stay.status == 'active'
                                            ? 'ACTIVE GUEST'
                                            : (widget.stay.status == 'blacklisted'
                                                ? 'BLACKLISTED'
                                                : (widget.stay.status == 'registered' ? 'REGISTERED' : 'CHECKED OUT')),
                                        icon: widget.stay.status == 'active'
                                            ? Icons.check_circle_rounded
                                            : (widget.stay.status == 'blacklisted'
                                                ? Icons.dangerous_rounded
                                                : (widget.stay.status == 'registered' ? Icons.app_registration_rounded : Icons.history_rounded)),
                                        backgroundColor: widget.stay.status == 'active'
                                            ? AppColors.verifiedGreen
                                            : (widget.stay.status == 'blacklisted'
                                                ? AppColors.alertRed
                                                : (widget.stay.status == 'registered' ? AppColors.primaryPill : AppColors.textSecondary)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.stay.room != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ALLOCATED ROOM',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppColors.primaryPill,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPill.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.meeting_room_rounded, size: 14, color: AppColors.primaryPill),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                widget.stay.room!.roomNumber,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryPill),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Divider(height: 24, color: AppColors.glassBorder),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDetailField(
                                  'CHECKED IN DATE & TIME',
                                  DateFormat('dd MMMM yyyy, hh:mm a').format(widget.stay.checkInDate.toLocal()),
                                ),
                              ),
                              if (widget.stay.status == 'active')
                                IconButton(
                                  icon: const Icon(Icons.edit_calendar_rounded, color: AppColors.primaryPill, size: 22),
                                  tooltip: 'Edit Check-In Date',
                                  onPressed: () => _showEditCheckInDateDialog(context),
                                ),
                            ],
                          ),
                          _buildDetailField(
                            'CHECKED OUT DATE & TIME',
                            widget.stay.checkOutDate != null
                                ? DateFormat('dd MMMM yyyy, hh:mm a').format(widget.stay.checkOutDate!.toLocal())
                                : 'Currently Staying (Active Booking)',
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDetailField(
                                  'BILLING TARIFF & FREQUENCY',
                                  widget.stay.agreedRate > 0
                                      ? '₹${widget.stay.agreedRate.toStringAsFixed(0)} per ${widget.stay.rentalTypeUsed.toString().split('.').last.toUpperCase()}'
                                      : '₹0 (Default / No Rent Set)',
                                ),
                              ),
                              if (widget.stay.status == 'active')
                                IconButton(
                                  icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryPill, size: 24),
                                  tooltip: 'Edit Tariff / Rent',
                                  onPressed: () => _showEditRentDialog(context),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),



                    // 1.6 Camp & Property Details Card (with View Camp Details Option)
                    OfficialCard(
                      title: 'CAMP & PROPERTY DETAILS',
                      borderColor: AppColors.primaryPill,
                      backgroundColor: Colors.white.withOpacity(0.95),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPill.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.holiday_village_rounded,
                                  color: AppColors.primaryPill,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            camp?.name ?? 'Assigned Camp / Property',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        if (camp != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryPill.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              camp.propertyType.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryPill,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      camp != null
                                          ? '${camp.address}, ${camp.city}, ${camp.state} - ${camp.pincode}'
                                          : 'Property ID: ${widget.stay.propertyId}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: AppColors.glassBorder),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailField(
                                  'ALLOCATED ROOM',
                                  room != null
                                      ? room.roomNumber
                                      : (widget.stay.room != null
                                          ? widget.stay.room!.roomNumber
                                          : (widget.stay.roomId.isNotEmpty ? widget.stay.roomId : 'Not Allocated / Prior Record')),
                                ),
                              ),
                              if (camp != null && camp.contactNo.isNotEmpty)
                                Expanded(
                                  child: _buildDetailField('CAMP CONTACT', camp.contactNo),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPill,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.travel_explore_rounded, size: 18),
                              label: const Text(
                                'VIEW CAMP DETAILS',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                              ),
                              onPressed: () => _showCampDetailsModal(context, camp, room),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),



                    // 2. Financial Settlement & Payment History Button Card
                    Text(
                      'FINANCIAL SETTLEMENT LEDGER',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    billingVal.when(
                      data: (billing) {
                        if (billing == null) return const SizedBox();
                        final isPending = billing.pendingAmount > 0;
                        final pendingAmount = billing.pendingAmount;

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.glassCard,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isPending ? AppColors.alertRed : AppColors.verifiedGreen,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // 1. Balance Header with Status Badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isPending ? 'PENDING BALANCE' : 'PAID IN FULL',
                                    style: TextStyle(
                                      color: isPending ? AppColors.alertRed : AppColors.verifiedGreen,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isPending ? AppColors.alertRed : AppColors.verifiedGreen).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isPending ? 'PAYMENT DUE' : 'CLEAR',
                                      style: TextStyle(
                                        color: isPending ? AppColors.alertRed : AppColors.verifiedGreen,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '₹${pendingAmount.abs().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: isPending ? AppColors.alertRed : AppColors.verifiedGreen,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ),
                              if (!isPending && pendingAmount < 0) ...[
                                const SizedBox(height: 2),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Excess Advance Credit Paid',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.verifiedGreen,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),

                              // 2. Metrics summary card with 3 equal columns (never fighting or overflowing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'RATE',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 3),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹${widget.stay.agreedRate.toStringAsFixed(0)}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
                                            ),
                                          ),
                                          Text(
                                            '/${widget.stay.rentalTypeUsed.toString().split('.').last}',
                                            style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(height: 28, width: 1, color: AppColors.glassBorder),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'TOTAL DUE',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 3),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹${max(0.0, billing.totalAmountDue).toStringAsFixed(0)}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
                                            ),
                                          ),
                                          const Text(
                                            'Cumulative',
                                            style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(height: 28, width: 1, color: AppColors.glassBorder),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'TOTAL PAID',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.verifiedGreen),
                                          ),
                                          const SizedBox(height: 3),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹${billing.totalPaid.toStringAsFixed(0)}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.verifiedGreen),
                                            ),
                                          ),
                                          const Text(
                                            'Settled',
                                            style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final room = widget.stay.room ?? dbService.getCachedRoomById(widget.stay.roomId, widget.stay.propertyId);
                                  if (widget.stay.rentalTypeUsed == RentalBillingType.monthly &&
                                      room != null &&
                                      room.minimumDays > 0 &&
                                      room.minimumCharge > 0) {
                                    final stayDays = SupabaseService.stayDaysBetween(
                                        widget.stay.checkInDate.toLocal(),
                                        (widget.stay.checkOutDate ?? DateTime.now()).toLocal());
                                    if (stayDays <= room.minimumDays) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPill.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.primaryPill.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primaryPill),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Minimum Tariff Applied: ₹${room.minimumCharge.toStringAsFixed(0)} (Stay: $stayDays days ≤ ${room.minimumDays} days threshold)',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryPill),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              const Divider(height: 24, color: AppColors.glassBorder),
                              
                              // Dedicated View Payment History & Checkout Row
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryPill,
                                        side: const BorderSide(color: AppColors.primaryPill, width: 1.5),
                                        shape: const StadiumBorder(),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PaymentsScreen(stay: widget.stay),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.history_rounded, size: 20),
                                      label: const Text(
                                        'VIEW PAYMENT HISTORY',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  if (widget.stay.status == 'active') ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.brandBlue,
                                          shape: const StadiumBorder(),
                                        ),
                                        onPressed: () => _showTransferRoomDialog(context),
                                        icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                                        label: const Text(
                                          'TRANSFER TO ANOTHER ROOM',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.alertRed,
                                          shape: const StadiumBorder(),
                                        ),
                                        onPressed: () => _triggerCheckoutSettlement(context, billing.pendingAmount),
                                        icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                                        label: const Text(
                                          'CHECK-OUT GUEST',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (widget.stay.status != 'active') ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.verifiedGreen,
                                          shape: const StadiumBorder(),
                                        ),
                                        onPressed: () {
                                          final guest = dbService.getCachedPersonById(widget.stay.personId) ?? widget.stay.person;
                                          if (guest != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AddGuestFlow(initialPerson: guest),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.login_rounded, size: 20),
                                        label: const Text(
                                          'CHECK-IN GUEST / RE-ADMIT',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Text('Error loading billing summary: $e'),
                    ),
                    const SizedBox(height: 20),

                    // 3. Cross-Property Stay History
                    Text(
                      'CROSS-PROPERTY STAY HISTORY',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Documented stays for this Aadhaar across platform listings.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    historyVal.when(
                      data: (historyList) {
                        if (historyList.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.glassCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Center(child: Text('No other stays documented.')),
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.glassCard,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: historyList.length,
                            separatorBuilder: (context, idx) => const Divider(height: 1, color: AppColors.glassBorder),
                            itemBuilder: (context, idx) {
                              final hist = historyList[idx];
                              final isActive = hist.status == 'active';

                              return ListTile(
                                title: Text(
                                  '${hist.propertyName} - ${hist.roomNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  'In: ${DateFormat('dd-MMM-yyyy').format(hist.checkInDate)}'
                                  ' • Out: ${hist.checkOutDate != null ? DateFormat('dd-MMM-yyyy').format(hist.checkOutDate!) : 'Active'}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                trailing: StatusBadge(
                                  label: hist.status.toUpperCase(),
                                  icon: isActive ? Icons.check_circle_rounded : Icons.history_rounded,
                                  backgroundColor: isActive ? AppColors.verifiedGreen : AppColors.primaryPill,
                                ),
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Text('Error loading history: $e'),
                    ),
                    const SizedBox(height: 32),

                    // 4. Bottom Clean Blacklist / Un-blacklist Button
                    Builder(
                      builder: (context) {
                        final currentOwner = dbService.currentOwnerId;
                        final isBlacklisted = guest.isBlacklisted;
                        final isOriginalOwner = guest.blacklistedBy == null ||
                            guest.blacklistedBy!.isEmpty ||
                            guest.blacklistedBy == currentOwner;

                        final Color btnBg = !isBlacklisted
                            ? AppColors.alertRed
                            : (isOriginalOwner ? AppColors.verifiedGreen : const Color(0xFF64748B));

                        final IconData btnIcon = !isBlacklisted
                            ? Icons.report_problem_rounded
                            : (isOriginalOwner ? Icons.check_circle_rounded : Icons.lock_rounded);

                        final String btnLabel = !isBlacklisted
                            ? 'FLAG / BLACKLIST GUEST'
                            : (isOriginalOwner
                                ? 'REMOVE BLACKLIST STATUS'
                                : 'LOCKED: FLAGGED BY ${_blacklistingOwner?.fullName.toUpperCase() ?? "ANOTHER OWNER"}');

                        return Center(
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            margin: const EdgeInsets.only(bottom: 24),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: btnBg,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                if (isBlacklisted) {
                                  if (!isOriginalOwner) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        title: Row(
                                          children: const [
                                            Icon(Icons.lock_rounded, color: AppColors.alertRed),
                                            SizedBox(width: 8),
                                            Text('Blacklist Removal Locked'),
                                          ],
                                        ),
                                        content: Text(
                                          'This individual was blacklisted by ${_blacklistingOwner?.fullName ?? "another property landlord"}'
                                          '${_blacklistingOwner?.mobileNo != null && _blacklistingOwner!.mobileNo.isNotEmpty ? " (Phone: ${_blacklistingOwner!.mobileNo})" : ""}.\n\n'
                                          'Only the original landlord who recorded this report has authorization to remove the blacklist status.',
                                        ),
                                        actions: [
                                          if (_blacklistingOwner?.mobileNo != null && _blacklistingOwner!.mobileNo.isNotEmpty)
                                            TextButton.icon(
                                              icon: const Icon(Icons.call_rounded, size: 16),
                                              label: Text('CALL ${_blacklistingOwner!.mobileNo}'),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _makeCall(_blacklistingOwner!.mobileNo);
                                              },
                                            ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  _showUnblacklistDialog(context, guest);
                                } else {
                                  _showBlacklistDialog(context);
                                }
                              },
                              icon: Icon(btnIcon, size: 20),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  btnLabel,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // 5. Delete Guest Profile Button
                    Center(
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        margin: const EdgeInsets.only(bottom: 24),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: guest.isBlacklisted ? const Color(0xFF94A3B8) : AppColors.alertRed,
                            side: BorderSide(
                              color: guest.isBlacklisted ? const Color(0xFFCBD5E1) : AppColors.alertRed,
                              width: 1.5,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => _confirmDeleteGuest(context, guest),
                          icon: Icon(
                            guest.isBlacklisted ? Icons.lock_outline_rounded : Icons.delete_outline_rounded,
                            size: 20,
                          ),
                          label: Text(
                            guest.isBlacklisted ? 'DELETE LOCKED (GUEST BLACKLISTED)' : 'DELETE GUEST PROFILE',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoLightbox(BuildContext context, String photoUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const CloseButton(color: Colors.white),
            ),
            Expanded(
              child: InteractiveViewer(
                child: AppImageHelper.buildImage(
                  photoUrl,
                  fit: BoxFit.contain,
                  placeholder: const Center(
                    child: Icon(Icons.person, size: 80, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerCheckoutSettlement(BuildContext context, double pendingAmount) async {
    final room = widget.stay.room ?? dbService.getCachedRoomById(widget.stay.roomId, widget.stay.propertyId);
    final isMinChargeActive = widget.stay.rentalTypeUsed == RentalBillingType.monthly &&
        room != null &&
        room.minimumDays > 0 &&
        room.minimumCharge > 0;
    final now = DateTime.now();
    final checkIn = widget.stay.checkInDate.toLocal();
    final stayDays = SupabaseService.stayDaysBetween(checkIn, now);
    final isWithinMinDays = isMinChargeActive && stayDays <= room.minimumDays;

    String settleMode = 'cash';
    // 'settle' = money changed hands now (recorded), 'later' = check out leaving the balance open
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('VERIFY SETTLEMENT BALANCE'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Final checkout calculation (rent for the stay minus everything already paid, advance and deposit included):'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pendingAmount > 0
                        ? AppColors.alertRed.withOpacity(0.1)
                        : AppColors.verifiedGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pendingAmount > 0
                            ? 'DUE FROM GUEST:'
                            : (pendingAmount < 0 ? 'REFUND TO GUEST:' : 'ALL SETTLED:'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${pendingAmount.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: pendingAmount > 0 ? AppColors.alertRed : AppColors.verifiedGreen,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWithinMinDays) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPill.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryPill.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryPill),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Minimum Stay Tariff Applied: ₹${room.minimumCharge.toStringAsFixed(0)} (Stay: $stayDays days ≤ ${room.minimumDays} days threshold)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryPill),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (pendingAmount != 0) ...[
                  Text(
                    pendingAmount > 0
                        ? 'Tap COLLECTED once the guest has paid this amount - it is recorded in the ledger.'
                        : 'Tap REFUNDED once you have handed this amount back - it is recorded in the ledger.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: settleMode,
                    decoration: const InputDecoration(labelText: 'Payment mode'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('CASH')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('BANK TRANSFER')),
                      DropdownMenuItem(value: 'card', child: Text('CARD')),
                    ],
                    onChanged: (v) => setLocal(() => settleMode = v ?? 'cash'),
                  ),
                ] else
                  const Text('Nothing is owed either way.'),
              ],
            ),
          ),
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCEL'),
            ),
            if (pendingAmount != 0)
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, 'later'),
                child: Text(pendingAmount > 0 ? 'CHECK OUT, UNPAID' : 'CHECK OUT, REFUND LATER'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pendingAmount > 0 ? AppColors.alertRed : AppColors.verifiedGreen,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(dialogCtx, 'settle'),
              child: Text(
                pendingAmount > 0
                    ? 'COLLECTED & CHECK OUT'
                    : (pendingAmount < 0 ? 'REFUNDED & CHECK OUT' : 'CONFIRM CHECK-OUT'),
              ),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    final stayId = widget.stay.id;
    await ref.read(staysProvider.notifier).checkOut(stayId, DateTime.now());

    // Record the money that changed hands so the ledger balances and keeps an audit trail.
    var recorded = false;
    if (choice == 'settle') {
      final due = double.parse(dbService.getLocalBillingSummary(stayId).pendingAmount.toStringAsFixed(2));
      if (due != 0) {
        await ref.read(paymentsProvider(stayId).notifier).addPayment(Payment(
              id: '',
              stayId: stayId,
              personId: widget.stay.personId,
              ownerId: widget.stay.ownerId,
              paymentType: due > 0 ? PaymentCategory.rent : PaymentCategory.refund,
              amount: due.abs(),
              paymentMode: settleMode,
              paidAt: DateTime.now(),
              notes: due > 0 ? 'Checkout settlement - dues collected' : 'Checkout settlement - refund to guest',
              recordedBy: widget.stay.ownerId,
              createdAt: DateTime.now(),
            ));
        recorded = true;
      }
    }
    ref.invalidate(billingSummaryProvider(stayId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(recorded
              ? 'Checked out. Settlement recorded in the ledger.'
              : (choice == 'later' && pendingAmount != 0
                  ? 'Checked out. Balance of ₹${pendingAmount.abs().toStringAsFixed(2)} left open - record it later from Payments.'
                  : 'Checked out. Nothing was owed.')),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showBlacklistDialog(BuildContext context) {
    final reasonController = TextEditingController();
    ReportCategory selectedCategory = ReportCategory.blacklist;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('CRITICAL: FLAG GUEST PLATFORM-WIDE'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This action flag-reports the guest across the entire network. All owners will see this warning. Use only for valid reasons.',
                  style: TextStyle(color: AppColors.alertRed, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ReportCategory>(
                  value: selectedCategory,
                  items: ReportCategory.values
                      .map((val) => DropdownMenuItem(
                            value: val,
                            child: Text(val.toString().split('.').last.replaceAll('_', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: isProcessing
                      ? null
                      : (val) {
                          if (val != null) {
                            setDialogState(() => selectedCategory = val);
                          }
                        },
                  decoration: const InputDecoration(labelText: 'Report Severity Category'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  enabled: !isProcessing,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Detailed Reason / Offense Description',
                    hintText: 'e.g. Damage to room, unpaid balance of ₹4000, rule violation, etc.',
                  ),
                ),
                if (isProcessing) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Text('Processing blacklist update...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          actions: isProcessing
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertRed, shape: const StadiumBorder()),
                    onPressed: () async {
                      String reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        reason = 'Flagged for violation of property rules & conduct standards';
                      }

                      setDialogState(() => isProcessing = true);

                      try {
                        await dbService.blacklistGuest(
                          widget.stay.personId,
                          reason,
                          selectedCategory,
                        );

                        if (context.mounted) {
                          Navigator.pop(context); // Close dialog
                          ref.read(staysProvider.notifier).loadStays();
                          ref.invalidate(guestStayHistoryProvider(widget.stay.personId));
                          ref.invalidate(billingSummaryProvider(widget.stay.id));
                          Navigator.pop(context); // Return to previous screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Guest has been blacklisted and reported platform-wide.'),
                              backgroundColor: AppColors.alertRed,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating blacklist: $e'),
                              backgroundColor: AppColors.alertRed,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('CONFIRM BLACKLIST'),
                  ),
                ],
        ),
      ),
    );
  }

  void _showUnblacklistDialog(BuildContext context, Person guest) {
    final currentUserId = dbService.currentOwnerId;
    final isOriginalOwner = guest.blacklistedBy == null ||
        guest.blacklistedBy!.isEmpty ||
        guest.blacklistedBy == currentUserId;

    if (!isOriginalOwner) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.lock_rounded, color: AppColors.alertRed),
              SizedBox(width: 8),
              Expanded(child: Text('ACTION RESTRICTED', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(
            'This guest was blacklisted by another property owner (${guest.blacklistedBy}).\n\n'
            'Only the original owner who flagged this guest has the authority to remove their blacklist status.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('REMOVE BLACKLIST STATUS'),
        content: Text('Are you sure you want to remove the blacklisted status for ${guest.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verifiedGreen, shape: const StadiumBorder()),
            onPressed: () async {
              try {
                await dbService.unblacklistGuest(guest.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _blacklistingOwner = null;
                  });
                  ref.read(staysProvider.notifier).loadStays();
                  ref.invalidate(guestStayHistoryProvider(guest.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Blacklist status removed successfully.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error removing blacklist: $e'), backgroundColor: AppColors.alertRed),
                  );
                }
              }
            },
            child: const Text('REMOVE BLACKLIST'),
          ),
        ],
      ),
    );
  }



  // Enhanced Detail Field Typography
  Widget _buildDetailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: AppColors.primaryPill,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
