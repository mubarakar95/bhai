import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import '../../guests/presentation/add_guest_flow.dart';
import '../../guests/presentation/guests_screen.dart';
import '../../guests/presentation/select_previous_guest_sheet.dart';
import 'property_occupants_screen.dart';

class RoomOccupantsScreen extends ConsumerStatefulWidget {
  final Property property;
  final Room room;

  const RoomOccupantsScreen({
    Key? key,
    required this.property,
    required this.room,
  }) : super(key: key);

  @override
  ConsumerState<RoomOccupantsScreen> createState() => _RoomOccupantsScreenState();
}

class _RoomOccupantsScreenState extends ConsumerState<RoomOccupantsScreen> {
  final _roomFormKey = GlobalKey<FormState>();
  final _roomNoController = TextEditingController();
  final _roomCapacityController = TextEditingController();
  final _roomSingleRateController = TextEditingController();
  final _roomMinDaysController = TextEditingController();
  final _roomMinChargeController = TextEditingController();
  String _selectedRateMode = 'monthly';

  @override
  void dispose() {
    _roomNoController.dispose();
    _roomCapacityController.dispose();
    _roomSingleRateController.dispose();
    _roomMinDaysController.dispose();
    _roomMinChargeController.dispose();
    super.dispose();
  }

  void _showEditRoomDialog(Room currentRoom) {
    bool isSavingRoom = false;
    _roomNoController.text = currentRoom.roomNumber;
    _roomCapacityController.text = currentRoom.capacity.toString();
    _selectedRateMode = (currentRoom.rentalType == 'daily' || currentRoom.rentalType == 'hourly')
        ? currentRoom.rentalType
        : 'monthly';

    if (_selectedRateMode == 'hourly') {
      _roomSingleRateController.text = currentRoom.hourlyRate.toStringAsFixed(0);
    } else if (_selectedRateMode == 'daily') {
      _roomSingleRateController.text = currentRoom.dailyRate.toStringAsFixed(0);
    } else {
      _roomSingleRateController.text = currentRoom.monthlyRate.toStringAsFixed(0);
    }
    // Defaults: 15 days, charge = half the monthly rent
    _roomMinDaysController.text =
        (currentRoom.minimumDays > 0 ? currentRoom.minimumDays : 15).toString();
    _roomMinChargeController.text =
        (currentRoom.minimumCharge > 0 ? currentRoom.minimumCharge : currentRoom.monthlyRate / 2)
            .toStringAsFixed(0);
    // While the owner has not typed their own minimum charge it follows half the rent.
    bool minChargeEdited = currentRoom.minimumCharge > 0 &&
        currentRoom.minimumCharge != currentRoom.monthlyRate / 2;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: AppColors.primaryPill),
              SizedBox(width: 10),
              Text('EDIT ROOM & TARIFF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Form(
            key: _roomFormKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _roomNoController,
                    decoration: const InputDecoration(
                      labelText: 'Room Number / Name (e.g. 101, Hall A, Flat 3) *',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _roomCapacityController,
                    decoration: const InputDecoration(
                      labelText: 'Capacity (No. of Beds) *',
                      prefixIcon: Icon(Icons.single_bed_rounded),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      if (_selectedRateMode == 'monthly' && !minChargeEdited) {
                        final r = double.tryParse(v.trim());
                        if (r != null) _roomMinChargeController.text = (r / 2).toStringAsFixed(0);
                      }
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (int.tryParse(v.trim()) == null || int.parse(v.trim()) <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedRateMode,
                    decoration: const InputDecoration(
                      labelText: 'Rent Calculation Type',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly Rate (₹/month)')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily Rate (₹/day)')),
                      DropdownMenuItem(value: 'hourly', child: Text('Hourly Rate (₹/hour)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          _selectedRateMode = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _roomSingleRateController,
                    decoration: InputDecoration(
                      labelText: _selectedRateMode == 'monthly'
                          ? 'Agreed Monthly Rent (₹) *'
                          : _selectedRateMode == 'daily'
                              ? 'Daily Tariff Rate (₹) *'
                              : 'Hourly Tariff Rate (₹) *',
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null || double.parse(v.trim()) < 0) {
                        return 'Must be valid positive amount';
                      }
                      return null;
                    },
                  ),
                  if (_selectedRateMode == 'monthly') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _roomMinDaysController,
                            decoration: const InputDecoration(
                              labelText: 'Min Stay Days',
                              helperText: 'Default 15',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.trim().isNotEmpty) {
                                final d = int.tryParse(v.trim());
                                if (d == null || d < 0 || d > 30) {
                                  return '0 - 30 days';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _roomMinChargeController,
                            decoration: const InputDecoration(
                              labelText: 'Min Charge (₹)',
                              helperText: 'Default: half rent',
                              prefixIcon: Icon(Icons.shield_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => minChargeEdited = true,
                            validator: (v) {
                              if (v != null && v.trim().isNotEmpty) {
                                final c = double.tryParse(v.trim());
                                if (c == null || c < 0) {
                                  return 'Valid amount';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: isSavingRoom
                  ? null
                  : () async {
                      if (!_roomFormKey.currentState!.validate()) return;
                      setDialogState(() => isSavingRoom = true);
                      final rateValue = double.tryParse(_roomSingleRateController.text.trim()) ?? 0.0;
                      final minDaysValue = int.tryParse(_roomMinDaysController.text.trim()) ?? 15;
                      final minChargeText = double.tryParse(_roomMinChargeController.text.trim());
                      final minChargeValue =
                          (minChargeText == null || minChargeText <= 0) ? rateValue / 2 : minChargeText;
                      double hourly = 0.0;
                      double daily = 0.0;
                      double monthly = 0.0;
                      int minDays = 0;
                      double minCharge = 0.0;

                      if (_selectedRateMode == 'hourly') {
                        hourly = rateValue;
                      } else if (_selectedRateMode == 'daily') {
                        daily = rateValue;
                      } else {
                        monthly = rateValue;
                        minDays = minDaysValue;
                        minCharge = minChargeValue;
                      }

                      try {
                        final updatedRoom = Room(
                          id: currentRoom.id,
                          propertyId: currentRoom.propertyId,
                          roomNumber: _roomNoController.text.trim(),
                          capacity: int.parse(_roomCapacityController.text.trim()),
                          currentOccupancy: currentRoom.currentOccupancy,
                          rentalType: _selectedRateMode,
                          hourlyRate: hourly,
                          dailyRate: daily,
                          monthlyRate: monthly,
                          minimumDays: minDays,
                          minimumCharge: minCharge,
                          status: currentRoom.status,
                          photos: currentRoom.photos,
                          createdAt: currentRoom.createdAt,
                        );

                        await ref.read(roomsProvider(widget.property.id).notifier).updateRoom(updatedRoom);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Room "${updatedRoom.roomNumber}" updated successfully.')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSavingRoom = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating room: $e'), backgroundColor: AppColors.alertRed),
                          );
                        }
                      }
                    },
              child: isSavingRoom
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('UPDATE ROOM'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRoom(Room room) {
    if (room.currentOccupancy > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 28),
              SizedBox(width: 10),
              Text('Cannot Delete Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Cannot delete "${room.roomNumber}" because it currently has ${room.currentOccupancy} active occupant(s).\n\nPlease check out or reassign all guests before deleting this room.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
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
            Icon(Icons.delete_outline_rounded, color: AppColors.alertRed, size: 28),
            SizedBox(width: 10),
            Text('Delete Room?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${room.roomNumber}"? This action cannot be undone.',
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
              await ref.read(roomsProvider(widget.property.id).notifier).deleteRoom(room.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${room.roomNumber}" removed.')),
                );
                Navigator.pop(context); // Go back to property screen
              }
            },
            child: const Text('DELETE ROOM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddGuestOptions(BuildContext context, Property property, Room currentRoom) {
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
                          'Add Guest to ${currentRoom.roomNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          '${property.name} • ${currentRoom.currentOccupancy}/${currentRoom.capacity} beds occupied',
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
                    targetRoomId: currentRoom.id,
                  );
                  if (selectedPerson != null && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddGuestFlow(
                          initialPropertyId: property.id,
                          initialRoomId: currentRoom.id,
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
                          initialRoomId: currentRoom.id,
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
                        initialRoomId: currentRoom.id,
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
    final rooms = ref.watch(roomsProvider(widget.property.id)).value ?? [];
    final currentRoom = rooms.firstWhere(
      (r) => r.id == widget.room.id,
      orElse: () => widget.room,
    );

    final staysState = ref.watch(staysProvider);
    final stays = staysState.value ?? [];
    final roomStays = stays.where((s) => s.roomId == currentRoom.id && s.status == 'active').toList();
    final activeOccupants = roomStays.map((s) => s.person).whereType<Person>().toList();

    final primaryRate = currentRoom.rentalType == 'daily'
        ? '₹${currentRoom.dailyRate.toStringAsFixed(0)} / day'
        : currentRoom.rentalType == 'hourly'
            ? '₹${currentRoom.hourlyRate.toStringAsFixed(0)} / hour'
            : (currentRoom.minimumDays > 0 && currentRoom.minimumCharge > 0
                ? '₹${currentRoom.monthlyRate.toStringAsFixed(0)} / month (Min ₹${currentRoom.minimumCharge.toStringAsFixed(0)} for ≤${currentRoom.minimumDays}d)'
                : '₹${currentRoom.monthlyRate.toStringAsFixed(0)} / month');

    return ReplicaHeaderScaffold(
      title: currentRoom.roomNumber,
      subtitle: widget.property.name,
      showBackButton: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: AppColors.verifiedGreen.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.people_alt_rounded, color: AppColors.verifiedGreen, size: 20),
            tooltip: 'View All Property Occupants',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PropertyOccupantsScreen(property: widget.property),
                ),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryPill.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primaryPill, size: 20),
            tooltip: 'Edit Room',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _showEditRoomDialog(currentRoom),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.alertRed.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.alertRed, size: 20),
            tooltip: 'Delete Room',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _confirmDeleteRoom(currentRoom),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room Specs & Status Card
            Container(
              padding: const EdgeInsets.all(20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final isMaint = currentRoom.status == RoomStatus.maintenance;
                      final isFull = currentRoom.status == RoomStatus.full || activeOccupants.length >= currentRoom.capacity;
                      final Color statusColor = isMaint
                          ? AppColors.alertRed
                          : (isFull ? const Color(0xFF6366F1) : AppColors.verifiedGreen);
                      final Color statusBg = isMaint
                          ? AppColors.alertBg
                          : (isFull ? const Color(0xFFEEF2FF) : AppColors.verifiedBg);
                      final IconData badgeIcon = isMaint
                          ? Icons.build_rounded
                          : (isFull ? Icons.people_rounded : Icons.check_rounded);
                      final IconData statusIcon = isMaint
                          ? Icons.build_rounded
                          : (isFull ? Icons.people_rounded : Icons.check_circle_rounded);
                      final String statusText = isMaint
                          ? 'Room is Under Maintenance'
                          : (isFull ? 'Room is Fully Occupied' : 'Room is Available for Check-in');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.meeting_room_rounded,
                                      color: statusColor,
                                      size: 28,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Icon(
                                        badgeIcon,
                                        size: 9,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentRoom.roomNumber,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.property.name,
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Dedicated Status Badge Row (never tight, zero overflow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: statusColor.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 13,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 24, color: AppColors.glassBorder),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn('Bed Capacity', '${currentRoom.capacity} Beds', Icons.single_bed_rounded),
                      Container(height: 36, width: 1, color: AppColors.glassBorder),
                      _buildInfoColumn('Tariff Rate', primaryRate, Icons.payments_outlined),
                      Container(height: 36, width: 1, color: AppColors.glassBorder),
                      _buildInfoColumn(
                        'Occupancy',
                        '${activeOccupants.length} / ${currentRoom.capacity}',
                        Icons.people_alt_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Button to View All Property Occupants
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.verifiedGreen,
                side: BorderSide(color: AppColors.verifiedGreen.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PropertyOccupantsScreen(property: widget.property),
                  ),
                );
              },
              icon: const Icon(Icons.people_alt_outlined, size: 18),
              label: Text(
                'View All Occupants in ${widget.property.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Occupants Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Occupants (${activeOccupants.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textMain),
                ),
                if (activeOccupants.length < currentRoom.capacity)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPill,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _showAddGuestOptions(context, widget.property, currentRoom),
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('Add Guest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Occupants List
            if (activeOccupants.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.glassCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No occupants in this room',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'All beds in this room are currently vacant and available for booking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPill,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () => _showAddGuestOptions(context, widget.property, currentRoom),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('CHECK-IN TO THIS ROOM', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roomStays.length,
                itemBuilder: (context, idx) {
                  final stay = roomStays[idx];
                  final guest = stay.person;
                  if (guest == null) return const SizedBox();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.glassCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.glassBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
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
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: guest.isBlacklisted ? AppColors.alertRed : AppColors.verifiedGreen,
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        backgroundImage: AppImageHelper.getImageProvider(guest.personPhoto),
                                        radius: 20,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -1,
                                      right: -1,
                                      child: Container(
                                        padding: const EdgeInsets.all(2.5),
                                        decoration: BoxDecoration(
                                          color: guest.isBlacklisted ? AppColors.alertRed : AppColors.verifiedGreen,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: Icon(
                                          guest.isBlacklisted ? Icons.warning_rounded : Icons.home_rounded,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      guest.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Mob: ${guest.mobileNo} • Aadhaar: ${guest.aadhaarNo}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Checked in: ${DateFormat('dd MMM yyyy').format(stay.checkInDate)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryPill),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
