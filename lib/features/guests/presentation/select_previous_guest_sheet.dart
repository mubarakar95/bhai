import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/image_helper.dart';

/// Modal bottom sheet to search and select a previously registered or
/// checked-out guest to re-allocate into a property/room without re-doing KYC.
class SelectPreviousGuestSheet extends ConsumerStatefulWidget {
  final String? targetPropertyId;
  final String? targetRoomId;

  const SelectPreviousGuestSheet({
    Key? key,
    this.targetPropertyId,
    this.targetRoomId,
  }) : super(key: key);

  /// Helper to display this modal bottom sheet easily from any screen
  static Future<Person?> show(
    BuildContext context, {
    String? targetPropertyId,
    String? targetRoomId,
  }) {
    return showModalBottomSheet<Person>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SelectPreviousGuestSheet(
        targetPropertyId: targetPropertyId,
        targetRoomId: targetRoomId,
      ),
    );
  }

  @override
  ConsumerState<SelectPreviousGuestSheet> createState() => _SelectPreviousGuestSheetState();
}

class _SelectPreviousGuestSheetState extends ConsumerState<SelectPreviousGuestSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'checked_out', 'blacklisted'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _maskAadhaar(String aadhaar) {
    final clean = aadhaar.replaceAll(RegExp(r'\s+'), '');
    if (clean.length < 4) return aadhaar;
    final last4 = clean.substring(clean.length - 4);
    return 'XXXX-XXXX-$last4';
  }

  Future<void> _handleGuestSelected(Person person, Stay? activeStay, Stay? latestStay, Map<String, Property> propMap) async {
    final db = ref.read(dbServiceProvider);

    // 1. Critical Blacklist Check
    if (person.isBlacklisted) {
      Owner? blacklistingOwner;
      final ownerId = person.blacklistedBy?.isNotEmpty == true
          ? person.blacklistedBy!
          : person.createdByOwnerId;
      if (ownerId.isNotEmpty) {
        blacklistingOwner = await db.getOwnerById(ownerId);
      }

      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.alertRed.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.dangerous_rounded, color: AppColors.alertRed, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'CRITICAL: BLACKLISTED GUEST',
                  style: TextStyle(
                    color: AppColors.alertRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.alertRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.alertRed.withOpacity(0.3)),
                ),
                child: Text(
                  '${person.name} has been BLACKLISTED across the rental network.',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.alertRed, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '• Reported By: ${blacklistingOwner?.fullName ?? "Host Property Owner"}\n'
                '• Reason: ${person.blacklistReason?.isNotEmpty == true ? person.blacklistReason! : "Violation of conduct standards / unpaid dues"}\n'
                '• Origin Circle: ${person.policeStationCircle.isNotEmpty ? person.policeStationCircle : "Not Specified"}\n'
                '• Date: ${person.blacklistedAt != null ? DateFormat('dd MMM yyyy').format(person.blacklistedAt!.toLocal()) : "Documented"}',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              const Text(
                'Are you sure you want to re-admit this guest to your property despite this warning?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alertRed,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('PROCEED ANYWAY', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    // 2. Active Stay Warning Check
    if (activeStay != null) {
      if (widget.targetRoomId != null && activeStay.roomId == widget.targetRoomId) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This guest is already an active occupant of this room.'),
            backgroundColor: AppColors.alertRed,
          ),
        );
        return;
      }

      final propName = propMap[activeStay.propertyId]?.name ?? 'Another Property';
      final roomName = activeStay.room?.roomNumber ?? activeStay.roomId;

      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 26),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Guest Active Elsewhere', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Text(
            '${person.name} is currently registered as an active occupant in $propName (Room $roomName).\n\nDo you want to allocate them to this new property/room as well?',
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('PROCEED'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    if (!mounted) return;
    Navigator.pop(context, person);
  }

  @override
  Widget build(BuildContext context) {
    final staysAsync = ref.watch(staysProvider);
    final stays = staysAsync.value ?? [];

    final propertiesAsync = ref.watch(propertiesProvider);
    final properties = propertiesAsync.value ?? [];
    final propMap = {for (var p in properties) p.id: p};

    final db = ref.read(dbServiceProvider);
    final currentOwner = db.currentOwnerId;
    final cachedPersons = db.allCachedPersons;

    // Collect all unique persons known to this owner
    final personMap = <String, Person>{};
    final personActiveStay = <String, Stay>{};
    final personLatestStay = <String, Stay>{};
    final activePersonIds = <String>{};
    final activeAadhaars = <String>{};
    final activeMobiles = <String>{};

    for (var stay in stays) {
      final p = stay.person ?? db.getCachedPersonById(stay.personId);
      if (p != null) {
        personMap[p.id] = p;

        if (stay.status == 'active') {
          personActiveStay[p.id] = stay;
          personActiveStay[stay.personId] = stay;
          activePersonIds.add(p.id);
          activePersonIds.add(stay.personId);
          if (p.aadhaarNo.isNotEmpty) activeAadhaars.add(p.aadhaarNo.trim());
          if (p.mobileNo.isNotEmpty) activeMobiles.add(p.mobileNo.trim());
        }

        final existingLatest = personLatestStay[p.id];
        if (existingLatest == null || stay.checkInDate.isAfter(existingLatest.checkInDate)) {
          personLatestStay[p.id] = stay;
          personLatestStay[stay.personId] = stay;
        }
      } else if (stay.status == 'active') {
        activePersonIds.add(stay.personId);
      }
    }

    for (var p in cachedPersons) {
      final isOwnerGuest = currentOwner != null && (p.createdByOwnerId == currentOwner || p.blacklistedBy == currentOwner);
      if (isOwnerGuest && !personMap.containsKey(p.id)) {
        personMap[p.id] = p;
      }
    }

    var candidateList = personMap.values.toList();

    // Filter by tab
    if (_selectedFilter == 'checked_out') {
      candidateList = candidateList.where((p) {
        final isActive = activePersonIds.contains(p.id) ||
            (p.aadhaarNo.isNotEmpty && activeAadhaars.contains(p.aadhaarNo.trim())) ||
            (p.mobileNo.isNotEmpty && activeMobiles.contains(p.mobileNo.trim())) ||
            (personActiveStay[p.id] != null);
        if (isActive) return false;

        final latest = personLatestStay[p.id];
        return latest != null && (latest.status == 'checked_out' || latest.status == 'checkout' || latest.checkOutDate != null);
      }).toList();
    } else if (_selectedFilter == 'blacklisted') {
      candidateList = candidateList.where((p) => p.isBlacklisted).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      candidateList = candidateList.where((p) {
        final nameMatch = p.name.toLowerCase().contains(q);
        final phoneMatch = p.mobileNo.toLowerCase().contains(q);
        final aadhaarMatch = p.aadhaarNo.toLowerCase().contains(q);
        final cityMatch = p.city.toLowerCase().contains(q);

        final stay = personLatestStay[p.id];
        final propName = stay != null ? (propMap[stay.propertyId]?.name ?? '').toLowerCase() : '';
        final roomName = stay?.room?.roomNumber.toLowerCase() ?? '';

        return nameMatch || phoneMatch || aadhaarMatch || cityMatch || propName.contains(q) || roomName.contains(q);
      }).toList();
    }

    // Sort: Checked-out/Unassigned guests first, then recently active, alphabetically
    candidateList.sort((a, b) {
      final aActive = activePersonIds.contains(a.id) || (a.aadhaarNo.isNotEmpty && activeAadhaars.contains(a.aadhaarNo.trim())) || (a.mobileNo.isNotEmpty && activeMobiles.contains(a.mobileNo.trim())) || personActiveStay[a.id] != null;
      final bActive = activePersonIds.contains(b.id) || (b.aadhaarNo.isNotEmpty && activeAadhaars.contains(b.aadhaarNo.trim())) || (b.mobileNo.isNotEmpty && activeMobiles.contains(b.mobileNo.trim())) || personActiveStay[b.id] != null;
      if (!aActive && bActive) return -1;
      if (aActive && !bActive) return 1;

      final aLatest = personLatestStay[a.id]?.checkInDate;
      final bLatest = personLatestStay[b.id]?.checkInDate;
      if (aLatest != null && bLatest != null) {
        return bLatest.compareTo(aLatest);
      }
      return a.name.compareTo(b.name);
    });

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPill.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_rounded, color: AppColors.primaryPill, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Previous Guest',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'Re-admit a past or checked-out guest with saved KYC',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.glassBorder),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, Aadhaar, room...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                filled: true,
                fillColor: AppColors.glassCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('All Past Guests (${personMap.length})', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Checked-Out Guests', 'checked_out'),
                const SizedBox(width: 8),
                _buildFilterChip('Blacklisted', 'blacklisted'),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Guest List
          Flexible(
            child: candidateList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 52, color: AppColors.textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Matching Previous Guests',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try a different search or register a new guest with Aadhaar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    itemCount: candidateList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final person = candidateList[idx];
                      final activeStay = personActiveStay[person.id];
                      final latestStay = personLatestStay[person.id];

                      final isBlacklisted = person.isBlacklisted;
                      final isActive = activeStay != null;
                      final isCurrentRoomActive = widget.targetRoomId != null && activeStay?.roomId == widget.targetRoomId;

                      String staySubtitle = '';
                      if (isActive) {
                        final propName = propMap[activeStay.propertyId]?.name ?? 'Property';
                        final roomName = activeStay.room?.roomNumber.isNotEmpty == true
                            ? activeStay.room!.roomNumber
                            : activeStay.roomId;
                        staySubtitle = 'Active in $propName • $roomName';
                      } else if (latestStay != null) {
                        final propName = propMap[latestStay.propertyId]?.name ?? 'Property';
                        final roomName = latestStay.room?.roomNumber.isNotEmpty == true
                            ? latestStay.room!.roomNumber
                            : latestStay.roomId;
                        final outDate = latestStay.checkOutDate != null
                            ? DateFormat('dd MMM yyyy').format(latestStay.checkOutDate!)
                            : (latestStay.status == 'checked_out' || latestStay.status == 'checkout' ? 'Checked out' : 'Prior stay');
                        staySubtitle = 'Past: $propName ($roomName) • $outDate';
                      } else {
                        staySubtitle = 'Registered profile • ${person.city.isNotEmpty ? person.city : person.state}';
                      }

                      return InkWell(
                        onTap: isCurrentRoomActive
                            ? null
                            : () => _handleGuestSelected(person, activeStay, latestStay, propMap),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isBlacklisted
                                ? AppColors.alertRed.withOpacity(0.06)
                                : (isCurrentRoomActive ? Colors.grey.withOpacity(0.08) : AppColors.glassCard),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isBlacklisted
                                  ? AppColors.alertRed.withOpacity(0.35)
                                  : (isCurrentRoomActive ? Colors.grey.withOpacity(0.2) : AppColors.glassBorder),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar / Photo
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: isBlacklisted
                                    ? AppColors.alertRed.withOpacity(0.15)
                                    : AppColors.primaryPill.withOpacity(0.12),
                                backgroundImage: AppImageHelper.getImageProvider(person.personPhoto),
                                child: AppImageHelper.getImageProvider(person.personPhoto) == null
                                    ? Text(
                                        person.name.isNotEmpty ? person.name[0].toUpperCase() : 'G',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: isBlacklisted ? AppColors.alertRed : AppColors.primaryPill,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),

                              // Info Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            person.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isCurrentRoomActive ? AppColors.textSecondary : AppColors.textMain,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isBlacklisted) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.alertRed,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'BLACKLISTED',
                                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        ] else if (isCurrentRoomActive) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'IN THIS ROOM',
                                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ] else if (isActive) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade700,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'ACTIVE',
                                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${person.mobileNo.isNotEmpty ? person.mobileNo : "No Phone"} • ${_maskAadhaar(person.aadhaarNo)}',
                                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      staySubtitle,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isBlacklisted ? AppColors.alertRed : AppColors.textMuted,
                                        fontWeight: isBlacklisted ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: isCurrentRoomActive ? Colors.transparent : AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Footer Action: Register New Guest
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.primaryPill),
                ),
                onPressed: () => Navigator.pop(context, null),
                icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryPill, size: 18),
                label: const Text(
                  'Register New Guest (Aadhaar KYC)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPill, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
      selectedColor: AppColors.primaryPill.withOpacity(0.18),
      backgroundColor: AppColors.glassCard,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryPill : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryPill : AppColors.glassBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
