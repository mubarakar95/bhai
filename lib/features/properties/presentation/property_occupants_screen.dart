import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import '../../guests/presentation/add_guest_flow.dart';
import '../../guests/presentation/guests_screen.dart';
import '../../guests/presentation/select_previous_guest_sheet.dart';

class PropertyOccupantsScreen extends ConsumerStatefulWidget {
  final Property property;

  const PropertyOccupantsScreen({
    Key? key,
    required this.property,
  }) : super(key: key);

  @override
  ConsumerState<PropertyOccupantsScreen> createState() => _PropertyOccupantsScreenState();
}

class _PropertyOccupantsScreenState extends ConsumerState<PropertyOccupantsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'active'; // 'active', 'checked_out', 'all'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showAddGuestOptions(BuildContext context, Property property) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPill.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryPill, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Guest to ${property.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          '${property.city} • Quick check-in or new KYC',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Option 1: Select Previous / Checked-Out Guest
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  final selectedPerson = await SelectPreviousGuestSheet.show(
                    context,
                    targetPropertyId: property.id,
                  );
                  if (selectedPerson != null && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddGuestFlow(
                          initialPropertyId: property.id,
                          initialPerson: selectedPerson,
                        ),
                      ),
                    );
                  } else if (selectedPerson == null && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddGuestFlow(
                          initialPropertyId: property.id,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.glassCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.verifiedGreen.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_rounded, color: AppColors.verifiedGreen, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Previous / Checked-Out Guest',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Fast check-in using saved KYC, Aadhaar & photo from past stays.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Register New Guest (Aadhaar KYC)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddGuestFlow(
                        initialPropertyId: property.id,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.glassCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPill.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.badge_rounded, color: AppColors.primaryPill, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register New Guest',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Verify 12-digit UID Aadhaar and complete KYC documentation.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider(widget.property.id));
    final rooms = roomsAsync.value ?? dbService.getCachedRooms(widget.property.id);
    final totalCapacity = rooms.fold<int>(0, (sum, r) => sum + r.capacity);

    final rawStays = ref.watch(staysProvider).value ?? [];
    final propertyStays = rawStays
        .where((s) => s.propertyId == widget.property.id)
        .map((s) {
          final person = dbService.getCachedPersonById(s.personId) ?? s.person;
          final room = dbService.getCachedRoomById(s.roomId, s.propertyId) ?? s.room;
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
            person: person,
            room: room,
          );
        })
        .toList();

    final activeStays = propertyStays.where((s) => s.status == 'active').toList();
    final activePersonIds = activeStays.map((s) => s.personId).toSet();
    final checkedOutStays = propertyStays.where((s) => s.status != 'active' && !activePersonIds.contains(s.personId)).toList();

    final filteredStays = propertyStays.where((s) {
      // 1. Status Filter
      if (_statusFilter == 'active' && s.status != 'active') return false;
      if (_statusFilter == 'checked_out' && (s.status == 'active' || activePersonIds.contains(s.personId))) return false;

      // 2. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final guest = s.person;
        final roomNo = s.room?.roomNumber ?? '';
        final q = _searchQuery.toLowerCase();
        final matchesName = guest?.name.toLowerCase().contains(q) ?? false;
        final matchesMobile = guest?.mobileNo.contains(q) ?? false;
        final matchesAadhaar = guest?.aadhaarNo.contains(q) ?? false;
        final matchesRoom = roomNo.toLowerCase().contains(q);
        if (!matchesName && !matchesMobile && !matchesAadhaar && !matchesRoom) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort: active first, then newest check-in
    filteredStays.sort((a, b) {
      if (a.status == 'active' && b.status != 'active') return -1;
      if (a.status != 'active' && b.status == 'active') return 1;
      return b.checkInDate.compareTo(a.checkInDate);
    });

    return ReplicaHeaderScaffold(
      title: 'Occupants Directory',
      subtitle: '${widget.property.name} • ${widget.property.city}',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryPill,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Guest', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddGuestOptions(context, widget.property),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Property Occupancy Metric Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    label: 'Active Guests',
                    value: '${activeStays.length}',
                    icon: Icons.people_alt_rounded,
                    color: AppColors.verifiedGreen,
                  ),
                  Container(height: 32, width: 1, color: AppColors.glassBorder),
                  _buildStatColumn(
                    label: 'Total Capacity',
                    value: '$totalCapacity Beds',
                    icon: Icons.single_bed_rounded,
                    color: AppColors.primaryPill,
                  ),
                  Container(height: 32, width: 1, color: AppColors.glassBorder),
                  _buildStatColumn(
                    label: 'Past Stays',
                    value: '${checkedOutStays.length}',
                    icon: Icons.history_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.glassCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search occupants by name, room, mobile, Aadhaar...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPill, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
            ),
            const SizedBox(height: 12),

            // Filter Tabs
            Row(
              children: [
                _buildFilterTab(
                  label: 'Active (${activeStays.length})',
                  key: 'active',
                  color: AppColors.verifiedGreen,
                ),
                const SizedBox(width: 8),
                _buildFilterTab(
                  label: 'Past Stays (${checkedOutStays.length})',
                  key: 'checked_out',
                  color: AppColors.primaryPill,
                ),
                const SizedBox(width: 8),
                _buildFilterTab(
                  label: 'All (${propertyStays.length})',
                  key: 'all',
                  color: AppColors.brandBlue,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Occupants List
            if (filteredStays.isEmpty)
              Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: AppColors.glassCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No occupants matching "$_searchQuery"'
                          : _statusFilter == 'active'
                              ? 'No active occupants in this property'
                              : 'No guests found',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try searching with a different name or room number.'
                          : 'Tap "Add Guest" below to register a new tenant or occupant into this property.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredStays.length,
                itemBuilder: (context, idx) {
                  final stay = filteredStays[idx];
                  final guest = stay.person;
                  final room = stay.room;
                  final isActive = stay.status == 'active';
                  final isBlacklisted = guest?.isBlacklisted == true;

                  final roomDisplay = room != null && room.roomNumber.isNotEmpty
                      ? room.roomNumber
                      : 'Unassigned Room';

                  final rateText = '₹${stay.agreedRate.toStringAsFixed(0)}/${stay.rentalTypeUsed.toString().split('.').last}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.glassCard,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isBlacklisted
                            ? AppColors.alertRed.withOpacity(0.4)
                            : AppColors.glassBorder,
                        width: isBlacklisted ? 1.5 : 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 14,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GuestDetailScreen(stay: stay),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Avatar with status ring
                              SizedBox(
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
                                          color: isBlacklisted
                                              ? AppColors.alertRed
                                              : (isActive ? AppColors.verifiedGreen : AppColors.textMuted),
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        backgroundImage: AppImageHelper.getImageProvider(guest?.personPhoto),
                                        radius: 22,
                                        child: guest?.personPhoto == null || guest!.personPhoto.isEmpty
                                            ? const Icon(Icons.person, color: Colors.white, size: 20)
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -1,
                                      right: -1,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: isBlacklisted
                                              ? AppColors.alertRed
                                              : (isActive ? AppColors.verifiedGreen : const Color(0xFF64748B)),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Icon(
                                          isBlacklisted
                                              ? Icons.warning_rounded
                                              : (isActive ? Icons.home_rounded : Icons.history_rounded),
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Guest details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            guest?.name ?? 'Unknown Resident',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isBlacklisted
                                                ? AppColors.alertRed.withOpacity(0.1)
                                                : (isActive
                                                    ? AppColors.verifiedGreen.withOpacity(0.1)
                                                    : AppColors.textMuted.withOpacity(0.1)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isBlacklisted
                                                ? 'FLAGGED'
                                                : (isActive ? 'CHECKED-IN' : 'CHECKED-OUT'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isBlacklisted
                                                  ? AppColors.alertRed
                                                  : (isActive ? AppColors.verifiedGreen : AppColors.textSecondary),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),

                                    // Room & Rate Badge Row
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPill.withOpacity(0.09),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.meeting_room_outlined, size: 12, color: AppColors.primaryPill),
                                              const SizedBox(width: 4),
                                              Text(
                                                roomDisplay,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryPill,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          rateText,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),

                                    // Check-in Date & Contact
                                    Text(
                                      'Check-in: ${DateFormat('dd-MMM-yyyy').format(stay.checkInDate)}${guest?.mobileNo.isNotEmpty == true ? ' • Mob: ${guest!.mobileNo}' : ''}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Quick Call Button or Chevron
                              if (guest?.mobileNo.isNotEmpty == true)
                                IconButton(
                                  icon: const Icon(Icons.call_rounded, size: 19, color: AppColors.primaryPill),
                                  tooltip: 'Call Guest',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _makeCall(guest!.mobileNo),
                                ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterTab({
    required String label,
    required String key,
    required Color color,
  }) {
    final bool isSelected = _statusFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : AppColors.glassBorder,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
