import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/models/subscription_plan.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import '../../../core/widgets/subscription_upgrade_dialog.dart';
import 'add_edit_property_screen.dart';
import 'room_occupants_screen.dart';
import 'property_occupants_screen.dart';
import '../../guests/presentation/add_guest_flow.dart';
import '../../guests/presentation/select_previous_guest_sheet.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final Property property;

  const PropertyDetailScreen({Key? key, required this.property}) : super(key: key);

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
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

  void _showAddOrEditRoomDialog(String propertyId, {Room? roomToEdit}) {
    if (roomToEdit != null) {
      _roomNoController.text = roomToEdit.roomNumber;
      _roomCapacityController.text = roomToEdit.capacity.toString();
      _selectedRateMode = (roomToEdit.rentalType == 'daily' || roomToEdit.rentalType == 'hourly')
          ? roomToEdit.rentalType
          : 'monthly';
      if (_selectedRateMode == 'hourly') {
        _roomSingleRateController.text = roomToEdit.hourlyRate.toStringAsFixed(0);
      } else if (_selectedRateMode == 'daily') {
        _roomSingleRateController.text = roomToEdit.dailyRate.toStringAsFixed(0);
      } else {
        _roomSingleRateController.text = roomToEdit.monthlyRate.toStringAsFixed(0);
      }
      _roomMinDaysController.text = roomToEdit.minimumDays > 0 ? roomToEdit.minimumDays.toString() : '';
      _roomMinChargeController.text = roomToEdit.minimumCharge > 0 ? roomToEdit.minimumCharge.toStringAsFixed(0) : '';
    } else {
      _roomNoController.clear();
      _roomCapacityController.text = '4';
      _selectedRateMode = 'monthly';
      _roomSingleRateController.text = '0';
      _roomMinDaysController.text = '';
      _roomMinChargeController.text = '';
    }

    bool isSavingRoom = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              const Icon(Icons.meeting_room_rounded, color: AppColors.primaryPill),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  roomToEdit == null ? 'ADD ROOM / UNIT' : 'EDIT ROOM / UNIT',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
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
                              hintText: 'e.g. 15',
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
                              hintText: 'e.g. 500',
                              prefixIcon: Icon(Icons.shield_outlined),
                            ),
                            keyboardType: TextInputType.number,
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
                      final minDaysValue = int.tryParse(_roomMinDaysController.text.trim()) ?? 0;
                      final minChargeValue = double.tryParse(_roomMinChargeController.text.trim()) ?? 0.0;
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
                        if (roomToEdit == null) {
                          final newRoom = Room(
                            id: '',
                            propertyId: propertyId,
                            roomNumber: _roomNoController.text.trim(),
                            capacity: int.parse(_roomCapacityController.text.trim()),
                            currentOccupancy: 0,
                            rentalType: _selectedRateMode,
                            hourlyRate: hourly,
                            dailyRate: daily,
                            monthlyRate: monthly,
                            minimumDays: minDays,
                            minimumCharge: minCharge,
                            status: RoomStatus.available,
                            photos: [],
                            createdAt: DateTime.now(),
                          );

                          await ref.read(roomsProvider(propertyId).notifier).addRoom(newRoom);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Room registered successfully under property.')),
                            );
                            _roomNoController.clear();
                            _roomCapacityController.clear();
                            _roomSingleRateController.clear();
                            _roomMinDaysController.clear();
                            _roomMinChargeController.clear();
                          }
                        } else {
                          final updatedRoom = Room(
                            id: roomToEdit.id,
                            propertyId: roomToEdit.propertyId,
                            roomNumber: _roomNoController.text.trim(),
                            capacity: int.parse(_roomCapacityController.text.trim()),
                            currentOccupancy: roomToEdit.currentOccupancy,
                            rentalType: _selectedRateMode,
                            hourlyRate: hourly,
                            dailyRate: daily,
                            monthlyRate: monthly,
                            minimumDays: minDays,
                            minimumCharge: minCharge,
                            status: roomToEdit.status,
                            photos: roomToEdit.photos,
                            createdAt: roomToEdit.createdAt,
                          );

                          await ref.read(roomsProvider(propertyId).notifier).updateRoom(updatedRoom);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Room "${updatedRoom.roomNumber}" updated successfully.')),
                            );
                            _roomNoController.clear();
                            _roomCapacityController.clear();
                            _roomSingleRateController.clear();
                            _roomMinDaysController.clear();
                            _roomMinChargeController.clear();
                          }
                        }
                      } catch (e) {
                        setDialogState(() => isSavingRoom = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving room: $e'), backgroundColor: AppColors.alertRed),
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
                  : Text(roomToEdit == null ? 'SAVE ROOM' : 'UPDATE ROOM'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProperty(Property prop) {
    final stays = ref.read(staysProvider).value ?? [];
    final activeStays = stays.where((s) => s.propertyId == prop.id && s.status == 'active').toList();
    if (activeStays.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 28),
              SizedBox(width: 10),
              Text('Cannot Delete Property', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Cannot delete "${prop.name}" because it currently has ${activeStays.length} active checked-in guest(s).\n\nPlease check out or reassign all guests before deleting this property.',
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
            Icon(Icons.delete_forever_rounded, color: AppColors.alertRed, size: 28),
            SizedBox(width: 10),
            Text('Delete Property?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${prop.name}"?\n\nThis will remove all associated rooms and past check-in records under this property. This action cannot be undone.',
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
              await ref.read(propertiesProvider.notifier).deleteProperty(prop.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Property "${prop.name}" deleted successfully.')),
                );
                Navigator.pop(context); // Go back to property list
              }
            },
            child: const Text('DELETE PROPERTY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRoom(String propertyId, Room room) {
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
              await ref.read(roomsProvider(propertyId).notifier).deleteRoom(room.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${room.roomNumber}" removed.')),
                );
              }
            },
            child: const Text('DELETE ROOM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
    final properties = ref.watch(propertiesProvider).value ?? [];
    // Ensure we have latest property updates if edited
    final currentProp = properties.firstWhere(
      (p) => p.id == widget.property.id,
      orElse: () => widget.property,
    );

    final roomsAsync = ref.watch(roomsProvider(currentProp.id));

    return ReplicaHeaderScaffold(
      title: currentProp.name,
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
                  builder: (context) => PropertyOccupantsScreen(property: currentProp),
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
            tooltip: 'Edit Property Details',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditPropertyScreen(property: currentProp),
                ),
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.alertRed.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.alertRed, size: 20),
            tooltip: 'Delete Property',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _confirmDeleteProperty(currentProp),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryPill,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Guest', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddGuestOptions(context, currentProp),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Property Details Card
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPill.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.business_rounded, color: AppColors.primaryPill, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentProp.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.neutralPill,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                currentProp.propertyType.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.glassBorder),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primaryPill),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${currentProp.address}, ${currentProp.city}, ${currentProp.state} - ${currentProp.pincode}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 16, color: AppColors.primaryPill),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Contact: ${currentProp.contactNo}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
                        ),
                      ),
                      if (currentProp.contactNo.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.call_rounded, size: 18, color: AppColors.primaryPill),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => launchUrl(Uri.parse('tel:${currentProp.contactNo}')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Capacity & Occupancy Summary Card
            roomsAsync.when(
              data: (rooms) {
                final totalRooms = rooms.length;
                final totalCapacity = rooms.fold<int>(0, (sum, r) => sum + r.capacity);
                final totalOccupancy = rooms.fold<int>(0, (sum, r) => sum + r.currentOccupancy);
                final availableBeds = totalCapacity - totalOccupancy;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.glassCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('Rooms', '$totalRooms', Icons.meeting_room_outlined),
                      Container(height: 32, width: 1, color: AppColors.glassBorder),
                      _buildSummaryStat('Capacity', '$totalCapacity beds', Icons.single_bed_rounded),
                      Container(height: 32, width: 1, color: AppColors.glassBorder),
                      _buildSummaryStat(
                        'Occupants',
                        '$totalOccupancy',
                        Icons.people_alt_rounded,
                        iconColor: AppColors.verifiedGreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PropertyOccupantsScreen(property: currentProp),
                            ),
                          );
                        },
                      ),
                      Container(height: 32, width: 1, color: AppColors.glassBorder),
                      _buildSummaryStat('Available', '$availableBeds beds', Icons.check_circle_outline_rounded),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 20),

            // Rooms Header & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Registered Rooms',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textMain),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.verifiedGreen,
                        side: BorderSide(color: AppColors.verifiedGreen.withOpacity(0.4)),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PropertyOccupantsScreen(property: currentProp),
                          ),
                        );
                      },
                      icon: const Icon(Icons.people_alt_rounded, size: 16),
                      label: const Text('All Occupants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPill,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        final currentRooms = ref.read(roomsProvider(currentProp.id)).value?.length ?? 0;
                        final owner = ref.read(authProvider).value;
                        final check = SubscriptionPlanConfig.checkCanAddRoom(
                          owner: owner,
                          currentRoomCount: currentRooms,
                        );
                        if (!check.canAdd) {
                          SubscriptionUpgradeDialog.show(
                            context,
                            limitWarningTitle: 'Room Limit Reached',
                            limitWarningMessage: check.reason,
                          );
                          return;
                        }
                        _showAddOrEditRoomDialog(currentProp.id);
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rooms List
            roomsAsync.when(
              data: (rooms) {
                if (rooms.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.glassCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'No rooms registered yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap the "+ Add Room" button to register rooms and assign beds for guests.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rooms.length,
                  itemBuilder: (context, idx) {
                    final room = rooms[idx];
                    final primaryRate = room.rentalType == 'daily'
                        ? '₹${room.dailyRate.toStringAsFixed(0)}/day'
                        : room.rentalType == 'hourly'
                            ? '₹${room.hourlyRate.toStringAsFixed(0)}/hr'
                            : (room.minimumDays > 0 && room.minimumCharge > 0
                                ? '₹${room.monthlyRate.toStringAsFixed(0)}/mo (Min ₹${room.minimumCharge.toStringAsFixed(0)} for ≤${room.minimumDays}d)'
                                : '₹${room.monthlyRate.toStringAsFixed(0)}/mo');

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
                                builder: (context) => RoomOccupantsScreen(
                                  property: currentProp,
                                  room: room,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final isMaint = room.status == RoomStatus.maintenance;
                                        final isFull = room.status == RoomStatus.full || room.currentOccupancy >= room.capacity;
                                        final Color iconColor = isMaint
                                            ? AppColors.alertRed
                                            : (isFull ? const Color(0xFF6366F1) : AppColors.verifiedGreen);
                                        final IconData badgeIcon = isMaint
                                            ? Icons.build_rounded
                                            : (isFull ? Icons.people_rounded : Icons.check_rounded);

                                        return SizedBox(
                                          width: 38,
                                          height: 38,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: iconColor.withOpacity(0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.meeting_room_rounded,
                                                  color: iconColor,
                                                  size: 20,
                                                ),
                                              ),
                                              Positioned(
                                                bottom: -1,
                                                right: -1,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: iconColor,
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
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        room.roomNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.primaryPill),
                                      tooltip: 'Edit Room',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => _showAddOrEditRoomDialog(currentProp.id, roomToEdit: room),
                                    ),
                                    if (room.currentOccupancy < room.capacity)
                                      IconButton(
                                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: AppColors.verifiedGreen),
                                        tooltip: 'Check-in Guest to this room',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AddGuestFlow(
                                                initialPropertyId: currentProp.id,
                                                initialRoomId: room.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.alertRed),
                                      tooltip: 'Delete Room',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => _confirmDeleteRoom(currentProp.id, room),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18, color: AppColors.glassBorder),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Capacity: ${room.capacity} beds • $primaryRate',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPill.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${room.currentOccupancy}/${room.capacity} Occ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppColors.primaryPill,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading rooms: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final content = Column(
      children: [
        Icon(icon, size: 18, color: iconColor ?? AppColors.primaryPill),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: content,
        ),
      );
    }
    return content;
  }
}
